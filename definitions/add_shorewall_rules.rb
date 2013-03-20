#
# Author:: Denis Barishev (<denis.barishev@gmail.com>)
# Cookbook Name:: shorewall
# Definition:: add_shorewall_rules
#
# Copyright 2011-2013, Twiket LTD
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

define :add_shorewall_rules, :match_nodes => [], :rules => [] do

  # match_nodes we expect as an array or a nested array, so flatten and slice it
  params[:match_nodes].flatten.each_slice(2) do |search_criteria, config|
    stanza = Shorewall::Helpers::config_stanza(config)
    found  = Shorewall.search({
      :rule      => search_criteria,
      :interface => stanza[:interface],
      :public    => stanza[:public]
    })

    # rules we expect as a hash or maybe array of hashes
    (params[:rules].respond_to?(:has_key?) ? [params[:rules]] : params[:rules]).each do |rule|
      rule = Mash.new(rule)
      node.default['shorewall']['rules'] << Shorewall::Helpers.compute_rule(rule, stanza.merge({:matched_hosts => found.join(',')}))
    end
  end

end