#
# Author:: Adam Jacob (<adam@opscode.com>)
# Author:: Tyler Cloke (<tyler@opscode.com>)
# Copyright:: Copyright (c) 2008 Opscode, Inc.
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

require 'chef/resource/execute'

class Chef
  class Resource
    class Script < Chef::Resource::Execute

      identity_attr :command

      def initialize(name, run_context=nil)
        super
        @resource_name = :script
        @command = name
        @code = nil
        @interpreter = nil
        @flags = nil
        @guard_interpreter = nil
      end

      attr_reader :guard_interpreter

      def code(arg=nil)
        set_or_return(
          :code,
          arg,
          :kind_of => [ String ]
        )
      end

      def interpreter(arg=nil)
        set_or_return(
          :interpreter,
          arg,
          :kind_of => [ String ]
        )
      end

      def flags(arg=nil)
        set_or_return(
          :flags,
          arg,
          :kind_of => [ String ]
        )
      end

      def only_if(command=nil, opts={}, &block)
        translated_command, translated_block = translate_command_block(command, &block)
        super(translated_command, opts, &translated_block)
      end

      def not_if(command=nil, opts={}, &block)
        translated_command, translated_block = translate_command_block(command, &block)
        super(translated_command, opts, &translated_block)
      end

      protected

      def override_guard_interpreter(guard_interpreter_symbol)
        @guard_interpreter = guard_interpreter_symbol
      end

      def translate_command_block(command, &block)
        if @guard_interpreter && command && ! block_given?
          evaluator = Conditional::AnonymousResourceEvaluator.new(guard_interpreter, self, [Mixlib::ShellOut::ShellCommandFailed])
          translated_block = evaluator.to_block({:code => command})
          [nil, translated_block]
        else
          [command, block]
        end
      end
    end
  end
end
