#
# Author:: Adam Edwards (<adamed@getchef.com>)
# Copyright:: Copyright (c) 2014 Opscode, Inc.
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
    class GuardInterpreter

      def initialize(resource_symbol, parent_resource, handled_exceptions, source_line=nil)
        resource_class = get_resource_class(parent_resource, resource_symbol)

        raise ArgumentError, "Specified resource #{resource_symbol.to_s} unknown for this platform" if resource_class.nil?

        empty_events = Chef::EventDispatch::Dispatcher.new
        anonymous_run_context = Chef::RunContext.new(parent_resource.node, {}, empty_events)

        @resource = resource_class.new('anonymous', anonymous_run_context)
        @handled_exceptions = handled_exceptions ? handled_exceptions : []
        merge_inherited_attributes(parent_resource)
        @source_line = source_line if source_line
      end

      def evaluate_action(action=nil, &block)
        @resource.instance_eval(&block)

        run_action = action || @resource.action

        begin
          @resource.run_action(run_action)
          resource_updated = @resource.updated
        rescue *@handled_exceptions
          resource_updated = nil
        end

        resource_updated
      end

      def to_block(attributes, action=nil)
        resource_block = block_from_attributes(attributes)
        Proc.new do
          evaluate_action(action, &resource_block)
        end
      end

      private

      def get_resource_class(parent_resource, resource_symbol)
        if parent_resource.nil? || parent_resource.node.nil?
          raise ArgumentError, "Node for anonymous resource must not be nil"
        end
        Chef::Resource.resource_for_node(resource_symbol, parent_resource.node)
      end

      def block_from_attributes(attributes)
        Proc.new do
          attributes.keys.each do |attribute_name|
            send(attribute_name, attributes[attribute_name]) if respond_to?(attribute_name)
          end
        end
      end

      def merge_inherited_attributes(parent_resource)
        inherited_attributes = parent_resource.guard_inherited_attributes
        
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
      end
    end
  end
end
