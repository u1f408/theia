# frozen_string_literal: true

class Rogare::Plugins::Wordcount
  extend Rogare::Plugin
  extend Memoist

  command 'wc'
  aliases 'count'
  usage [
    '`!%`, `!% <id>`, `!% <nanoname>`, or `!% <@nick>` (to see others’ counts)',
    '`!% set <words>` or `!% add <words>` - Set or increment your word count.',
    '`!% (set|add) <words> (for|to) <novel ID>` - Set the word count for a particular novel.',
    '`!% set today <words> [for <novel ID>]` - Set the word count for today.',
    '`!% add <words> to <novel ID>` - Set the word count for a particular novel.',
    'To register your nano name against your discord user: `!my nano <nanoname>`',
    'To set your goal: `!novel goal set <count>`. To set your timezone: `!my tz <timezone>`.'
  ]
  handle_help

  def get_today(name)
    res = Typhoeus.get "https://nanowrimo.org/participants/#{name}/stats"
    return unless res.code == 200

    doc = Nokogiri::HTML res.body
    doc.at_css('#novel_stats .stat:nth-child(2) .value').content.gsub(/[,\s]/, '').to_i
  end

  def get_count(name)
    res = Typhoeus.get "https://nanowrimo.org/wordcount_api/wc/#{name}"
    return unless res.code == 200

    doc = Nokogiri::XML(res.body)
    return unless doc.css('error').empty?

    doc.at_css('user_wordcount').content.to_i
  end

  match_command /set\s+today\s+(\d+)(?:\s+(?:for|to)\s+(\d+))?/, method: :set_today_count
  match_command /set\s+(\d+)(?:\s+(?:for|to)\s+(\d+))?/, method: :set_count
  match_command /add\s+(-?\d+)(?:\s+(?:for|to)\s+(\d+))?/, method: :add_count

  match_command /(set|add)\s+.+/, method: :help_message
  match_command /(\d+)/, method: :novel_count
  match_command /(.+)/, method: :other_counts
  match_empty :own_count

  def own_count(m)
    novels = get_counts([m.user.to_db]).first

    return m.reply 'Something is very wrong' unless novels
    return m.reply 'You have no current novel' if novels.empty?

    display_novels m, novels
  end

  def other_counts(m, param = '')
    names = param.strip.split.uniq.compact
    return own_count(m) if names.empty?

    users = get_counts(names.map do |name|
      if /^<@!?\d+>$/.match?(name)
        # Exact match from @mention / mid
        Rogare.from_discord_mid(name).to_db
      else
        # Case-insensitive match from nick
        Rogare::Data.users.where { nick =~ /^#{name}$/i }.first
      end
    end.compact)

    return m.reply 'No valid users found' unless users
    return m.reply 'No current novels found' if users.select { |n| n.length.positive? }.empty?

    display_novels m, users.flatten(1)
  end

  def novel_count(m, id)
    novel = Rogare::Data.novels.where(id: id.to_i).first
    return m.reply 'No such novel' unless novel

    count = get_novel_count novel
    display_novels m, [count]
  end

  def set_count(m, words, id = '')
    user = m.user.to_db
    novel = Rogare::Data.load_novel user, id

    return m.reply 'No such novel' if id && !novel
    return m.reply 'You don’t have a novel yet' unless novel
    return m.reply 'Can’t set wordcount of a finished novel' if novel[:finished]

    Rogare::Data.set_novel_wordcount(novel[:id], words.strip.to_i)
    own_count(m)
  end

  def set_today_count(m, words, id = '')
    user = m.user.to_db
    novel = Rogare::Data.load_novel user, id

    return m.reply 'No such novel' if id && !novel
    return m.reply 'You don’t have a novel yet' unless novel
    return m.reply 'Can’t set wordcount of a finished novel' if novel[:finished]

    existing = Rogare::Data.novel_wordcount(novel[:id])
    today = Rogare::Data.novel_todaycount(novel[:id])
    gap = words.strip.to_i - today

    Rogare::Data.set_novel_wordcount(novel[:id], existing + gap)
    own_count(m)
  end

  def add_count(m, words, id = '')
    user = m.user.to_db
    novel = Rogare::Data.load_novel user, id

    return m.reply 'No such novel' if id && !novel
    return m.reply 'You don’t have a novel yet' unless novel
    return m.reply 'Can’t set wordcount of a finished novel' if novel[:finished]

    existing = Rogare::Data.novel_wordcount(novel[:id])

    new_words = existing + if words.start_with? '-'
                             words[1..-1].to_i * -1
                           else
                             words.to_i
                           end

    return m.reply "Can’t remove more words than the novel has (#{existing})" if new_words.negative?

    Rogare::Data.set_novel_wordcount(novel[:id], new_words)
    own_count(m)
  end

  def get_novel_count(novel, user = nil)
    user ||= Rogare::Data.users.where(id: novel[:user_id]).first

    data = {
      user: user,
      novel: novel,
      count: 0
    }

    db_wc = Rogare::Data.novel_wordcount(novel[:id])

    if user[:id] == 10 && user[:nick] =~ /\[\d+\]$/ # tamgar sets their count in their nick
      data[:count] = user[:nick].split(/[\[\]]/).last.to_i
    elsif db_wc.positive?
      data[:count] = db_wc
      data[:today] = Rogare::Data.novel_todaycount(novel[:id])
    elsif novel[:type] == 'nano' # TODO: camp
      data[:count] = get_count(user[:nano_user]) || 0
      data[:today] = get_today(user[:nano_user]) if data[:count].positive?
    end

    goal = Rogare::Data.current_goal(novel)
    data[:goal] = goal

    # no need to do any time calculations if there's no time limit
    if goal && goal[:finish]
      tz = TimeZone.new(user[:tz] || Rogare.tz)
      now = tz.now

      gstart = tz.local goal[:start].year, goal[:start].month, goal[:start].day
      gfinish = tz.local(goal[:finish].year, goal[:finish].month, goal[:finish].day).end_of_day

      totaldiff = gfinish - gstart.end_of_day
      days = (totaldiff / 1.day).to_i
      totaldiff = days.days

      timetarget = gfinish
      timediff = timetarget - now

      # TODO: repeats

      data[:days] = {
        total: days,
        length: totaldiff,
        finish: goal[:finish],
        left: timediff,
        gone: totaldiff - timediff,
        expired: !timediff.positive?
      }

      unless data[:days][:expired]
        goal_secs = 1.day.to_i * data[:days][:total]

        nth = (data[:days][:gone] / 1.day.to_i).ceil
        goal = goal[:words].to_f

        goal_live = ((goal / goal_secs) * data[:days][:gone]).round
        goal_today = (goal / data[:days][:total] * nth).round

        data[:target] = {
          diff: goal_today - data[:count],
          live: goal_live - data[:count],
          percent: (100.0 * data[:count] / goal).round(1)
        }
      end
    end

    data
  end

  def get_counts(users)
    users.map do |user|
      Rogare::Data.current_novels(user).map do |novel|
        get_novel_count novel, user
      end
    end
  end

  def display_novels(m, novels)
    if rand > 0.5 && !novels.select { |n| n[:novel][:type] == 'nano' && n[:count] > 100_000 }.empty?
      m.reply "Content Warning: #{%w[Astonishing Wondrous Beffudling Shocking Monstrous].sample} Wordcount"
      sleep 1
    end

    m.reply novels.map { |n| format n }.join("\n")
  end

  def format(count)
    deets = []

    deets << "#{count[:target][:percent]}%" if count[:target]
    deets << "today: #{count[:today]}" if count[:today]

    if count[:target]
      diff = count[:target][:diff]
      deets << if diff.zero?
                 'up to date'
               elsif diff.positive?
                 "#{diff} behind"
               else
                 "#{diff.abs} ahead"
               end

      live = count[:target][:live]
      deets << if live.zero?
                 'up to live'
               elsif live.positive?
                 "#{live} behind live"
               else
                 "#{live.abs} ahead live"
               end
    end

    if count[:goal]
      if count[:novel][:type] == 'nano'
        deets << Rogare::Data.goal_format(count[:goal][:words]) unless count[:goal][:words] == 50_000
        deets << 'nano has ended' if count[:days][:expired]
      elsif count[:days] && count[:days][:expired]
        deets << Rogare::Data.goal_format(count[:goal][:words])
        deets << "over #{count[:days][:total]} days"
        deets << 'expired'
      elsif count[:target]
        deets << Rogare::Data.goal_format(count[:goal][:words])
        days = (count[:days][:left] / 1.day.to_i).floor
        deets << (days == 1 ? 'one day left' : "#{days} days left")
      else
        deets << Rogare::Data.goal_format(count[:goal][:words])
      end
    end

    name = count[:novel][:name]
    name = name[0, 35] + '…' if name && name.length > 40
    name = " _“#{Rogare::Data.encode_entities name}”_" if name

    "[#{count[:novel][:id]}] #{count[:user][:nick]}:#{name} — **#{count[:count]}** (#{deets.join(', ')})"
  end
end
