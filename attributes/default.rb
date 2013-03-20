#
# Author:: Denis Barishev (<denis.barishev@gmail.com>)
# Cookbook Name:: shorewall
# Attribute:: default
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

default['shorewall']['enabled']       = true
default['shorewall']['skip_restart']  = false

default['shorewall']['zone_interfaces']['net'] = "eth0"
default['shorewall']['zone_interfaces']['lan'] = "eth0"
default['shorewall']['zone_hosts']['lan'] = "search:*.*"
default['shorewall']['zone_hosts']['net'] = "0.0.0.0/0"

default['shorewall']['default_interface_settings']['broadcast'] = "detect"
default['shorewall']['default_interface_settings']['options']   = "tcpflags,blacklist,routefilter,nosmurfs,logmartians,dhcp"

default['shorewall']['actions'] = [ 'Limit' ]

default['shorewall']['zones'] = [
    { 'zone' => "fw",  'type' => "firewall" },
    { 'zone' => "lan", 'type' => "ipv4" },
    { 'zone' => "net", 'type' => "ipv4" }
]

default['shorewall']['zones_order']   = "fw,lan,net"
default['shorewall']['public_zones']  = ["net"]

default['shorewall']['policy'] = [
    { 'source' => "fw",  'dest' => "all", 'policy' => 'ACCEPT' },
    { 'source' => "lan", 'dest' => "fw",  'policy' => 'REJECT', 'log' => 'DEBUG' },
    { 'source' => "all", 'dest' => "all", 'policy' => 'REJECT' }
]

default['shorewall']['interfaces']  = []
default['shorewall']['hosts']       = []

default['shorewall']['rules']       = [
    { 'description' => "Incoming SSH to firewall",
      'source' => "all", 'dest' => 'fw', 'proto' => 'tcp', 'dest_port' => 22, 'action' => 'Limit:none:SSHA,5,60'}
]