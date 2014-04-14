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

Shorewall cookbook uses a set of attributes `zones, policy, rules...` to setup vital configuration for the shorewall files. The default configuration of those file will make shorewall block everything but SSH connections. So you should look through the attributes before using the cookbook.

There are two endpoints for configuration data input. Respectively *roles, environments* along with `add_shorewall_rules` definition. I strongly encourage to use `add_shorewall_rules` for configuring the shorewall rules instead of *roles or environments*.

## Using **add_shorewall_rules** definition

This definition allows you to add rules to the shorewall right away from the recipe code.

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


...in the above case, we're using the `add_shorewall_rules` definition to `ACCEPT` connections to port *8080*. `match_nodes` stanza can accept one *match item* or more like in our case. We've used two *match items* consequently there will be two *rules* generated. The same is valid for `rules`, you can pass one hash or an array of hashes. Basically, if you do so you get all of the *rules* generated for each *match item*. When creating static rules which don't require hosts matching you are free to omit *match_nodes*.

Notably, any of the values in the `rules` hash can be a block, in which case it
is executed with a hash argument containing both the match data, retrieved with the **matched_hosts**  key and all those values you passed via match item options hash.

## Using **add_shorewall_zone** definition

Another usage pattern comes when we want to add zones on runtime right away from the recipe code. Here comes `add_shorewall_zone` definition which expects zone name as the first argument and all the configuration parameters passed as always via block. The list of parameters:

 * `interface` - is a **required** parameter which sets the physical interface for the new zone.
 * `after`, `before` - positioning parameters used when a non-nested zone is created, since we don't know where the zone should be actually placed. These parameters are ingnored when we create a nested zone. The nested zone is always automatically placed right after its parent(s).
 * `hosts` - the zone hosts search expression, which populates zones hosts via the shorewall search operation.
 * `public` - specifies if addresses of the zone are public or private. Default is `false`.

Typical usage of the definition might look as follows:

    add_shorewall_zone 'test1' do
      interface Shorewall.zone_interface('lan')
      hosts '192.168.0.128/25'
      after 'lan'
      public false
    end

It's worth mentioning that `interface` is a required option, to simplify interface choosing a helper method `zone_interface` might be used. Also `hosts` option which basically can be omitted in case it's a *single interface zone*, expects a valid search expression for example like `search:roles:test1`

# Library information

The shorewall cookbook search implementation was heavily reworked since 0.12.0 version and now it provides pluggable search capability. You can pass a hash configuring user defined search operation. For how to achieve this dive into the library code:)

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

# Zone ordering

Shorewall **zones order** is an important configuration issue. Namely the default zone `net` is located in the end of the zone file, since it has a capture for all the addresses (`0.0.0.0/0`). Putting the `net` zone in the begining we will end up with all the packets going to its corresponding iptables chain.

The shorewall cookbook gives you a capability to define the desired order with the `shorewall.zones_order` attribute which is **"fw,lan,net"** by default. Just set the order by providing the string like "fw,lan,api,webf,net".

But relax maybe we don't need to give the order attribute. We've already defined nested zones,  as you could probably noticed there are two zones mentioned in the previous section. These zones are nested shorewall zones defined like "child:parent[,parent]".  The absence of specifically given `shorewall.zones_order` means that the shorewall cookbook will automatically determine the right order for you.

# Zone scrambled search

The new search mode which makes the address retrieval procedure indifferent to the actual interface. These maybe useful when more sophisticated network layouts are being ran. For example, let's say that we have different networks (**A** and **B**) connected via routable VPN solution. These networks have different interface layouts. LAN network resides on the **eth0** in the first network and on **eth1** in the second network. Without scrambled mode on it's impossible to retrieve private IP address of machines in the remote network. Because the default address retrieval tries to pick up the IP address of the **eth0** interface even if the **B**-network node is found by the search operation. In the given case we should enable scrambled mode, like the following:

    "shorewall": {
      "zone_search_scramble": ["lan"]
    }

By specifying this the *search scrambled* mode will be used when searching for hosts of the **lan** zone. In fact the scrambled mode ignores the actual interface and picks up all private addresses of a particular node.

# Multi-interface zones

Also this is the new feature which is introduced in 0.13.10 version. Now it's possible to do like the following:

    "shorewall": {
      "zone_search_scramble": ["lan"],
      "zone_interfaces": {
        "lan": "tun0,eth0",
        "net": "eth0"
      }
    }

Hosts or interface file are populated several times for each given interface. Shorewall uses hosts file only in case if there is more than one zone on the particular. The configuration above sets two zones: *lan* and *net* on the interface **eth0**. When lan hosts will be populated the default rule `search:*:*` is used. So the search operation takes place only one time, it picks up all the private IP addresses due to the scrambled mode used and multiple hosts rules are inserted for each of the interfaces given (**tun0** and **eth0**).

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
 - `shorewall/zone_search_scrample` - specify the list of zones that will operate in search **scrambled** mode.

**Important:** In previous version of cookbook there were many override attributes. The new version of cookbook is supposed to run on chef11 which doesn't have weird attribute behavior. So all of the attributes are set back to default level of precedence. Be aware if you override some attribute now it will loose its default value.

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
