# frozen_string_literal: true

class Theia::Module::PatCat
  DEFAULT_MESSAGE_COUNT = 20
  PAT_EMOJI_REGEX = /(?:cat|meow|blep)/i
  CAT_JPEGS = [
    "https://cdn.discordapp.com/emojis/890032949087584266.webp",
  ]

  extend Theia::ModuleHooks
  extend Theia::Command
  include Theia::Subcommand

  derive_help_subcommand
  command "patcat", hidden: true, help: [
    "Pat pat pat the cat cat cat~",
    "If cats are enabled in a channel, sometimes one will spawn after some activity.",
    "You can react with any cat emoji to pat the cat, and I'll keep track!",
  ]

  subcommand("stats", help: "Show the cat patting leaderboard") do |cmdargs, opts|
    users = Theia::DataStore.server(opts[:message].server).known_users.map do |user|
      count = user[:patcount].to_i
      next nil unless count.positive?
      [user, count]
    end.compact.sort { |a, b| b.last <=> a.last }

    if users.empty?
      next opts[:message].reply! [
        "No one has pat any cats in",
        opts[:message].server.name,
        ">:(",
      ].join(" ")
    end

    leaderboard = users[0..10].map do |(user, count)|
      "\\* **#{user[:user_displayname] || "ID `#{user.user_id}`"}** (#{count} cats)"
    end

    opts[:message].reply! [
      "The top 10 cat patters in #{opts[:message].server.name} are:",
      "",
      leaderboard,
    ].flatten.join("\n")
  end

  subcommand("channel", help: "Show cat configuration for this channel") do |cmdargs, opts|
    message = opts[:message]
    chancfg = Theia::DataStore.server(message.server).channel(message.channel)

    message.reply! "Cat configuration for #{message.channel.mention}: " + ({
      "spawning" => (chancfg[:patcat_spawn?].to_i.positive?() ? "enabled" : "disabled"),
      "minimum message count" => (chancfg[:patcat_messagecount] || DEFAULT_MESSAGE_COUNT).to_i,
    }.map { |k, v| [k, v].join(': ') }.join(", "))
  end

  subcommand("toggle", help: "Enable/disable cat spawning in this channel") do |cmdargs, opts|
    unless opts[:source_message].author.permission?(:manage_messages)
      next opts[:message].reply! "❌ You don't have permission to do that."
    end

    message = opts[:message]
    chancfg = Theia::DataStore.server(message.server).channel(message.channel)
    chancfg[:patcat_spawn?] = chancfg[:patcat_spawn?].to_i.positive?() ? 0 : 1
    chancfg[:patcat_messagecount] ||= DEFAULT_MESSAGE_COUNT

    message.reply! [
      "Cat spawning is now",
      (chancfg[:patcat_spawn?].to_i.positive?() ? "enabled" : "disabled"),
      "in the channel",
      message.channel.mention,
      ":3",
    ].join(" ")
  end

  subcommand("setcount", help: "Set the minimum number of messages before a cat spawn for this channel") do |cmdargs, opts|
    unless opts[:source_message].author.permission?(:manage_messages)
      next opts[:message].reply! "❌ You don't have permission to do that."
    end

    message = opts[:message]
    chancfg = Theia::DataStore.server(message.server).channel(message.channel)

    oldcount = chancfg[:patcat_messagecount].to_i
    chancfg[:patcat_messagecount] = newcount = cmdargs[:args].last.to_i

    message.reply! [
      "Cats will now spawn after approximately",
      newcount,
      "messages in",
      message.channel.mention,
      "(changed from",
      oldcount,
      "messages)"
    ].join(" ")
  end

  subcommand("reset", hidden: true, help: "Reset your cat count") do |cmdargs, opts|
    unless cmdargs[:args].map { |w| /-{1,2}y(?:es)?/i =~ w }.any?
      next opts[:message].reply! [
        "You sure?",
        "Use `#{Theia.config['prefix']}#{cmdargs[:command]} #{cmdargs[:args].first} --yes` to confirm.",
      ].join(" ")
    end

    message = opts[:source_message]
    user = Theia::DataStore.server(message.server).user(message.user)
    patcount = user[:patcount].to_i
    user[:patcount] = 0

    opts[:message].reply! [
      "Reset your cat count to zero.",
      "Before the reset, you had pat",
      patcount,
      "cats. Maybe you'll pat more?",
    ].join(" ")
  end

  subcommand("dumpchan", hidden: true, help: "Dump the patcat data for this channel") do |cmdargs, opts|
    unless (Theia.config['admins'] || []).include?(opts[:source_message].author.id.to_s)
      next opts[:message].reply! "❌ You don't have permission to do that."
    end

    message = opts[:message]
    chancfg = Theia::DataStore.server(message.server).channel(message.channel)

    data = chancfg.to_h.map do |k, v|
      next nil unless k.to_s.start_with?("patcat_")
      [k, v]
    end.compact.to_h

    opts[:message].reply! [
      "`#{chancfg.inspect} => #{chancfg.redis_key!.inspect}`",
      "```\n#{data.inspect}\n```",
    ].join("\n")
  end

  subcommand("spawn", hidden: true, help: "Spawn a debug cat") do |cmdargs, opts|
    unless (Theia.config['admins'] || []).include?(opts[:source_message].author.id.to_s)
      next opts[:message].reply! "❌ You don't have permission to do that."
    end

    self.spawn_cat(opts[:source_message].channel)
  end

  @@active_messages = {}
  def self.active_messages
    @@active_messages
  end

  # Message hook to increment the count for a channel
  hook_to :on_message do |message|
    next unless message.respond_to?(:channel)

    chancfg = Theia::DataStore.server(message.server).channel(message.channel)
    next unless chancfg && chancfg[:patcat_spawn?].to_i.positive?

    count = chancfg[:patcat_currentcount].to_i
    chancfg[:patcat_currentcount] = count + 1
  end

  # Message hook to potentially spawn a cat
  hook_to :on_message do |message|
    next unless message.respond_to?(:channel)

    chancfg = Theia::DataStore.server(message.server).channel(message.channel)
    next unless chancfg && chancfg[:patcat_spawn?].to_i.positive?

    if chancfg[:patcat_currentcount].to_i >= chancfg[:patcat_messagecount].to_i
      next if rand < 0.25

      # spawn a cat!
      chancfg[:patcat_currentcount] = 0
      Theia::Module::PatCat.spawn_cat(message.channel)
    end
  end

  hook_to :on_reaction_add do |event|
    message = @@active_messages[event.message.id.to_s]
    next unless message

    if PAT_EMOJI_REGEX =~ event.emoji.name
      unless @@active_messages.delete(event.message.id.to_s).nil?
        self.pat_cat(message, event)
      end
    end
  end

  def self.spawn_cat(channel)
    message = channel.send_embed("Meow!") do |embed|
      embed.title = "A kitty has appeared, and they want pats!"
      embed.description = "React with any cat emoji to pat the cat."
      embed.thumbnail = Discordrb::Webhooks::EmbedThumbnail.new url: CAT_JPEGS.sample

      embed
    end

    @@active_messages[message.id.to_s] = message
  end

  def self.pat_cat(message, event)
    user = Theia::DataStore.server(event.server).user(event.user)
    patcount = user[:patcount].to_i
    user[:patcount] = patcount + 1

    message.reply! [
      "\\*purr~\\*",
      "**#{event.user.display_name}** (#{event.user.mention})",
      "was the fastest to pat the cat!",
      "You've pat #{user[:patcount]} cats so far in #{event.server.name} :3",
    ].join(" ")
  end
end
