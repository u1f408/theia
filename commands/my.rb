# frozen_string_literal: true

class Nguway::Commands::My
  extend Nguway::Command

  command 'my'
  usage [
    '`!%` - Show yourself!',
    '`!% tz <timezone e.g. Pacific/Auckland>` - Set your timezone (for counts, goals, etc).'
  ]
  handle_help

  match_command /tz\s+(.+)/, method: :set_timezone
  match_empty :show

  def show(m)
    m.reply [
      "Hello, #{m.user.nick || 'unknown'}!",
      "**First seen**: `#{m.user.first_seen.strftime('%Y-%m-%d')}`",
      "**Timezone**: `#{m.user.tz}`",
    ].compact.join("\n")
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
