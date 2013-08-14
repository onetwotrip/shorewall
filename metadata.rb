maintainer		    "Denis Barishev"
maintainer_email	"denz@twiket.com"
license			      "Apache 2.0"
description		    "Configures iptables with Shorewall"
long_description	IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version			      "0.13.5"

recipe "shorewall",         "Set up Shorewall firewall"
recipe "shorewall::config", "Configure shorewall. Install the package and create files the service won't be activated"

%w{ubuntu debian}.each do |dep|
  supports dep
end
