require 'set'

case node['platform']
when "centos","redhat","fedora"
  include_recipe "yumrepo::epel"
when "ubuntu"
  package "ufw" do
    action :remove
  end

  directory "/var/lock/subsys" do
    action :create
  end
end

package "shorewall" do
  action :install
end

## FIXME: local logic below
zones_per_interface = {}
node[:shorewall][:zone_interfaces].each_pair do |zone,interface|
  if not zones_per_interface.has_key?(interface)
    zones_per_interface[interface] = SortedSet.new
  end
  zones_per_interface[interface].add(zone)
end

# symbolize keys and inject a new hash hash
default_settings = node[:shorewall][:default_interface_settings].to_hash.keys.inject({}) { |h, k|
  h[k.to_sym] = node[:shorewall][:default_interface_settings][k]; h
}

zones_per_interface.each_pair do |interface,zones|
  if zones.length > 1
    unless node[:shorewall][:interfaces].any? { |iface| iface[:interface] == interface }
      node.override[:shorewall][:interfaces] << default_settings.merge({:interface => interface})
    end
    zones.each do |zone|
      zone_hosts = node[:shorewall][:zone_hosts][zone]
      if zone_hosts != nil
        if zone_hosts =~ /^search:(.*)$/
          search_exp = Regexp.last_match(1)
          public = node[:shorewall][:public_zones].include?(zone)
          addresses = get_addresses(search_nodes(search_exp), interface, public).join(',')
        else
          addresses = zone_hosts
        end
        node.override[:shorewall][:hosts] << {
          :zone => zone,
          :hosts => "#{interface}:#{addresses}"
        }
      end
    end
  else
    unless node[:shorewall][:interfaces].any? { |iface| iface[:interface] == interface }
      node.override[:shorewall][:interfaces] << default_settings.merge({
       :zone => zones.to_a[0],
       :interface => interface
      })
    end
  end
end

if node[:shorewall][:skip_restart].to_s == "true"
  Chef::Log.warn("recipe[#{cookbook_name}::#{recipe_name}] :skip_restart is enabled, skipping the shorewall restart!")
end

incookbook_actions = [ 'Limit' ]
incookbook_actions.each do |act|
  shorewall_action act do
    source "actions/#{act}"
    notifies(:restart, "service[shorewall]") unless node[:shorewall][:skip_restart].to_s == "true"
  end
end

template "/etc/shorewall/actions" do
  source "actions.erb"
  mode 0600
  owner "root"
  group "root"
  notifies(:restart, "service[shorewall]") unless node[:shorewall][:skip_restart].to_s == "true"
end

template "/etc/shorewall/hosts" do
  source "hosts.erb"
  mode 0600
  owner "root"
  group "root"
  notifies(:restart, "service[shorewall]") unless node[:shorewall][:skip_restart].to_s == "true"
end

template "/etc/shorewall/interfaces" do
  source "interfaces.erb"
  mode 0600
  owner "root"
  group "root"
  notifies(:restart, "service[shorewall]") unless node[:shorewall][:skip_restart].to_s == "true"
end

template "/etc/shorewall/policy" do
  source "policy.erb"
  mode 0600
  owner "root"
  group "root"
  notifies(:restart, "service[shorewall]") unless node[:shorewall][:skip_restart].to_s == "true"
end

template "/etc/shorewall/rules" do
  source "rules.erb"
  mode 0600
  owner "root"
  group "root"
  notifies(:restart, "service[shorewall]") unless node[:shorewall][:skip_restart].to_s == "true"
end

order_zones()
template "/etc/shorewall/zones" do
  source "zones.erb"
  mode 0600
  owner "root"
  group "root"
  notifies(:restart, "service[shorewall]") unless node[:shorewall][:skip_restart].to_s == "true"
end

shorewall_enabled = [true, "true"].include?(node[:shorewall][:enabled])
template "/etc/shorewall/shorewall.conf" do
  source "shorewall.conf.erb"
  mode 0600
end

case node[:platform]
when "debian", "ubuntu"
  template "/etc/default/shorewall" do
    source "default.erb"
    mode 0644
  end
end

service "shorewall" do
  supports [ :status, :restart ]
  action shorewall_enabled ? [:start, :enable] : :disable
end

# vim: ai et sts=2 sw=2 sts=2
