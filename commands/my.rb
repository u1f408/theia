# frozen_string_literal: true

class Nguway::Commands::My
  extend Nguway::Command

  command 'my'
  usage [
    '`!%` - Show yourself!',
    '`!% time` - Show the current time in your timezone',
    '`!% set tz <timezone e.g. Pacific/Auckland>` - Set your timezone'
  ]
  handle_help

  match_command /time/, method: :time
  match_command /set tz\s+(.+)/, method: :set_timezone
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
    m.reply "Time for **#{m.user.nick}**: `#{usertime}`"
  end

  def set_timezone(m, tz)
    tz.strip!

    unless TimeZone.new(tz)
      logs "Invalid timezone: #{e}"
      return m.reply 'That’s not a valid timezone.'
    end

    m.user.tz = tz
    m.user.save
    m.reply "Your timezone has been set to #{tz}."
  end
end
