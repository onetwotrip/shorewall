#
# Author:: Denis Barishev (<denis.barishev@gmail.com>)
# Cookbook Name:: shorewall
# Library:: configuration
#
# Copyright 2011-2013, Twiket LTD
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'chef/log'
require 'singleton'
require 'set'
require 'forwardable'

class Shorewall

  class SingleConfig
    include Singleton

    attr_reader :node, :zone_list

    # shorewall configuration uses node object
    def use(node)
      @node = node
    end

    def setup
      order_zones
      set_eth_defaults
      set_zone_hosts
    end

    # Order node['shorewall']['zones'] array
    def order_node_zones
      node.default['shorewall']['zones'] = []
      zone_list.each {|zone| node.default['shorewall']['zones'] << zone.to_hash}
    end

    def compute_rule(rule, data)
      rule.keys.inject({}) do |hash, key|
        hash[key] = case rule[key]
                      when Proc
                        rule[key].call(data)
                      else
                        rule[key].to_s
                    end
        hash
      end
    end

    def zone_interface(zone_name)
      node['shorewall']['zone_interfaces'][zone_name]
    end

    private

    # Create ordered zone list and populate shorewall.zones attributes
    #
    def order_zones
      @zone_list ||= ZoneList.new
      zone_list.arrange
    end

    # Populate node['shorewall']['interfaces'] attributes, sets the default interface
    # settings and default zone (for single-zone interface)
    #
    def set_eth_defaults(eth_zones_hash)
      eth_zones.each do |eth, zones|
        unless node['shorewall']['interfaces'].any? {|h| h['interface'] == eth }
          node.default['shorewall']['interfaces'] << interface_settings(eth)
          # populate interfaces attributes with eth => zone,
          # since the current interface has only one zone. Otherwise leave it empty.
          if zones.size == 1
            node.default['shorewall']['interfaces'].last['zone'] = zones.first
          end
        end
      end
    end

    # Populate node['shorewall']['hosts'] attributes.
    # Performs actual shorewall search operation.
    #
    def setup_host(eth, zones)
      zones.each do |zone|
        next if zones.size == 1 || node['shorewall']['hosts'].any? {|o| o['zone'] == zone}
        options = {}
        builtin = [:nosearch, :chefsearch]
        osearch = node['shorewall']['zone_hosts'][zone]

        if osearch.nil?
          Chef::Log.warn("Shorewall zone_hosts configuration is not defined for the zone #{zone}")
          next
        end

        if 
        search_rule = Shorewall::SearchRule.new(osearch, {})
        if builtin.include?(search_rule.type)
          options = {
            :interface => eth,
            :public    => is_public?(zone)
          }
        end
        result = Shorewall.search(osearch, options)
        node.default['shorewall']['hosts'] << {'zone' => zone, 'hosts' => "#{eth}:#{result.join(',')}"}
      end
    end

    # Populate shorewall.hosts attributes
    #
    def set_zone_hosts
      ez_hash = eth_zones_hash
      node['shorewall']['zone_hosts'].each do |zone, osearch|
        # Skip zone add if: a) it's already there, b) this is single-zone interface
        #
        skip = node['shorewall']['hosts'].any? {|o| o['zone'] == zone}
        skip ||= eth_zone_count(ez_hash, zone) == 1
        next if skip

        options = {}
        builtin = [:nosearch, :chefsearch]
        osearch = node['shorewall']['zone_hosts'][zone]
        if osearch.nil?
          Chef::Log.warn("Shorewall zone_hosts configuration is not defined for the zone #{zone}")
          next
        end

        add_search_hosts(zone, osearch)
      end
    end

    def add_search_hosts(zone, osearch)
      eths = node['shorewall']['zone_interfaces'][zone].split(',')

      if node['shorewall']['zone_search_scramble'].include?(zone)
        # During scramble search only one search is handled and 
        # the addresses are not bound to any particular interdace.

        options = {scramble: => true, :public => is_public?(zone)}
        found_hosts = Shorewall.search(osearch, options)
        # The same hosts search results will appear on each of the interfaces
        eths.each do |eth|
          node.default['shorewall']['hosts'] << {'zone' => zone, 'hosts' => "#{eth}:#{found_hosts.join(',')}"
        end
      else
        # When normal search occures with search and extract address
        # from the given interface several times.

        eths.each do |eth|
          options = {:interface => eth, :public => is_public?(zone)}
          found_hosts = Shorewall.search(osearch, options)
          node.default['shorewall']['hosts'] << {'zone' => zone, 'hosts' => "#{eth}:#{found_hosts.join(',')}"
        end
      end
    end

    # Verifiy if zone is public or not
    #
    def is_public?(zone)
      node['shorewall']['public_zones'].any? {|z| z == zone}
    end

    # Get the specified interface settings
    #
    def interface_settings(eth)
      if node['shorewall']['interface_settings'].has_key?(eth)
        node['shorewall']['interface_settings'][eth].merge({'interface' => eth})
      else
        node['shorewall']['interface_settings']['default'].merge({'interface' => eth})
      end
    end

    # Creates hash: interface => [zone1, zone2]
    #
    def eth_zones(&block)
      hash = {}
      node['shorewall']['zone_interfaces'].each do |zone, eths|
        # zone_interfaces support multiple values given as comma separated list
        list = eths.split(',')
        list.each do |eth|
          hash.has_key?(eth) or hash[eth] = SortedSet.new
          hash[eth] << zone
        end
      end
      hash
    end


    # Count number if interfaces which zone resides in.
    # Expected input is eth_zones_hash and zone name
    #
    def eth_zone_count(hash, zone)
      hash.inject(0) {|s,o| eth, zones = o; s = s + 1 if zones.include?(zone); s} 
    end

  end

  # Forward interface methods to the SingleConfig.instance
  class << self
    extend Forwardable

    def_delegators 'Shorewall::SingleConfig.instance'.to_sym, :use, :setup, :zone_interface,
      :order_node_zones, :compute_rule, :zone_list
  end

end
