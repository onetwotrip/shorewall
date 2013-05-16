#
# Author:: Denis Barishev (<denis.barishev@gmail.com>)
# Cookbook Name:: shorewall
# Library:: search
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

require 'chef/mash'

module Shorewall

  # SearchRule the search configuration placeholder class
  #
  class SearchRule
    attr_accessor :rule, :type, :options

    def initialize(search, options)
      # a custom rule is hash, here we store rule and options in the same mash
      if search.kind_of?(Hash)
        mash  = Mash.new(search)
        @type = mash.delete(:search)
        @rule = mash.merge(Mash.new(options))
        @options = @rule

      # built-in rule will be processed with the standard provider
      elsif search.is_a?(String)
        prefix, solrstr = search.split(":", 2)
        if prefix == "search"
          @type = "chef_search"
          @rule = solrstr
        else
          @type = "no_search"
          @rule = search
        end
        @options = Mash.new(options)
      else
        raise NotImplementedError.new("#{self.class} unsuported search expression type #{search.class}")
      end
    end
  end

  def self.search(search, options = {})
    Provider.create_instance(SearchRule.new(search, options)).execute
  end
end
