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

require 'chef/mash'

module Shorewall

  class Provider

    def initialize(search_rule)
      @search_rule = search_rule
    end

    def self.search_providers
      @@search_providers ||= []
    end

    def self.inherited(child)
      search_providers.push(child) if !search_providers.include?(child)
    end

    def self.create_instance(search_rule)
      search_providers.each do |pklass|
        return pklass.new(search_rule) if pklass.is_type?(search_rule)
      end
      raise RuntimeError.new("No provider found for search type `#{search_rule.type}'")
    end

    def execute
      hosts = []
      check
      find_nodes.each do |node|
        hosts += retrieve_addresses(node)
      end
      hosts.uniq.sort.map {|ip| ip.to_s}
    end

    def check; end

    def retrieve_addresses(node)
      raise NotImplementedError.new("#{self.class} retrieve_addresses method not implemented!")
    end

    def find_nodes
      raise NotImplementedError.new("#{self.class} find_nodes method not implemented!")
    end

    def self.is_type?(search_rule)
      raise NotImplementedError.new("#{self} is_type? class method not implemented!")
    end
  end

end
