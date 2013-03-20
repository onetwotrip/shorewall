#
# Cookbook Name:: shorewall
# Definition:: action
#

define :shorewall_action do
  params[:cookbook] ||= self.cookbook_name.to_s

  file "/etc/shorewall/action.#{params[:name]}"

  cookbook_file "/etc/shorewall/#{params[:name]}" do
    mode      0600
    owner     'root'
    group     'root'
    source    params[:source]
    cookbook  params[:cookbook]
  end
end
