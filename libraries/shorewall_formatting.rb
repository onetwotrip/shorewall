#
# arrange shorewall.zones array in the right order
#
def order_zones()
  zones = node[:shorewall][:zones].clone
  node[:shorewall][:zones].clear
  ordered = node[:shorewall][:zones_order].split(",")
  # put zones in the specified order
  ordered.each do |s_zone|
    zone = zones.select { |el| el[:zone] == s_zone or el[:zone] =~ /#{s_zone}:/ }[0]
    node.override[:shorewall][:zones] << zones.delete(zone)
  end
  return if zones.empty? == true
  # more zones left which we include automatically (but if only they are nested)
  zones.each do |zh|
    if ! zh[:zone].include?(':')
      Chef::Log.error("shorewall zones_order must include zone #{zh[:zone]}") && raise
    end
    parent_zone = zh[:zone].split(":")[1]
    i = node[:shorewall][:zones].index { |el| el[:zone] == parent_zone }
    node[:shorewall][:zones].insert(i+1, zh)
  end
end

def shorewall_format_file(column_defs, data)
  retval = ''
  data.each { |element|
    retval << "\n"
    if element[:description] then
      retval << "# "
      retval << element[:description]
      retval << "\n"
    end
    pos = 0
    column_defs.each { |key, width|
      pos += width
      value = element.fetch(key, '-').to_s
      retval << (('%%-%ds' % width) % value)
      if width != 0 and value.length >= width then
        retval << (" \\\n" + (' ' * pos))
      end
    }
    retval << "\n"
  }
  return retval
end

# vim: ai et sts=2 sw=2 ts=2
