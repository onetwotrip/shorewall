#
# Author:: Charles Duffy (<charles@poweredbytippr.com>)
# Cookbook Name:: shorewall
# Library:: shorewall_formatting
#
# Copyright 2011, Charles Duffy
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

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