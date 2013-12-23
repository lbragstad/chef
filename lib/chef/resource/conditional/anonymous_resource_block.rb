#
# Author:: Adam Edwards (<adamed@getchef.com>)
# Copyright:: Copyright (c) 2013 Opscode, Inc.
# License:: Apache License, Version 2.0
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
#

require 'chef/resource'

class Chef
  class Resource::Conditional
    class AnonymousResourceBlock

      def self.well_formed?(*args, &block)
        args.size == 0 && block_given?
      end

      def self.from_resource_symbol(parent_resource, resource_symbol, inherited_attributes, handled_exceptions, source_line, *args, &block)
        resource_class = get_resource_class(parent_resource, resource_symbol, *args, &block)

        raise ArgumentError, "Specified resource #{resource_symbol.to_s} unknown for this platform" if resource_class.nil?

        empty_events = Chef::EventDispatch::Dispatcher.new
        anonymous_run_context = Chef::RunContext.new(parent_resource.node, {}, empty_events)
        anonymous_resource = resource_class.new('anonymous', anonymous_run_context)

        new(anonymous_resource, parent_resource, inherited_attributes, handled_exceptions, source_line, &block)
      end

      def evaluate_action
        @resource.instance_eval(&@block)

        begin
          @resource.run_action(@resource.action)
          resource_updated = @resource.updated
        rescue *@handled_exceptions
          resource_updated = nil
        end

        resource_updated
      end

      private

      def self.get_resource_class(parent_resource, resource_symbol, *args, &block)
        if well_formed?(*args, &block)
          if parent_resource.nil? || parent_resource.node.nil? 
            raise ArgumentError, "Node for anonymous resource must not be nil"
          end
          Chef::Resource.resource_for_node(resource_symbol, parent_resource.node)
        end
      end

      def initialize(resource, parent_resource, inherited_attributes, handled_exceptions, source_line, &block)
        @resource = resource
        @block = block
        @handled_exceptions = handled_exceptions ? handled_exceptions : []
        merge_inherited_attributes(parent_resource, inherited_attributes, source_line)
      end

      def merge_inherited_attributes(parent_resource, inherited_attributes, source_line)
        if inherited_attributes
          inherited_attributes.each do |attribute|
            if parent_resource.respond_to?(attribute) && @resource.respond_to?(attribute)
              parent_value = parent_resource.send(attribute)
              child_value = @resource.send(attribute)
              if parent_value || child_value
                @resource.send(attribute, parent_value)
              end
            end
          end
        end

        @resource.source_line = source_line
      end
    end
  end
end
