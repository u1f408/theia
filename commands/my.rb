# frozen_string_literal: true

class Theia::Commands::My
  extend Theia::Command

  command 'my'
  usage [
    '`!%` - Show yourself!',
    '`!% time` - Show the current time in your timezone',
    '`!% xiv` - Show your Final Fantasy XIV character',
    '',
    '`!% set tz <timezone e.g. Pacific/Auckland>` - Set your timezone',
    '`!% set xiv <server> <character>` - Set your Final Fantasy XIV character'
  ]
  handle_help

  match_command /time/, method: :time
  match_command /(?:xiv|catgirls)/, method: :xiv
  match_command /set tz (.*)/, method: :set_timezone
  match_command /set (?:xiv|catgirls) (\w+) (.*)/, method: :set_xiv
  match_empty :show

  def show(m)
    m.reply [
      "Hello, **#{m.user.nick}**",
      "First seen: `#{m.user.first_seen.strftime('%Y-%m-%d')}`",
      "Timezone: `#{m.user.tz}`",
    ].compact.join("\n")
  end

  def time(m)
    usertime = TimeZone.new(m.user.tz).now.strftime('%Y-%m-%d %H:%M %z')
    m.reply "Time for **#{m.user.nick}**: `#{usertime}` (`#{m.user.tz}`)"
  end

  def xiv(m)
    unless m.user.xiv_character
      return m.reply "You don't have a Final Fantasy XIV character set! Use #{Theia.prefix}my set xiv <server> <character>"
    end

    character = Catgirls.character(m.user.xiv_character)
    character.embed(m)
  end

  def set_timezone(m, tz)
    tz.strip!

    unless TimeZone.new(tz)
      m.reply [
        "Sorry, `#{tz}` isn't a valid timezone.",
        "Look at the \"TZ database name\" column of <https://en.wikipedia.org/wiki/List_of_tz_database_time_zones> for examples."
      ].join("\n")

      return
    end

    m.user.tz = tz
    m.user.save
    m.reply "Your timezone has been set to `#{tz}`."
  end

  def set_xiv(m, server, character)
    character.strip!
    server = server.strip.split('')
    server.first.upcase!
    server = server.join('')

    # Check server exists
    unless Catgirls.servers.include?(server)
      return m.reply "Sorry, #{server} isn't a valid Final Fantasy XIV server."
    end

    # Check character exists
    api_character = Catgirls.character_search(server, character)
    unless character
      return m.reply "Sorry, I couldn't find that character!"
    end

    m.user.xiv_character = api_character
    m.user.save
    m.reply "Final Fantasy XIV character data saved."

    character = Catgirls.character(api_character)
    character.embed(m)
  end
end
