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

require 'singleton'
require 'set'

module Shorewall

  class Config
    include Singleton

    attr_reader :node, :zone_list

    # shorewall configuration uses node object
    def use(node)
      @node = node
    end

    def setup
      setup_zones
      with_pif_zones do |eth, zones|
        setup_interface(eth, zones)
        setup_host(eth, zones)
      end
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

    private

    # Create zone list and arrange it
    def setup_zones
      @zone_list ||= ZoneList.new
      zone_list.arrange
    end

    # Populate node['shorewall']['interfaces'] attributes
    #
    def setup_interface(eth, zones)
      unless node['shorewall']['interfaces'].any? {|h| h['interface'] == eth }
        node.default['shorewall']['interfaces'] << interface_settings(eth)
        # populate interfaces attributes with eth => zone,
        # since the current interface has only one zone. Otherwise leave it empty.
        if zones.size == 1
          node.default['shorewall']['interfaces'].last['zone'] = zones.first
        end
      end
    end

    # Populate node['shorewall']['hosts'] attributes.
    # Performs actual shorewall search operation.
    #
    def setup_host(eth, zones)
      zones.each do |zone|
        # skip zone addition if already added or this particular interface has only one zone
        next if zones.size == 1 || node['shorewall']['hosts'].any? {|o| o['zone'] == zone}
        options = {}
        builtin = [:nosearch, :chefsearch]
        osearch = node['shorewall']['zone_hosts'][zone]

        if osearch.nil?
          Chef::Log.warn("Shorewall zone_hosts configuration is not defined for the zone #{zone}")
          next
        end

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

    # Interate pifs along with zones
    #
    def with_pif_zones
      hash = {}
      node['shorewall']['zone_interfaces'].each do |zone, eth|
        hash.has_key?(eth) or hash[eth] = SortedSet.new
        hash[eth].add(zone)
      end
      hash.each do |eth, zones|
        yield(eth, zones.to_a)
      end
    end

  end

  Configuration ||= Config.instance
end
