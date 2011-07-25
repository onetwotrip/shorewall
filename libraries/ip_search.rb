require 'ipaddr'

# search for nodes with a specified criteria
def search_nodes(search_criteria, mandatory=false)
  retval = []
  search(:node, search_criteria).each do |matching_node|
    break if matching_node == :node
    # reduce returned node information to name and network information
    retnode = Mash.new({
      :hostname => matching_node[:hostname],
      :fqdn => matching_node[:fqdn],
      :network => Mash.new(matching_node[:network].to_hash)
    })
    retval << retnode
  end
  if mandatory and retval.length == 0
    raise "no matches for mandatory search #{search_criteria}"
  end
  return retval
end

# extract ip addresses
# aliased interfaces eth0, eth0:0 are supposed to be identical for firewall
def get_ipv4_addresses(node_def, interface)
  addresses = []
  return addresses if node_def['network'] == nil # node may have no ohai data yet
  node_def["network"]["interfaces"].each_pair do |ifname, ifdata|
    next if ! ifdata["addresses"]
    next if ifname.split(":")[0] != interface
    ifdata["addresses"].each_pair do |ip_str, ip_data|
      if ip_data["family"] == "inet"
        addresses << IPAddr.new(ip_str)
      end
    end
  end
  return addresses
end

# get nodes addresses on a specified interface
def get_addresses(node_list, interface, public=false)
  addresses = []
  private_ranges = node[:shorewall][:private_ranges].map { |ip_str| IPAddr.new(ip_str) }
  if !node_list.is_a?(Array)
    node_list = [node_list]
  end
  node_list.each do |anode|
    get_ipv4_addresses(anode, interface).select { |ip_addr|
      public ^ private_ranges.any? { |range| range.include?(ip_addr) }
    }.each do |ip_addr|
      addresses << ip_addr.to_s
    end
  end
  return addresses
end

require 'set'

# calculate rules content, group nodes if specified
def calc_rules(rules, matched_nodes, match_data)
  crules = rules.clone
  data = { :match => match_data }
  [:source, :dest].each do |dir|
    if rules[dir].is_a?(Hash)
      zone = rules[dir][:zone]
      proc = rules[dir][:proc]
      public = rules[dir][:public] ? true : false
    else
      next
    end
    addresses = get_addresses(matched_nodes, node[:shorewall][:zone_interfaces][zone], public)
    if proc
      if matched_nodes.is_a?(Array)
        raise "proc is not suppused to use with a group rule"
      end
      data.merge!({
        :addresses => addresses.join(','),
        :node => matched_nodes
      })
      crules[dir] = proc.call(data)
    # automatic addresses substitution
    elsif zone
      crules[dir] = "#{zone}:#{addresses.join(',')}"
    end
  end
  crules.merge!(crules) do |k,v,_|
    v = v.call(data) if v.is_a?(Proc)
    next v
  end
end

def add_shorewall_rules(match_nodes, rules, mandatory=false)
  done_nodes = Set.new
  match_nodes.each do |search_rule, match_data|
    matched_nodes = search_nodes(search_rule, mandatory)
    if [:source, :dest].map { |dir| rules[dir].is_a?(Hash) and rules[dir][:group] }.any?
      node.override[:shorewall][:rules] << calc_rules(rules, matched_nodes, match_data)
    else
      matched_nodes.each  do |a_node|
        next if done_nodes.include?(a_node)
        done_nodes.add(a_node)
        node.override[:shorewall][:rules] << calc_rules(rules, a_node, match_data)
      end
    end
  end
end
# vim: ai et sts=2 sw=2 ts=2
