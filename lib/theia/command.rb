# frozen_string_literal: true

module Theia
  module Command
    @@cmds = {}

    def self.allcmds
      @@cmds
    end

    def command(cmdname, opts = {})
      @@cmds[cmdname] = opts
      @@cmds[cmdname][:klass] = self
    end

    def derive_help
      self.define_method(:execute_help) do |cmdargs, opts|
        klass = Theia::Command.allcmds[cmdargs[:command]]
        help = klass&.[](:help).dup || []
        syntax = klass&.[](:syntax)

        combined = [help.shift].compact
        combined << "Usage: `%!#{cmdargs[:command]} #{syntax}`" if syntax
        combined = combined + ["", help] unless help.empty?
        combined = combined.compact.flatten.map do |line|
          line.gsub("%!", Theia.config["prefix"])
        end

        opts[:message].reply! combined.join("\n")
      end
    end 

    class << self
      def handle_command!(cmdargs, opts = {})
        message = opts[:message]

        # Attempt to get command
        cmdklass = @@cmds[cmdargs[:command]]
        if cmdklass.nil?
          # Attempt to get by alias
          if Theia.config['aliases'].key?(cmdargs[:command])
            aliastarget = Theia.config['aliases'][cmdargs[:command]]
            cmdklass = @@cmds[aliastarget]
            cmdargs[:command] = aliastarget
          end
        end

        # Bail with an "unknown command" message if we don't have a valid command
        if cmdklass.nil?
          return message.reply! [
            "❓ Unknown command `#{Theia.config['prefix']}#{cmdargs[:command]}`",
            "-",
            "see `#{Theia.config['prefix']}help` for a list of available commands.",
          ].join(" ")
        end

        begin
          # Create class instance
          klass = cmdklass[:klass].new
          send_to = :execute

          # Check for a help flag
          if /-{1,2}h(?:elp)?/i =~ cmdargs[:args].first
            cmdargs[:help_requested] = true
            send_to = :execute_help if klass.respond_to? :execute_help
          end

          # Run the class #before method, if it exists
          if klass.respond_to?(:before)
            return if klass.before(cmdargs, opts) == :stop
          end

          # And send to the right class method
          klass.send(send_to, cmdargs, opts)

        rescue => e
          return message.reply! [
            "💀 An exception occurred during command handling, and I'm not sure what to do.",
            "Please send a screenshot of this message to The Iris System.",
            "```",
            e.to_s,
            "",
            e.backtrace,
            "```",
          ].flatten.join("\n")
        end
      end
    end
  end
end
