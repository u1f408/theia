# frozen_string_literal: true

class Theia::Module::BotAdmin
  extend Theia::Command
  include Theia::Subcommand

  derive_help_subcommand
  command "botadmin", hidden: true, help: [
    "Bot administration commands, restricted to admins."
  ]

  before_subcommand do |cmdargs, opts|
    unless (Theia.config['admins'] || []).include?(opts[:source_message].author.id.to_s)
      opts[:message].reply! "❌ You don't have permission to do that."
      next :stop
    end
  end

  subcommand("naptime", help: "Shut down the bot") do |cmdargs, opts|
    opts[:message].reply! "💤 Good night..."
    Process.kill('TERM', Process.pid)

    sleep 5
    Process.exit
  end

  subcommand("rehash", help: "Rehash the bot configuration") do |cmdargs, opts|
    begin
      Theia.config.rehash!
    rescue => e
      next opts[:message].reply! "💀 An exception occurred while rehashing:\n```\n#{e.inspect}\n```"
    end

    opts[:message].react "✅"
  end

  subcommand("dsget", help: "Dump an object from the datastore") do |cmdargs, opts|
    next opts[:message].reply! "💀 Not enough parameters" unless cmdargs[:args].count >= 3
    type, args = [cmdargs[:args][1].to_sym, cmdargs[:args][2..]]

    klass = Theia::DataStore.const_get(type)
    next opts[:message].reply! "💀 `#{type.inspect}` is not a valid Theia::DataStore type" unless klass
    inst = klass.new(*args)

    opts[:message].reply! [
      "`#{inst.inspect} => #{inst.redis_key!.inspect}`",
      "```\n#{inst.to_h.inspect}\n```",
    ].join("\n")
  end

  subcommand("dsset", help: "Set an attribute on a datastore object") do |cmdargs, opts|
    next opts[:message].reply! "💀 Not enough parameters" unless cmdargs[:args].count >= 5

    type, args = [cmdargs[:args][1].to_sym, cmdargs[:args][2..-3]]
    key, val = [cmdargs[:args][-2].to_sym, cmdargs[:args][-1]]

    klass = Theia::DataStore.const_get(type)
    next opts[:message].reply! "💀 `#{type.inspect}` is not a valid Theia::DataStore type" unless klass
    inst = klass.new(*args)

    oldval = inst[key]
    inst[key] = val

    opts[:message].reply! [
      "`#{inst.inspect} => #{inst.redis_key!.inspect}`",
      "Set `#{key.inspect}` to `#{val.inspect}` (was `#{oldval.inspect}`)",
    ].join("\n")
  end
end
