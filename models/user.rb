# frozen_string_literal: true

class User < Sequel::Model
  plugin :timestamps, create: :first_seen, update: :updated, update_on_create: true, allow_manual_update: true

  @discord = nil
  attr_accessor :discord

  def self.from_discord(discu)
    u = where(discord_id: discu.id).first
    return unless u

    u.discord = discu
    u
  end

  def self.create_from_discord(discu)
    u = from_discord discu
    return u if u

    u = create(discord_id: discu.id)
    u.discord = discu
    u
  end

  def seen!
    return self unless Time.now - last_seen > 60 || nick != discord_nick

    # keep same updated stamp unless we actually update something
    self.updated = updated unless nick != discord_nick
    self.last_seen = Time.now
    self.nick = discord_nick
    save

    self
  end

  def discord_nick
    (@discord.nick if @discord.is_a? Discordrb::Member) ||
      @discord.username ||
      '?'
  end

  def send_msg(message)
    @discord.pm message
  end

  def mid
    "<@#{discord_id}>"
  end

  def nixnotif
    Nguway.nixnotif nick
  end

  def timezone
    TimeZone.new tz
  end

  def date_in_tz(date)
    timezone.local date.year, date.month, date.day
  end

  def now
    timezone.now
  end
end
