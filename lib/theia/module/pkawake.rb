# frozen_string_literal: true

class Theia::Module::PKAwake
  API_BASE = "https://awake.iris.ac.nz/api"

  extend Theia::Command
  derive_help
  command "awake", syntax: "[PluralKit system ID]", help: [
    "Show a PluralKit system's switch-out status.",
    "Shows how long the given PluralKit systems have been \"awake\" (time since last switch-out)",
    "With no arguments, will default to your system.",
  ]

  def execute(cmdargs, opts = {})
    message = opts[:message]

    our_system = opts[:pluralkit_data]&.[](:system)&.[]('id')
    systems = [our_system].compact
    if cmdargs[:args].count.positive?
      systems = cmdargs[:args]
        .map { |s| s == "me" ? our_system : s }
        .compact
    end

    return message.reply! "❌ No system IDs were given." if systems.empty?

    message.reply!(systems.map do |sysid|
      req = Typhoeus::Request.new((Theia::Module::PKAwake::API_BASE + "/#{sysid}")).run
      next nil unless req.success?
      resp = JSON.parse req.body

      [
        (resp['awake'] ? "☀️" : "🌙"),
        "**#{resp['system']['name']}**",
        "is _#{resp['awake'] ? "awake" : "asleep"}_,",
        "and has been for #{resp['switch_ts']['friendly']}",
      ].join(" ")
    end.compact.join("\n"))
  end
end
