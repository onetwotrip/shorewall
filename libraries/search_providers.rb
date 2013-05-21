#
# Author:: Denis Barishev (<denis.barishev@gmail.com>)
# Cookbook Name:: shorewall
# Library:: search_providers
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

require 'chef/config'
require 'chef/log'
require 'chef/dsl/data_query'
require 'ipaddr'

require 'json'

module Shorewall
  class Provider

    # StaticSearch uses the rule of String type.
    # Rule must not begin with "search:xxx" (which is used for the default chef search operation)
    #
    class StaticSearch < Provider
      def self.is_type?(search_rule)
        search_rule.type == 'no_search'
      end

      # == return just the search string, because no actual search must be executed
      #
      def execute
        Array(@search_rule.rule)
      end
    end

    # ChefSearch class uses chef search facility to find nodes in chef
    # and extract needed ip addresses from the given network interface
    #
    class ChefSearch < Provider
      include Chef::DSL::DataQuery

      PRIVATE_RANGES = ['192.168.0.0/16', '172.16.0.0/12', '10.0.0.0/8'].map {|ip| IPAddr.new(ip)}

      def self.is_type?(search_rule)
        search_rule.type == 'chef_search'
      end

      def find_nodes
        search(:node, @search_rule.rule)
      end

      def check
        if @search_rule.options[:interface].to_s.empty?
          Chef::Log.error("You must provide :interface option for #{self.class}")
          raise RuntimeError.new("#{self.class} wrong search options!")
        end
      end

      # == retrieve_addresses exracts all matched address of the specified interface.
      #
      def retrieve_addresses(node)
        # filter out either private or public addresses (by default private is processed)
        addresses_on_physinterface(node, @search_rule.options[:interface]).select do |ip|
          @search_rule.options[:public] ^ PRIVATE_RANGES.any? {|range| range.include?(ip)}
        end
      end

      # get address of the physical interface (not alias)
      #
      def addresses_on_physinterface(node, interface)
        addresses = []
        begin
          node['network']['interfaces'].each do |eth, opts|
            # aliased interfaces are the same entity for shorewall
            eth = eth.split(':').first
            next unless eth == interface
            opts['addresses'].each do |ip, eth_opts|
              addresses << IPAddr.new(ip) if eth_opts['family'] == 'inet'
            end
          end
        rescue
          Chef::Log.warn("Shorewall search couldn't get ip addresses for #{node} on #{interface} interface")
        end
        addresses
      end
    end

  end
end
