maintainer		'Denis Barishev'
maintainer_email	'denz@twiket.com'
license			"Apache 2.0"
description		"Configures iptables with Shorewall"
long_description	IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version			'0.0.6'

recipe "shorewall", "Configures and activates Shorewall firewall"

%w{centos ubuntu debian}.each do |dep|
  supports dep
end

attribute "shorewall/enabled",
  :display_name => "Shorewall enabled?",
  :description => "Whether to activate the applied firewall configuration",
  :required => "recommended",
  :choice => [ "true", "false" ],
  :type => "string",
  :default => "false"
