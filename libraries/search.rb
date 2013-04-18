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
require 'chef/config'
require 'chef/log'
require 'chef/dsl/data_query'

module Shorewall

  def self.search(config)
    Search.new(config).execute
  end

  class Search
    include Chef::DSL::DataQuery

    PRIVATE_RANGES = ['192.168.0.0/16', '172.16.0.0/12', '10.0.0.0/8'].map {|ip| IPAddr.new(ip)}

    def initialize(config={})
      @config = Shorewall::Helpers.config_stanza(config)
    end

    def execute
      if search_type == :static
        Array(@config[:rule])
      else
        if Chef::Config[:solo]
          Chef::Log.warn("Shorewall node search doesn't work with chef-solo, will end up with an empty result")
          return []
        end
        check_config_stanza!
        find_nodes do |nodes|
          retrieve_ipaddrs(nodes)
        end
      end
    end

    # retrieve the list of ip addresses all of the given nodes
    def retrieve_ipaddrs(nodes)
      found          = []
      nodes.each do |node|
        found += get_eth_ipaddrs(node).select do |ip|
          @config[:public] ^ PRIVATE_RANGES.any? {|range| range.include?(ip)}
        end
      end
      # make the ip address list unique
      found.uniq.map {|ip| ip.to_s}
    end

    private

    # determine the search type
    def search_type
      @search_type ||=  case @config[:rule]
                        when String
                          type, criteria = @config[:rule].split(':', 2)
                          if type == 'search'
                            @config[:rule] = criteria
                            :chef
                          else
                            :static
                          end
                        when Hash
                          @config[:rule][:search].to_sym
                        end
    end

    # execute the particular search method
    def find_nodes(&block)
      if block.nil?
        self.send("search_#{search_type}")
      else
        block.call(self.send("search_#{search_type}"))
      end
    end

    # extract ipv4 addresses for the particular interface
    def get_eth_ipaddrs(node)
      addresses = []
      begin
        node['network']['interfaces'].each do |eth, opts|
          # aliased interfaces are the same entity for shorewall
          eth = eth.split(':').first
          next unless eth == @config[:interface]
          opts['addresses'].each do |ip, eth_opts|
            addresses << IPAddr.new(ip) if eth_opts['family'] == 'inet'
          end
        end
      rescue
        Chef::Log.warn("Shorewall search couldn't get ip addresses for #{node} on #{@config[:interface]} interface")
      end
      addresses
    end

    # Execute the default chef search method to lookup nodes
    def search_chef
      search(:node, @config[:rule])
    end

    def check_config_stanza!
      opts     = [:rule, :public, :interface]
      notfound = opts.find {|s| @config[s].nil?}
      raise RuntimeError.new("Shorewall config stanza requires the :#{notfound} option!") if notfound
    end
  end

end