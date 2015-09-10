maintainer        "OTT Operations"
maintainer_email  "operations@onetwotrip.com"
license           "Apache 2.0"
description       "Configures iptables with Shorewall"
long_description  IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version           "0.13.11"
name              "shorewall"

recipe "shorewall",         "Set up Shorewall firewall"
recipe "shorewall::config", "Configure shorewall. Install the package and create files the service won't be activated"

%w{ubuntu debian}.each do |dep|
  supports dep
end

depends 'partial_search', '~> 1.0.8'
