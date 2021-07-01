# frozen_string_literal: true

module PluralKitApi
  PLURALKIT_API_BASE = "https://api.pluralkit.me/v1"
  PKAWAKE_API_BASE = "https://awake.iris.ac.nz/api"

  module_function

  def system_id_from_discord_id(discord_id)
    url = PLURALKIT_API_BASE + "/a/#{discord_id.to_s}"
    data = JSON.parse Typhoeus::Request.new(url).run.body
    return nil unless data['id']
    data['id']
  end

  def awake_data(system_id)
    url = PKAWAKE_API_BASE + "/#{system_id}"
    data = JSON.parse Typhoeus::Request.new(url).run.body
    return nil unless data['system']
    data
  end

  def awake_embed(m, system_id)
    data = awake_data(system_id)
    if data.nil?
      m.reply "Hmm, that user doesn't appear to have an associated PluralKit system."
    end

    status = data['awake'] ? 'awake' : 'sleeping'
    fronters = data['fronters'].map do |member|
      {
        name: member['display_name'] || member['name'],
        pronouns: member['pronouns'],
        avatar: member['avatar_url'],
      }
    end

    m.inner.send_embed do |em|
      em.description = "**#{data['system']['name']}** is currently **#{status}**"

      # For how long?
      if (switch_fts = data['switch_ts']&.[]('friendly'))
        em.add_field(name: 'For a total of', value: switch_fts, inline: false)
      end

      if fronters.count.positive?
        fnames = fronters.map{|x| x[:name]}.join(', ')
        em.add_field(name: 'Current fronters', value: fnames, inline: false)

        # Current first fronter avatar
        if !(fronters.first[:avatar].nil?())
          em.thumbnail = Discordrb::Webhooks::EmbedImage.new(url: fronters.first[:avatar])
        end
      end
    end
  end
end
