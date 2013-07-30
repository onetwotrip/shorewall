# Description

Shorewall is a rather comprehensive and easy-to-use abstraction layer on top of
iptables.

# Capabilities

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
    Limit:none:SSHA,5,60 \
                    all             fw              tcp     22      -               -               -               -       -

    #LAST LINE -- ADD YOUR ENTRIES BEFORE THIS ONE -- DO NOT REMOVE

Note how line continuations are added as necessary to keep column alignment in place.

# Usage

Shorewall cookbook uses a set of attributes `zones, policy, rules...` to setup vital configuration for the shorewall files. The default configuration of those file will make shorewall block everything but SSH connections. So we've got to go through the attributes before using the cookbook.

There are two endpoints for configuration data input. Respectively *roles, environments* along with `add_shorewall_rules` definition. I stronly encourage to use `add_shorewall_rules` for configuring the shorewall rules instead of *roles or environments*.

Typical usage of the definition is expected to look like the following:

    add_shorewall_rules "match api and web servers" do
      match_nodes(
        ['search:roles:webfronts', {:name => 'web front server', :interface => 'eth0', :public => false, :zone => 'net'}],
        ['search:roles:api', {:name => 'api server', :interface => 'eth1', :zone => 'lan'}],
      )
      rules({
        :description => proc {|data| "Allow #{data[:name]} access API" },
        :action => :ACCEPT,
        :source => proc {|data| "#{data[:zone]}:#{data[:matched_hosts]}"},
        :dest => :fw,
        :proto => :tcp,
        :dest_port => 8080
      })
    end


...in the above case, we're using the `add_shorewall_rules` definition to `ACCEPT` connections to port *8080*. `match_nodes` stanza can accept one *match item* or more like in our case. We've used two *match items* consequently there will be two *rules* generated. The same is valid for `rules`, you can pass one hash or an array of hashes. Basically if you do so you get all of the *rules* generated for each *match item*.

Notably, any of the values in the `rules` hash can be a block, in which case it
is executed with a hash argument containing both the match data, retrieved with the **matched_hosts**  key and all those values you passed via match item options hash.

Futher more the shorewall cookbook search implementaion was heavily reworked and now it provides puggable search capability. You can pass a hash configuring user defined search operation. For how to achieve this dive into the library code:)


# Explicit configuration via role/environment attributes

You can use roles or environments to set up attributes.

    "shorewall" => {
        "rules" => [
          {
            :description => "Access to API from other API nodes",
            :action => :ACCEPT,
            :source => :api,
            :dest => :fw,
            :proto => :tcp,
            :dest_port => "8080,8088"
          }
        ],
        "zones" => [
          { :zone => "api:lan", :type => "ipv4" },
          { :zone => "webf:lan", :type => "ipv4" },
        ],
        "zone_interfaces" => {
          "api" => "eth0",
          "webf" => "eth0"
        },
        "zone_hosts" => {
          "api" =>  "search:role:api",
          "webf" => "search:role:webfront"
        }
    }

This is the paste of a role default attributes section.

# Zone odering

Shorewall **zones order** is an important configuration issue. Namely the default zone `net` is located in the end of the zone file, since it has a capture for all the addresses (`0.0.0.0/0`). Putting the `net` zone in the begining we will end up with all the packets going to its corresponding iptables chain.

The shorewall cookbook gives you a capabilty to define the desired order with the `shorewall.zones_order` attribute which is **"fw,lan,net"** by default. Just set the order by providing the string like "fw,lan,api,webf,net".

But relax maybe we don't need to give the order attribute. We've already defined nested zones,  as you could probably noticed there are two zones mentioned in the previous section. These zones are nested shorewall zones defined like "child:parent[,parent]".  The absence of specifically given `shorewall.zones_order` means that the shorewall cookbook will automatically determine the right order for you.

# Attributes

 - `shorewall/zones` - sets up the shorewall zone configuration (array of hashes). Three zones are created by default: **fw, lan, net**.
 - `shorewall/policy` - shorewall policy (array of hashes).
 - `shorewall/zones_order` - order of zones which will be used when writing the shorewall zones file. The order should respect parents which are supposed to go first. Default is **"fw,lan,net"**.
 - `shorewall/interface_settings/INTERFACE` - shorewall interface settings like broadcast and options, it already has the default value `shorewall.interface_settings.default`. However it can have per-interface setting, just add your interface to the `shorewall.interface_settings` hash.
 - `shorewall/enabled` - the state of shorewall service enabled/disabled. By default, it's set to `true`.
 - `shorewall/zone_hosts/ZONE` - specifies the rule for setting up a particular zone. By default, for **lan, net** zones it's set to **"search:\*.\*"** and **"0.0.0.0/0"** respectively.
 - `shorewall/zone_interfaces/ZONE` - specify the interface where particular zone resides. Defaults **"lan" => "eth0", "net" => "eth0"**.
 - `shorewall/public_zones` - specify that the public ip address will be retrieved for a zone (array). By default the zone **net** is only included.
 - `shorewall/rules`, `shorewall/policy`, `shorewall/hosts`, `shorewall/interfaces` configure the relevant shorewall files.

*Important:* In previuos version of cookbook there were many override attributes. The new version of cookbook is suppused to run on chef11 which doesn't have weird attribute behaviour. So all of the attributes are set back to default level of precedence. Be aware if you override some attribute now it will loose it's default values.

For more details, see the `attributes/default.rb` file.

# Limitations

Patches to address any of these items would be gratefully accepted.

* Includes a hardcoded, non-configurable versions of the `shorewall.conf` file.
* Supports Ubuntu, Debian, but other OS targets should be both worthwhile and straightforward.
* Not all of shorewall's configuration is mapped.
* No thought has been given to IPv6 support.


Authors
=======
* Denis Barishev (<denis.barishev@gmail.com>)
* Charles Duffy (<charles@poweredbytippr.com>)
