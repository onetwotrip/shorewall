#
# Cookbook Name:: shorewall
# Definition:: action
#

define :shorewall_action, :action => :create do
  aname = params[:name]
  cookbook = params[:cookbook] || self.cookbook_name
  file "/etc/shorewall/action.#{aname}" do
    action params[:action]
  end
  cookbook_file "/etc/shorewall/#{aname}" do
    mode 0600
    owner 'root'
    group 'root'
    source params[:source]
    action params[:action]
    notifies(*params[:notifies]) if params[:notifies]
    cookbook cookbook
  end
end
