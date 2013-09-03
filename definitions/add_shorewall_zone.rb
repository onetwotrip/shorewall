#
# Author:: Denis Barishev (<denis.barishev@gmail.com>)
# Cookbook Name:: shorewall
# Definition:: add_shorewall_zone
#
# Copyright 2013, Twiket LTD
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

define :add_shorewall_zone, :type => 'ipv4', :public_zone => nil, :interface_settings => nil do
  zone = Shorewall::Zone.new(params[:name])
  iface = params[:interface] or raise ArgumentError.new("add_shorewall_zone requires the interface parameter")
  position = [:after, :before].select {|o| not params[o].nil?}.first

  # The zone is not nested, we must use order
  if zone.parent_names.empty?
    if position.nil?
      Chef::Log.error("add_shorewall_zone: specify one of order parameters `after` or `before'")
      raise ArgumentError.new("add_shorewall_zone requires order to be specified for a none-nested zone")
    end
    border = params[position]
    order_index = Shorewall.zone_list.order.find_index(border)
    if order_index.nil?
      Chef::Log.error("add_shorewall_zone unable to add zone `#{zone.name}' #{position} `#{params[position]}'")
      return
    end
    order_index += 1 if position == :after
    Shorewall.zone_list.order.insert(order_index, zone.name)
  elsif not position.nil?
    Chef::Log.debug("add_shorewall_zone ignores position `#{position}' for a nested zone")
  end

  if not params[:interface_settings].nil?
    node.default['shorewall']['interface_settings'][iface] << params[:interface_settings]
  end
  node.default['shorewall']['zone_hosts'][zone.name] = params[:hosts] unless params[:hosts].nil?
  node.default['shorewall']['public_zones'] << zone.name if params[:public_zone] == true
  node.default['shorewall']['zone_interfaces'][zone.name] = iface
  node.default['shorewall']['zones'] << {zone: zone.zone, type: params[:type]}

  Shorewall.setup
end
