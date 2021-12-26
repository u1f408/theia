# frozen_string_literal: true

module Theia
  module CommandParser
    class << self
      # Parse a command from a text string, returning +nil+ if the string does
      # not contain a command invocation.
      def parse_text(text)
        return nil unless text.start_with?(Theia.config['prefix'])

        command, *argsplit = text.split(/\s/).map(&:strip)

        # strip prefix
        command = command[Theia.config['prefix'].length..]
        return nil if command.empty?

        # combine quoted strings in args array
        args, argsplit_idx = [], 0
        while argsplit_idx < argsplit.count
          arg = argsplit[argsplit_idx]
          if arg.start_with?('"')
            while !arg.end_with?('"')
              argsplit_idx += 1
              arg = [arg, argsplit[argsplit_idx]].join(' ')
            end

            arg = arg[1..-2]
          end

          args << arg
          argsplit_idx += 1
        end

        # compact args array
        args = args.map { |w| w.empty?() ? nil : w }.compact

        # return results
        {
          command: command,
          args: args,
        }
      end

      # Parse a command from a Discord message, returning +nil+ if the message
      # does not contain a command invocation.
      def parse(message)
        return nil unless message
        parse_text(message.text)
      end
    end
  end
end
