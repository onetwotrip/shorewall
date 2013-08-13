#
# Author:: Denis Barishev (<denis.barishev@gmail.com>)
# Cookbook Name:: shorewall
# Library:: zones
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

  class Zone
    attr_reader :name, :zone, :type, :parent_names

    def initialize(hash)
      @mash = Mash.new(hash)
      @zone = @mash[:zone]
      @type = @mash[:type]
      @name, parents = @zone.split(':')
      @parent_names = parents.nil? ? [] : parents.split(',')
    end

    def to_hash
      @mash
    end

    def ==(obj)
      self.name == obj.name
    end
  end

  # Ordered zone list class.
  #
  class Config::ZoneList
    attr_reader :zones, :order

    def initialize
      @order = node['shorewall']['zones_order'].split(',')
      @zones = []
      if ['fw', 'lan', 'net'].any? {|n| not order.include?(n)}
        raise RuntimeError.new("zones_order is wrong. One of the default zones fw, lan, net not found")
      end
      populate
    end

    def each(&block)
      zones.each(&block)
    end

    # Arrange zones by populating zones list in the specific order.
    # 1. Insert zones which explicitly present in the order array.
    # 2. Insert nested zones straight after its parents.
    # 3. Fail if the insert order is unresolved.
    #
    def arrange
      unarranged_in_insert_order do |list|
        list.each do |zone|
          orderi = order.find_index(zone.name)
          if orderi.nil? && zone.parent_names.empty?
            raise RuntimeError.new("Shorewall zone[#{zone.name}] add faild. No order or nesting specified!")
          elsif not orderi.nil?
            zones.insert(i, zone)
          else
            insert_zone(zone)
          end
        end
      end
    end

    private

    # unarranged_in_insert_order iterator method produces the desired
    # zones order for insertion.
    #
    def unarranged_in_insert_order
      to_process = node['shorewall']['zones'].select{ |o| not zones.include?(Zone.new(o['zone'])) }

      if not to_process.empty?
        # First process parentless zones
        arrange_list = to_process.select do |hash|
          Zone.new(hash).parent_names.empty?
        end
        yield(arrange_list.map { |h| Zone.new(h)} )
        to_process -= arrange_list

        # Cycle through zones, and yield those which parents have been already ordered,
        # so it's possible to insert them.
        begin
          arrange_list = to_process.select do |hash|
            Zone.new(hash).parent_names.all? {|pn| list_hasname?(pn)}
          end
          yield(arrange_list.map { |h| Zone.new(h) })
          to_process -= arrange_list
        end while not arrange_list.empty?
      end

      if not to_process.empty?
        msg = to_process.map {|o| o['zone']}.join(", ")
        raise RuntimeError.new("Shorewall couldn't arrange zones #{msg}. Check the zones_order!")
      end
    end

    # Insert zone after its parent with the highest index (latest parent)
    def insert_zone(zone)
      parent_with_index = zones.each_with_index.select {|o| zone.parent_names.include?(o.first.name)}
      _, idx = parent_with_index.max {|a, b| a.last <=> b.last}
      zones.insert(idx+1, zone)
      order.insert(idx+1, zone.name)
    end

    # Check the zones list for the zone name existance
    def list_hasname?(name)
      zones.any? {|z| z.name == name}
    end

    def node
      Configuration.node
    end

    # Initial zone list population use the zones_order
    def populate
      order.each do |zn|
        zones << Zone.new(node['shorewall']['zones'].find {|o| o['zone'] == zn})
      end
    end

  end
end
