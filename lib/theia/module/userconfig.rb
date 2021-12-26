# frozen_string_literal: true

class Theia::Module::UserConfig
  OPTIONS = {
    pluralkit: {
      aliases: %i[pk],
      ds_key: :pluralkit_enabled?,
      type: :bool,
      help: "Whether or not to support commands proxied through PluralKit",
    },
  }

  extend Theia::Command
  derive_help
  command "userconfig", syntax: "<setting> [<value>]", help: [
    "View or change your Theia user settings.",
    "To view the list of available settings, use `%!userconfig --list`.",
    "To view the current value of a setting, use `%!userconfig <setting>`.",
    "To change the value of a setting, use `%!userconfig <setting> <new value>`.",
  ]

  def execute(cmdargs, opts)
    return execute_help(cmdargs, opts) if cmdargs[:args].empty?

    message = opts[:message]
    userds = Theia::DataStore.user(opts[:source_message].author)

    if cmdargs[:args].map { |w| /^-{1,2}l(?:ist)?$/i =~ w }.any?
      knownopts = OPTIONS.map do |opt, data|
        "`#{opt.to_s}` - #{data[:help]}"
      end

      return message.reply! "**Available options:**\n#{knownopts.join("\n")}"
    end

    option = cmdargs[:args].shift.strip.to_sym

    # Alias search
    unless OPTIONS.key?(option)
      OPTIONS.each do |opt, data|
        if data[:aliases].include?(option)
          option = opt
          break
        end
      end
    end

    # Unknown option?
    unless OPTIONS.key?(option)
      return message.reply! [
        "❌ The user option `#{option.to_s}` isn't something I know about.",
        "Use `#{Theia.config['prefix']}#{cmdargs[:command]} --list`",
        "to see a list of available options.",
      ].join(" ")
    end

    current = userds.get(OPTIONS[option][:ds_key])
    current_friendly = friendly_value(OPTIONS[option][:type], current)

    # No more args? Reply with current value
    if cmdargs[:args].empty?
      return message.reply! "User option `#{option.to_s}` is currently #{current_friendly}."
    end

    # Get new value, convert to datastore format
    newval = cmdargs[:args].map(&:strip).join(" ")
    if /^-{1,2}clear$/i =~ newval.strip
      newval = nil
    elsif OPTIONS[option][:type] == :bool
      newval = (/(?:y(?:es)?|enabled?|1)/i =~ newval) ? "1" : "0"
    elsif OPTIONS[option][:type] == :int
      newval = newval.to_i
    end

    # Set value
    if newval.nil?
      userds.remove(OPTIONS[option][:ds_key])
    else
      userds[OPTIONS[option][:ds_key]] = newval
    end

    # Reply with new value
    newval_friendly = friendly_value(OPTIONS[option][:type], newval)
    message.reply! [
      "User option `#{option.to_s}` has been set to #{newval_friendly}",
      "(previously #{current_friendly})",
    ].join(" ")
  end

  private

  def friendly_value(type, value)
    if value.nil?
      "_not set_"
    elsif type == :bool
      value.to_i.positive?() ? "enabled" : "disabled"
    elsif type == :str
      "`#{current}`"
    else
      "`#{current.inspect}`"
    end
  end
end
