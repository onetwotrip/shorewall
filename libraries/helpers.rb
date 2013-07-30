#
# Author:: Denis Barishev (<denis.barishev@gmail.com>)
# Cookbook Name:: shorewall
# Library:: helpers
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

module Shorewall
  module Helpers
    require 'set'

    # Create the shorewall configuration and store it the node override attributes.
    # The data needed to construct interfaces and hosts file will be calculated.
    #
    def configure_shorewall
      zones_by_interface.each do |eth, zones|
        # we don't have an interface configuration yet, so we create it
        unless node['shorewall']['interfaces'].any? {|h| h['interface'] == eth }
          node.default['shorewall']['interfaces'] << interface_settings(eth)

          # we've got an interface with the one sole zone
          if zones.size == 1
            node.default['shorewall']['interfaces'].last['zone'] = zones.first
            next
          end
        end
        # we configure an interface with multiple zones
        zones.each do |zone|
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
      sort_nested_zones
    end

    # Compute the value of shorewall rule (for add_shorewall_rules)
    #
    def self.compute_rule(rule, data)
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

    def is_public?(zone)
      node['shorewall']['public_zones'].any? {|z| z == zone}
    end

    # Compose the hash of interface => [zones] mappings
    #
    def zones_by_interface
      return @zones_by_interface if @zones_by_interface
      hash = {}
      node['shorewall']['zone_interfaces'].each do |zone, eth|
        hash.has_key?(eth) or hash[eth] = SortedSet.new
        hash[eth].add(zone)
      end
      # cast the sets back to array
      @zones_by_interface = hash.keys.inject({}) {|h, k| h[k] = hash[k].to_a; h}
    end

    # Compose default interface settings with symbloized keys
    #
    def interface_settings(eth)
      if node['shorewall']['interface_settings'].has_key?(eth)
        node['shorewall']['interface_settings'][eth].merge({:interface => eth})
      else
        node['shorewall']['interface_settings']['default'].merge({:interface => eth})
      end
    end

    # Sort shorewall.zones array to set the right shorewall order
    #
    def sort_nested_zones
      # create initial arrays of already ordered zones and not yet ordered
      notdefined = []
      unordered  = JSON.parse(node['shorewall']['zones'].to_json) # make a deep copy of the zones hash

      ordered    = node['shorewall']['zones_order'].split(',').map do |z|
        ordered_zone = unordered.delete(_zonedef(unordered, z))
        notdefined << z if ordered_zone.nil?
        ordered_zone
      end

      # check if we supplied the propper shorewall.zones definitions
      if !notdefined.empty?
        Chef::Log.error("Shorewall couldn't determine definitions for zone(s): #{notdefined.join(', ')}")
        raise RuntimeError.new("Shorewall zone is not defined")
      end

      # sort zones acording to the shorewall zones nesting
      while !unordered.empty? do
        # if we have data1:data,lan data:lan and since lan is already in the ordered list data:lan will go first.
        unordered = unordered.sort_by do |zdef|
          parents = _get_zone_parents(zdef)
          if parents.empty?
            Chef::Log.error("Zone `#{_zonename(zdef)}` must be either nested or explicitly present in `zones_order` attribute")
            raise RuntimeError.new
          end
          parents.none? {|name| _zonedef(ordered, name).nil?} ? -1 : 0
        end
        to_ordered = unordered.shift

        # choose the latest parent of the nested zone,
        # by using the maximum index of a parent in ordered list and put the child stright after his parent
        begin
          latest = _get_zone_parents(to_ordered).map {|name| ordered.index{|zdef| _zonename(zdef) == name}}.max
          ordered.insert(latest+1, to_ordered)
        rescue
          notfound = _get_zone_parents(to_ordered).find {|name| _zonedef(node['shorewall']['zones'], name).nil?}
          Chef::Log.error("Shorewall zone `#{notfound}` is not defined, check zones configuration")
          raise RuntimeError.new("Shorewall zone #{notfound} not defined")
        end
      end

      # Save zones in an ordered manner into the override attributes
      node.default['shorewall']['zones'] = []
      ordered.each {|e| node.default[:shorewall][:zones] << e}
    end

    def _zonename(zonedef)
      zonedef['zone'].split(':').first
    end

    def _zonedef(list, zone)
      list.find {|zdef| _zonename(zdef) == zone}
    end

    def _get_zone_parents(zonedef)
      zonedef['zone'].include?(':') ? zonedef['zone'].split(':').last.split(',') : []
    end

  end
end