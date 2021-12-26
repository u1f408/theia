# frozen_string_literal: true

class Theia::Module::Debug
  extend Theia::Command
  include Theia::Subcommand

  derive_help_subcommand
  command "debug", hidden: true, help: [
    "Debugging commands, some of which are admin-restricted."
  ]

  subcommand("uid", help: "Display source message author ID") do |cmdargs, opts|
    opts[:message].reply! opts[:source_message].author.id
  end

  subcommand("message", help: "Display message information") do |cmdargs, opts|
    data = {
      "Source message author" => {
        id: opts[:source_message].author.id,
        distinct: opts[:source_message].author.distinct,
        nickname: opts[:source_message].author.nickname,
      },

      "Source message ID" => opts[:source_message].id,
      "Usable message ID" => opts[:message].id,
    }

    unless opts[:pluralkit_data].nil?
      data["PluralKit system"] = {
        id: opts[:pluralkit_data][:system]['id'],
        name: opts[:pluralkit_data][:system]['name'],
      }

      data["PluralKit member"] = {
        id: opts[:pluralkit_data][:message]['member']['id'],
        name: opts[:pluralkit_data][:message]['member']['name'],
        display_name: opts[:pluralkit_data][:message]['member']['display_name'],
      }
    end

    opts[:message].reply! data.map { |k, v| "#{k}: `#{v.inspect.gsub('`', '\\`')}`" }.join("\n")
  end

  subcommand("cmdargs", help: "Show command parser output") do |cmdargs, opts|
    opts[:message].reply! "`#{cmdargs}`"
  end

  subcommand("raise", help: "Raise an exception") do |cmdargs, opts|
    unless (Theia.config['admins'] || []).include?(opts[:source_message].author.id.to_s)
      next opts[:message].reply! "❌ You don't have permission to do that."
    end

    raise ArgumentError, "Debug raise: #{cmdargs[:args][1..].join(" ").inspect}"
  end
end
