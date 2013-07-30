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

module Shorewall
  class Provider

    # Provider substitues back its search rule, no search is performed
    #
    class NoSearch < Provider
      def execute
        Array(@search_rule.rule)
      end
    end

    # Search provider uses standart chef search to locate node.
    # Extracts address of the given interface.
    #
    class ChefSearch < Provider
      include Chef::DSL::DataQuery

      PRIVATE_RANGES = ['192.168.0.0/16', '172.16.0.0/12', '10.0.0.0/8'].map {|ip| IPAddr.new(ip)}

      def search_nodes
        search(:node, @search_rule.rule)
      end

      def check
        if @search_rule.options[:interface].to_s.empty?
          Chef::Log.error("You must provide :interface option for #{self.class}")
          raise RuntimeError.new("#{self.class} wrong search options!")
        end
      end

      # Filter out either private or public addresses of an interface (by default private is processed)
      def extract_addresses(node)
        pif_addresses(node, @search_rule.options[:interface]).select do |ip|
          @search_rule.options[:public] ^ PRIVATE_RANGES.any? {|range| range.include?(ip)}
        end
      end

      # Get address of a physical interface (including all aliased interfaces)
      def pif_addresses(node, interface)
        addresses = []
        begin
          node['network']['interfaces'].each do |eth, opts|
            next unless eth.split(':').first == interface
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
