# frozen_string_literal: true

class Nguway::Commands::User
  extend Nguway::Command
  include Nguway::Utilities

  command 'user'
  aliases 'u'
  usage [
    '`!% <user> last` - Show when the given user was last seen',
    '`!% <user> time` - Show the time for the given user',
    '`!% <user> xiv` - Show the user\'s Final Fantasy XIV character',
    '`<user>` can be an @mention, a Discord user ID, or a nick.',
  ]
  handle_help

  match_command /(.+)\s+last/, method: :last
  match_command /(.+)\s+time/, method: :time
  match_command /(.+)\s+(?:xiv|catgirls)/, method: :xiv
  match_empty :help_message

  def last(m, mid)
    mid.strip!
    user = Nguway.from_discord_mid(mid)
    user ||= User.where(nick: mid).first
    return m.reply "No such user: `#{mid}`" unless user

    lastseen = user.last_seen
    usertz = TimeZone.new(m.user.tz)
    lastseen = usertz.at(lastseen) if usertz
    lastseen = lastseen.strftime("%Y-%m-%d %H:%M %z")

    reltime, relneg = dur_display(user.last_seen)
    if %w[0s 1s 2s].include?(reltime)
      reltime = "right now"
    elsif relneg
      reltime = "#{reltime} ago"
    else
      reltime = "in the future by #{reltime}"
    end

    m.reply "**#{user.nixnotif}** was last seen: `#{lastseen}` (#{reltime})"
  end

  def time(m, mid)
    mid.strip!
    user = Nguway.from_discord_mid(mid)
    user ||= User.where(nick: mid).first
    return m.reply "No such user: `#{mid}`" unless user

    usertime = TimeZone.new(user.tz).now.strftime('%Y-%m-%d %H:%M %z')
    m.reply "Time for **#{user.nixnotif}**: `#{usertime}` (`#{user.tz}`)"
  end

  def xiv(m, mid)
    mid.strip!
    user = Nguway.from_discord_mid(mid)
    user ||= User.where(nick: mid).first
    return m.reply "No such user: `#{mid}`" unless user

    unless user.xiv_character
      return m.reply "That user doesn't have a Final Fantasy XIV character set."
    end

    character = Catgirls.character(user.xiv_character)
    character.embed(m)
  end
end
