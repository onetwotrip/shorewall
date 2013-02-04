# Sort shorewall zones to appear in the right order in the zones file
#
def order_zones()
  # get zone name from a definition which is a hash, in case :zone => "data:lan" ==> "data"
  p_zone_name = lambda{|d| d[:zone].split(':')[0]}
  # retrieve zone definition from a given list
  p_zone_def = lambda{|list, name| list.find {|d| p_zone_name.call(d) == name} }
  # retrieve list of zone parents
  p_zone_parents = lambda{|zonedef| zonedef[:zone].include?(':') ? zonedef[:zone].split(':')[1].split(',') : []}

  # Make initial order which is specified with the order attribute
  unordered = node[:shorewall][:zones].dup
  ordered = node[:shorewall][:zones_order].split(',').map {|n| unordered.delete(p_zone_def.call(unordered, n)) }

  # Make a correct order
  while not unordered.empty? do
    # Sort putting all zone definitions to the begining when they have all of the parents present in the ordered list
    # Namely if we have data1:data,lan data:lan, and since lan is already in the ordered list data:lan will go first.
    #
    unordered = unordered.sort_by do |d|
      parents = p_zone_parents.call(d)
      if parents.empty?
        Chef::Log.error("Zone `#{p_zone_name.call(d)}` must be either nested or explicitly present in `zones_order` attribute")
        raise RuntimeError.new
      end
      parents.none? {|p| p_zone_def.call(ordered, p).nil?} ? -1 : 0
    end
    to_ordered = unordered.shift

    # Get the latest parent of the nested zone
    begin
      # Get the maximum index of a parent in ordered list and put the child stright after his parenent
      latest = p_zone_parents.call(to_ordered).map {|name| ordered.index{|e| p_zone_name.call(e) == name}}.max
      ordered.insert(latest+1, to_ordered)
    rescue
      not_defined = p_zone_parents.call(to_ordered).find {|name| p_zone_def.call(node[:shorewall][:zones], name) == nil}
      Chef::Log.error("Zone `#{not_defined}` is not defined, check zones configuration")
      raise RuntimeError.new
    end
  end

  # Save zones in an ordered manner into the override attributes
  node[:shorewall][:zones].clear
  ordered.each {|e| node.override[:shorewall][:zones] << e}
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
