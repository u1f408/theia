# frozen_string_literal: true

module Theia
  module Subcommand
    @@mine = {}

    def self.allsubcmds
      @@mine
    end

    module ClassMethods
      def my_subcmd
        Theia::Subcommand.allsubcmds[inspect.to_sym] ||= {}
      end

      def my_subcmd=(v)
        Theia::Subcommand.allsubcmds[inspect.to_sym] = v
      end

      def subcommand(name, opts = {}, &block)
        my_subcmd[name] = opts
        my_subcmd[name][:block] = block
      end

      def before_subcommand(&block)
        my_subcmd[:before] ||= []
        my_subcmd[:before] << block
      end

      def derive_help_subcommand
        x_subcmd = my_subcmd # load bearing

        self.define_method(:execute_help) do |cmdargs, opts|
          klass = Theia::Command.allcmds[cmdargs[:command]]
          combined = klass&.[](:help).dup || ["A mystery command."]

          cmds = x_subcmd.map do |k, v|
            next nil unless v.is_a?(Hash)
            next nil if v[:hidden]

            "`#{Theia.config['prefix']}#{cmdargs[:command]} #{k}` - #{v[:help] || 'no help provided'}"
          end.compact
          combined = combined + ["", "**Subcommands:**", cmds] unless cmds.empty?

          opts[:message].reply! combined.compact.join("\n")
        end
      end
    end

    def self.included(base)
      base.extend(ClassMethods)
    end

    def execute(cmdargs, opts = {})
      subcmd = cmdargs[:args][0]

      # Check aliases if we don't have a command match
      unless self.class.my_subcmd.key?(subcmd)
        if Theia.config['modules'][cmdargs[:command]]&.key?('aliases')
          if Theia.config['modules'][cmdargs[:command]]['aliases'].key?(subcmd)
            subcmd = Theia.config['modules'][cmdargs[:command]]['aliases'][subcmd]
            cmdargs[:args][0] = subcmd
          end
        end
      end

      unless self.class.my_subcmd.key?(subcmd)
        # If still +nil+, and the class has a +execute_help+ method, dispatch
        # to that instead
        if subcmd.nil? && self.respond_to?(:execute_help)
          return self.execute_help(cmdargs, opts)
        end

        # Else, reply with an error
        replymsg = (
          "❓ `#{Theia.config['prefix']}#{cmdargs[:command]}` doesn't have a subcommand named `#{subcmd}`." +
          " Take a look at `#{Theia.config['prefix']}#{cmdargs[:command]} --help` for a list."
        )

        return opts[:message].reply! replymsg
      end

      # Call any +before_subcommand+ blocks, and stop command execution
      # if any of them ask us to (by returning +:stop+)
      (self.class.my_subcmd[:before] || []).each do |before|
        res = before.call(cmdargs, opts)
        return if res == :stop
      end

      # Call the actual subcommand block
      self.class.my_subcmd[subcmd][:block].call(cmdargs, opts)
    end
  end
end
