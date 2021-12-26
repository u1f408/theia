# frozen_string_literal: true

module Theia
  module ModuleHooks
    @@hooks = {
      message: [],
    }

    def self.hooks
      @@hooks
    end

    def hook_to(hook, &block)
      @@hooks[hook] ||= []
      @@hooks[hook] << block
    end

    class << self
      def execute_hook(hook, *args)
        return unless @@hooks.key?(hook)

        @@hooks[hook].each do |block|
          block.call(*args)
        end
      end
    end
  end
end
