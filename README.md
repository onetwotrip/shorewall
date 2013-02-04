Description
===========

Shorewall is a rather comprehensive and easy-to-use abstraction layer on top of
iptables.


Requirements
============

This cookbook must use the `yumrepo` module to install the EPEL
repository when run on CentOS-specific. Also it was adapted to run on Ubuntu/Debian.

The library functions anticipate a network topology in which a cluster of
servers have interconnects over a "private" network which is sufficiently
insecure that a firewall is appropriate to control connections from that
subnet. (This particularly applies to services such as memcached which expect
security to handled at a different layer). However, the module is expected to
remain useful in other scenarios as well.
Now the library functions recognize what addresses they should extract pubic or private.


Capabilities
============

Creates pretty Shorewall configuration files intended to be aesthetically
comparable to hand-written ones.

The following is a typical example of output (in this case, for a rules file):

    #
    # Shorewall version 4 - Rules File
    #
    # For information on the settings in this file, type "man shorewall-rules"
    #
    # The manpage is also online at
    # http://www.shorewall.net/manpages/shorewall-rules.html
    #
    ############################################################################################################################
    #ACTION         SOURCE          DEST            PROTO   DEST    SOURCE          ORIGINAL        RATE            USER/   MARK
    #                                                       PORT    PORT(S)         DEST            LIMIT           GROUP
    #SECTION ESTABLISHED
    #SECTION RELATED
    SECTION NEW

    # Incoming SSH to firewall
    ACCEPT          all             fw              tcp     22      -               -               12/min          -       -

    # Access to API from other API nodes
    ACCEPT          api             fw              tcp     8080    -               -               -               -       -

    # Public access to API from web front-ends
    ACCEPT          wwwf            fw              tcp     8100    -               -               -               -       -

    # Access to zabbix active check port
    ACCEPT          lan:192.168.0.74 \
                                    fw              tcp     10050   -               -               -               -       -

    # Allow api server appl01 access API
    ACCEPT          lan:192.168.0.28 \
                                    fw              tcp     8080    -               -               -               -       -

    # Allow api server appl05 access API
    ACCEPT          lan:192.168.0.215 \
                                    fw              tcp     8080    -               -               -               -       -

    # Allow api server appl00 access API
    ACCEPT          lan:192.168.0.152 \
                                    fw              tcp     8080    -               -               -               -       -


Note how line continuations are added as necessary to keep column alignment in place.


Usage
=====

Typical usage from another module is expected to look like the following:

    add_shorewall_rules(
      match_nodes=[
        ['search:roles:webfronts', { :name => 'web front server' }],
        ['search:roles:api', { :name => 'api server' }],
      ],
      rules={
        :description => proc { |data| "Allow #{data[:match][:name]} #{data[:node][:hostname]} access API" },
        :action => :ACCEPT,
        :source => {:zone => "lan", :public => false, :proc => proc { |data| "lan:#{data[:addresses]}"} },
        :dest => :fw,
        :proto => :tcp,
        :dest_port => 8080
      }
    )

...in the above case, we're using the `add_shorewall_rules` helper to add an
`ACCEPT` rule for each host which matches either the `webfronts` role
or the `api` role (with different comments depending on which role
matched). If a single host matches twice, only a single rule (for each of its
internal IP addresses) is added.

Notably, any of the values in the `rules` hash can be a block, in which case it
is executed with an argument containing both the match metadata passed to the
`match_nodes` argument and the matched node information (`:hostname`, `:fqdn`
and `:network`) retrieved by the search operation.

Source/Destination
==================

`:source` or `:dest` columns might be configured
by the hash with 4 options.

* `:zone` - sets the zone of matched nodes. In other words it tells the search
  operation to extract only those ip addresses which belong to the zone's interface.
* `:public` - by this search identifies what ip addresses it should extract public or
  private which are in the `shorewall/private_ranges`. Default is `false`.
* `:proc` - is a block which forms source/destination column, same as described above.
* `:group` - this parameter combines ip addresses of found hosts for each criteria.
  In this case you can't use proc as it's pointless, the source/destination column is
  constructed automatically. Mind that no address and node information is passed to
  data in other code blocks. Default is `false`.

Actually there are two ways of using `add_shorewall_rules` with and without grouping.
The first example which is shown above doesn't use grouping. To group similar rules use a command
like this:

    add_shorewall_rules(
    match_nodes=[
      ['search:roles:webfronts', { :name => 'web front servers' }],
    ],
    rules={
      :description => proc { |data| "Allow #{data[:match][:name]} access API" },
      :action => :ACCEPT,
      :source => { :zone => "lan", :group => true },
      :dest => :fw,
      :proto => :tcp,
      :dest_port => 8080
    }
    )

And you will get significantly simplified output:

...

    # Access to zabbix active check port
    ACCEPT          lan:192.168.154.74 \
                                    fw              tcp     10050   -               -               -               -       -
    
    # Allow web front servers access API
    ACCEPT          lan:192.168.0.28,192.168.0.215,192.168.0.152,192.168.0.248,192.168.0.54,192.168.0.53 \
                                    fw              tcp     8080    -               -               -               -       -


It's also worth mentioning that there is no real need in `:proc` as it was used in the first
`add_shorewall_rules` example. Say it that command like the following is more than enough:

    add_shorewall_rules(
    match_nodes=[
      ['search:roles:webfronts', { :name => 'web front server' }],
    ],
    rules={
      :description => proc { |data| "Allow #{data[:match][:name]} #{data[:node][:hostname]} access API" },
      :action => :ACCEPT,
      :source => { :zone => "lan" },
      :dest => :fw,
      :proto => :tcp,
      :dest_port => 8080
    }
    )

However if you would like to modify source/destination column you are still free to use `:proc`.


Explicit rules (or policies)
============================

Alternately, an explicit rule (or policy) can be added as follows:

    # Give ALL hosts in lan zone access to logstash
    node.override[:shorewall][:rules] << {
      :description => "Access to logstash web server",
      :action => :ACCEPT,
      :source => :lan,
      :dest => :fw,
      :proto => :tcp,
      :dest_port => 9292
    }


Advanced shorewall cookbook configuration topics
================================================

Zones order
-----------

Shorewall **zones order** is an important issue when filterening traffic. Namely the
default zone `net` is located in the end of the zone file, since it has a capture
for all the addresses (`0.0.0.0/0`). If we locate this zone in the begining
all the the packets will be processed by `net` zone iptables chains and all other
zones will simply fail to work.

Shorewall cookbook has the following default zones: `fw, lan, net`. These zones
automatically grab the specified subnet ip addresses.
In case we want to introduce a custom zone we need to remember about the order.
Say it, we have database servers which are part of `lan` zone. Here, we can use
two approaches. The first one is placing `db` before `lan` zone because we need
database servers to be processed independently of `lan` addresses.

To achieve this use `shorwall.zones_order` attribute, for example it can look like
the following:

    shorewall => {
        "zones" => [
          { :zone => "db", :type => "ipv4" }
        ]
        zones_order" => "fw,db,lan,net"
    }

The `db` zone chain rules will be applied first and only afterterwards `lan` zone
rules will be applied.

The second option is to use shorewall zone nesting. Nested zones are suffixed by the colon after
which a comma separated parent list goes - `api:lan`.

Automoatic zone ordering
------------------------

Child zones must appear in the shorewall zones file after its parents. When we use zone nesting to
configure the shorewall cookbook, the right order will be handled automatically.
Say it we introduce `db` zone nested to `lan` zone. We always have the default order which is:
`fw lan net` and zone nesting will be done using this predefined order.
Just make the following configuration:

    shorewall => {
        "zones" => [
            { :zone => "db:lan", :type => "ipv4" }
        ]
    }

In this case we don't need to set the `zones_order` explicitly.

Search for zone hosts capability
--------------------------------

Search operation is used `add_shorewall_rules` method in the `match_nodes` array. The second place
where it's used is `zone_hosts` attribute.
**zone_hosts** attribute is very important since it defines which hosts will the specific zone contain.
Usually the configuration of `zone_hosts` attribite can be like this:

    "shorewall" => {
        "zone_hosts" => {
            "db" =>  "192.168.15.10-20"
        }
    }

Zone host string in the above sample is set statically. However we can use the search operation in here.
There are two types of the search operations: `search` and `isystem_search`. The first one is the
standart chef search capability, the last one is the Twiket Ltd search helper method.
For example:

    "shorewall" => {
        "zone_hosts" => {
            "db" =>  "search:role:database AND chef_environment:production",
            "api" => "isystem_search:role:api AND name:main-group AND environment:testing"
        }
    }

For `isystem_search` mind that environment must be used instead chef_environment :)

Attributes
==========

*Important:* Many of these are defined at the `override` level rather than the
`default` level. This is done such that `node[:shorewall][:zones] << { ... }`
works as you'd expect.

* `shorewall/default_interface_settings` - Default settings to be used in
  filling out the `interfaces` file. May be overwritten on a per-interface basis.
* `shorewall/enabled` - Boolean (also accepts string versions of true/false);
  whether we actually start the firewall after configuring it.
* `shorewall/private_ranges` - IP address ranges considered eligible as private
  interconnect addresses.
* `shorewall/zone_hosts/ZONE` - if this starts with `search:`, the remainder is
  used as a search expression to identify hosts which should be considered
  members of this zone (when populating the shorewall `hosts` file). Otherwise,
  it can be a CIDR address (as `192.168.0.0/16` or `0.0.0.0/0`) to refer to a
  subnet.
* `shorewall/zone_interfaces/ZONE` - maps shorewall zone name to an ethernet
  interface serving this zone. If multiple zones are mapped to the same interface,
  then that interface will be distinguished via the shorewall `hosts` file.
* `shorewall/public_zones` - forces retrieval of public ip address for explicitly
  defined rules with `node.override[:shorewall][:rules]`.
* `shorewall/rules`, `shorewall/policy`, `shorewall/hosts`,
  `shorewall/interfaces` all correspond directly to the relevant upstream
  configuration files.

For more details, see the `attributes/default.rb` file.

Limitations
===========

Patches to address any of these items would be gratefully accepted.

* Includes a hardcoded, non-configurable versions of the `shorewall.conf` file.
* Supports CentOS, Ubuntu, Debian, but other OS targets should be both worthwhile and straightforward.
* Not all of shorewall's configuration is mapped.
* No thought has been given to IPv6 support.


Authors
=======
* Charles Duffy, charles@poweredbytippr.com
* Denis Barishev, denis.barishev@gmail.com
