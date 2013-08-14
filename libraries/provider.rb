#
# Author:: Denis Barishev (<denis.barishev@gmail.com>)
# Cookbook Name:: shorewall
# Library:: search_provider
#
# Copyright 2013, Twiket LTD
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

class Shorewall

  class Provider
    @@PROVIDERS ||= {} # chef multi-time code load prevention ^_^

    def initialize(search_rule)
      @search_rule = search_rule
    end

    # build hash of provider types
    def self.inherited(subclass)
      search_type = subclass.name.split('::').last.sub(/\W/, '').downcase.to_sym
      unless @@PROVIDERS[search_type].nil?
        raise RuntimeError.new("Provider #{@@PROVIDERS[search_type]} exists for type :#{search_type}")
      end
      @@PROVIDERS[search_type] = subclass
    end

    def self.klass(type)
      @@PROVIDERS[type] or raise TypeError.new("Shorewall provider for :#{type} doesn't exist")
    end

    def execute
      hosts = []
      check
      search_nodes.each do |node|
        hosts += extract_addresses(node)
      end
      # remove nil address, remove duplicates and sort
      hosts.compact.uniq.sort.map {|addr| addr.to_s}
    end

    def check
    end

    def search_nodes
      raise NotImplementedError.new("#{self.class} search_nodes method not implemented")
    end

    def extract_addresses(node)
      raise NotImplementedError.new("#{self.class} extract_addresses method not implemented")
    end
  end

end
