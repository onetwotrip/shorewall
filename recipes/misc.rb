#
# Author:: Denis Barishev (<denis.barishev@gmail.com>)
# Cookbook Name:: shorewall
# Recipe:: misc
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

if node['shorewall']['configuration']['ssh_enabled']
  rule = {
    :description => "Incoming SSH to firewall",
    :source => :all,
    :dest => :fw, 
    :proto => :tcp,
    :dest_port => 22,
    :action => :ACCEPT
  }
  rate_limit = node['shorewall']['configuration']['ssh_rate_limit'].to_s
  rule.merge!({:rate_limit => "s:ssh:#{rate_limit}"}) if not rate_limit.empty?
  node.default['shorewall']['rules'] << rule
end
