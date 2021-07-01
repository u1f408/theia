# frozen_string_literal: true

class Theia::Commands::Bot
  extend Theia::Command

  command 'bot'
  usage [
    'All commands are restricted to #botspam, and some are admin-restricted.',
    '',

    '**Public commands:**',
    '`!% info` - Show some bot information',
    '`!% uptime` - Show uptime, boot time, host, and version info',
    '`!% my id` - Show own Discord ID',
    '',

    '**Admin commands:**',
    '`!% take a nap` - Voluntarily exit',
    '`!% say <channel> <text>` - Say something in a given channel',

    '`!% user <user> tz info` - Inspects the given user',
    '`!% user <user> tz <tz>` - Sets the timezone for the given user',

    '`!% game cycle` - Cycle the bot’s playing now status',
    '`!% game list` - List all the stored now playing statuses',
    '`!% game add <text>` - Add a new now playing status to the rotation',
    '`!% game toggle <id>` - Toggle whether the given now playing status is in the rotation',
    '`!% game delete <id>` - Remove the given now playing status'
  ]
  handle_help

  match_command /info/, method: :botinfo
  match_command /uptime/, method: :uptime
  match_command /my id/, method: :my_id

  match_command /take a nap/, method: :take_a_nap
  match_command /say (\S+)\s+(.*)/, method: :say

  match_command /user (.+)\s+info/, method: :user_info
  match_command /user (.+)\s+tz (.*)/, method: :user_tz

  match_command /game cycle/, method: :game_cycle
  match_command /game list/, method: :game_list
  match_command /game add (.*)/, method: :game_add
  match_command /game toggle (\d+)/, method: :game_toggle
  match_command /game delete (\d+)/, method: :game_delete

  before_handler do |method, m|
    unless m.channel.name == 'botspam'
      m.reply('Debug in #botspam only please')
      next :stop
    end

    next if %i[
      help_message
      botinfo uptime
      my_id
      game_list
    ].include? method

    is_admin = m.user.discord.roles.find { |r| (r.permissions.bits & 3) == 3 }
    unless is_admin
      m.reply('Not authorised')
      next :stop
    end
  end

  def botinfo(m)
    m.reply [
      "My name is Theia.",
      "My source code can be found at <https://github.com/u1f408/theia>.",
      "I am a fork of Rogare, part of Sassbot - the bot for the New Zealand NaNoWriMo Discord server.",
      "Her source code can be found at <https://github.com/storily/rogare>.",
    ].join(" ")
  end

  def uptime(m)
    version = ENV['HEROKU_SLUG_DESCRIPTION'] || `git describe --always --tags --abbrev --dirty` || 'around'
    m.reply "My name is Theia, #{Socket.gethostname} is my home, running #{version}"
    m.reply "I made my debut at #{Theia.boot}, #{(Time.now - Theia.boot).round} seconds ago"
  end

  def take_a_nap(m)
    m.reply ['It’s been a privilege', 'See you soon', 'I’ll see you on the other side'].sample
    sleep 1

    logs 'Sending TERM to self'
    Process.kill('TERM', Process.pid)

    sleep 5
    logs 'exeunt.'
    Process.exit
  end

  def my_id(m)
    m.reply m.user.discord.id
  end

  def say(m, channel, message)
    channel = Theia.find_channel(channel.strip)
    if channel.nil?
      m.reply 'No such channel'
      return
    elsif channel.is_a? Array
      m.reply "Multiple channels match this:\n" + channel.map do |chan|
        "#{chan.server.name.tr(' ', '~')}/#{chan.name}"
      end.join("\n")
      return
    end

    channel.send_msg message
  end

  def user_info(m, mid)
    mid.strip!
    user = Theia.from_discord_mid(mid)
    user ||= User.where(nick: mid).first
    return m.reply "No such user: `#{mid}`" unless user

    m.debugly user
  end

  def user_tz(m, mid, tz)
    mid.strip!
    user = Theia.from_discord_mid(mid)
    user ||= User.where(nick: mid).first
    return m.reply "No such user: `#{mid}`" unless user

    tz.strip!
    unless TimeZone.new(tz)
      return m.reply "Sorry, `#{tz}` isn't a valid timezone."
    end

    user.tz = tz
    user.save
    m.reply "Timezone for **#{user.nixnotif}** has been set to `#{tz}`."
  end

  def game_cycle(_m)
    Theia.discord.update_status('online', Theia.game, nil)
  end

  def game_list(m)
    m.reply "**Now playing statuses**\n#{Game.all.map(&:display).join("\n")}"
  end

  def game_add(m, text)
    game = Game.new(creator_id: m.user.id, text: text.strip).save
    m.reply "📝 Added: #{game.display}"
  end

  def game_toggle(m, id)
    game = Game[id.to_i]
    unless game
      m.reply "Unknown game ID `#{id}`"
    end

    game.enabled = !game.enabled
    game.save
    m.reply game.display
  end

  def game_delete(m, id)
    game = Game[id.to_i]
    unless game
      m.reply "Unknown game ID `#{id}`"
    end

    game.delete
    m.reply "🗑️ Deleted: #{game.display}"
  end
end
