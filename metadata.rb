maintainer		    "Denis Barishev"
maintainer_email	"denz@twiket.com"
license			      "Apache 2.0"
description		    "Configures iptables with Shorewall"
long_description	IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version			      "0.12.14"

recipe "shorewall", "Configures and activates Shorewall firewall"

%w{ubuntu debian}.each do |dep|
  supports dep
end
