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
          node.default['shorewall']['interfaces'] << default_settings.merge({'interface' => eth})

          # we've got an interface with the one sole zone
          if zones.size == 1
            node.default['shorewall']['interfaces'].last['zone'] = zones.first
            next
          end
        end
        # we configure an interface with multiple zones
        zones.each do |zone|
          search_rule = node['shorewall']['zone_hosts'][zone].to_s
          next if search_rule.empty?
          result = Shorewall.search({
            :rule      => search_rule,
            :interface => eth,
            :public    => is_public?(zone)
          })
          node.default['shorewall']['hosts'] << {'zone' => zone, 'hosts' => "#{eth}:#{result.join(',')}"}
        end
      end
      sort_nested_zones
    end

    # Generate and check shorewall config stanza (for add_shorewall_rules)
    #
    def self.config_stanza(config = {})
      opts     = [:name, :public, :interface]
      defaults =  {
        :public => false
      }
      config   = Mash.new(defaults).merge(config)
      notfound = opts.find {|s| config[s].nil?}
      raise RuntimeError.new("Shorewall config stanza requires the :#{notfound} option!") if notfound 
      config
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
    def default_settings
      @default_settings ||= node['shorewall']['default_interface_settings'].keys.inject({}) do |h, k|
        h[k.to_sym] = node['shorewall']['default_interface_settings'][k]; h
      end
    end

    # Sort shorewall.zones array to set the right shorewall order
    #
    def sort_nested_zones
      # create the initial order of zones acording to the default order - shorewall.zones_order
      unordered = node['shorewall']['zones'].dup
      ordered   = node['shorewall']['zones_order'].split(',').map {|z| unordered.delete(_zonedef(unordered, z))}

      # check if we didn't supply right shorewall.zones
      if ordered.any? {|zdef| zdef.nil?}
        Chef::Log.error("Shorewall couldn't determine zones, check the configuration")
        raise RuntimeError.new
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
          raise RuntimeError.new
        end
      end

      # Save zones in an ordered manner into the override attributes
      node.default['shorewall']['zones'] = []
      ordered.each {|e| node.default[:shorewall][:zones] << e}
    end

    def _zonename(zonedef)
      zonedef[:zone].split(':').first
    end

    def _zonedef(list, zone)
      list.find {|zdef| _zonename(zdef) == zone}
    end

    def _get_zone_parents(zonedef)
      zonedef[:zone].include?(':') ? zonedef[:zone].split(':').last.split(',') : []
    end

  end
end