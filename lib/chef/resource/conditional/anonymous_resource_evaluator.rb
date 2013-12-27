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
    class AnonymousResourceEvaluator

      def self.well_formed_resource_block?(*args, &block)
        args.size == 0 && block_given?
      end

      def self.from_attributes(parent_resource, resource_symbol, handled_exceptions, attributes)
        resource_block = block_from_attributes(attributes)
        from_block(parent_resource, resource_symbol, handled_exceptions, nil, *nil, &resource_block)
      end

      def self.from_block(parent_resource, resource_symbol, handled_exceptions, source_line, *args, &block)
        raise ArgumentError, "A block must be specified with no arguments" if !well_formed_resource_block?(*args, &block)

        resource_class = get_resource_class(parent_resource, resource_symbol)

        raise ArgumentError, "Specified resource #{resource_symbol.to_s} unknown for this platform" if resource_class.nil?

        empty_events = Chef::EventDispatch::Dispatcher.new
        anonymous_run_context = Chef::RunContext.new(parent_resource.node, {}, empty_events)
        anonymous_resource = resource_class.new('anonymous', anonymous_run_context)

        new(anonymous_resource, parent_resource, handled_exceptions, source_line, &block)
      end

      def evaluate_action(action = nil)
        @resource.instance_eval(&@block)

        run_action = action || @resource.action

        begin
          @resource.run_action(run_action)
          resource_updated = @resource.updated
        rescue *@handled_exceptions
          resource_updated = nil
        end

        resource_updated
      end

      def to_block
        Proc.new do
          evaluate_action
        end
      end

      private

      def self.get_resource_class(parent_resource, resource_symbol)
        if parent_resource.nil? || parent_resource.node.nil?
          raise ArgumentError, "Node for anonymous resource must not be nil"
        end
        Chef::Resource.resource_for_node(resource_symbol, parent_resource.node)
      end

      def initialize(resource, parent_resource, handled_exceptions, source_line=nil, attributes=nil, &block)
        @resource = resource
        @block = block
        @handled_exceptions = handled_exceptions ? handled_exceptions : []
        merge_inherited_attributes(parent_resource, source_line)
      end

      def self.block_from_attributes(attributes)
        Proc.new do
          attributes.keys.each do |attribute_name|
            send(attribute_name, attributes[attribute_name])
          end
        end
      end

      def merge_inherited_attributes(parent_resource, source_line)
        inherited_attributes = parent_resource.block_inherited_attributes
        
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

        @resource.source_line = source_line if source_line
      end
    end
  end
end
