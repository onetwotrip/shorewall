#
# Author:: Denis Barishev (<denis.barishev@gmail.com>)
# Cookbook Name:: shorewall
# Recipe:: config
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

restart_action = :restart

case node['platform']
when "ubuntu"
  package("ufw") {action :remove}
  directory "/var/lock/subsys"
end

package "shorewall" do
  action :install
end

# Set up the shorewall attributes
self.send(:extend, Shorewall::Helpers)
self.configure_shorewall

if node['shorewall']['skip_restart']
  Chef::Log.warn("recipe[#{cookbook_name}::#{recipe_name}] skip_restart is enabled, skipping the shorewall restart!")
  restart_action = :nothing
end

node['shorewall']['actions'].each do |name|
  shorewall_action name do
    source "actions/#{name}"
  end
end

# Create shorewall configuration files
[ 
  'actions',
  'hosts',
  'interfaces',
  'policy',
  'rules',
  'zones'
].each do |file_name|

  template "/etc/shorewall/#{file_name}" do
    mode      0600
    owner     "root"
    group     "root"
    source    "#{file_name}.erb"
    notifies  restart_action, "service[shorewall]"
  end

end  

template "/etc/shorewall/shorewall.conf" do
  source "shorewall.conf.erb"
  mode 0600
end

template "/etc/default/shorewall" do
  source "default.erb"
  mode 0644
end
