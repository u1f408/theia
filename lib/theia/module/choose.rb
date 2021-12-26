# frozen_string_literal: true

class Theia::Module::Choose
  MAYBE_RESPONSES = [
    "uh, maybe?",
    "I'll think about it, ask me later",
    "not super sure, actually",
    "🤷",
  ]

  extend Theia::Command
  derive_help
  command "choose", syntax: "a [or b [or ...]]", help: [
    "A solution to decision paralysis.",
    "If given multiple options to choose from, I'll randomly choose one.",
    "Otherwise, I'll assume you're asking a question, and I'll give you a \"yes\" or \"no\".",
  ]

  def execute(cmdargs, opts = {})
    message = opts[:message]

    flags, end_args = {}, false
    args = cmdargs[:args].map do |arg|
      arg.strip!

      next arg if end_args
      next arg if arg.empty?

      if /^--?x(?:or)?$/i =~ arg
        flags[:xor] = true
        next nil

      else
        end_args = true
        next arg
      end
    end.compact.join(' ')

    # This allows parsing a list out of a string that is both comma-delimited
    # and "or"-delimited, such that "a, b, or c" => ["a", "b", "c"] :3c
    args = args
      .split(/\s+or\s+/i)
      .map { |w| w.split(/\s{0,},\s+/i) }
      .flatten
      .map(&:strip)
      .map { |w| w.end_with?(',') ? w[0..-2] : w }
      .map { |w| w.empty?() ? nil : w }
      .compact

    return message.reply! MAYBE_RESPONSES.sample if !flags[:xor] && rand < 0.01
    return message.reply! %w[yes no].sample if args.count == 1
    message.reply! args.sample
  end
end
