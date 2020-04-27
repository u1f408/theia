module Catgirls
  class Character
    attr_reader :name, :nameday, :server, :portrait_url
    attr_reader :job_name, :job_level
    attr_reader :fc_name

    def initialize(data)
      @raw_data = data

      @name = data["Character"]["Name"]
      @nameday = data["Character"]["Nameday"]
      @server = data["Character"]["Server"]
      @portrait_url = data["Character"]["Portrait"]
      @job_level = data["Character"]["ActiveClassJob"]["Level"]
      @job_name = data["Character"]["ActiveClassJob"]["Name"]
        .split(' ')
        .map{|x| [x.split('').first.upcase, x.split('')[1..]].flatten.join('')}
        .join(' ')

      if data["FreeCompany"]
        @fc_name = data["FreeCompany"]["Name"]
      end
    end

    def describe
      [
        [
          "**#{@name}** on #{@server}",
          ("Member of **#{@fc_name}**" if @fc_name),
        ].compact.join(" - "),
        "Nameday: #{@nameday}",
      ].compact.join("\n")
    end

    def embed(m)
      m.inner.send_embed do |em|
        em.description = "**#{@name}** on #{@server}"
        em.add_field(name: 'Nameday', value: @nameday, inline: true)
        em.add_field(name: 'Free Company', value: @fc_name, inline: true) if @fc_name
        em.add_field(name: 'Class / Job', value: "#{@job_name}, level #{@job_level}")

        em.image = Discordrb::Webhooks::EmbedImage.new(url: @portrait_url)
      end
    end
  end

  class << self
    extend Memoist

    def api_key
      ENV['XIVAPI_KEY']
    end

    def request(path, opts = {})
      url = 'https://xivapi.com' + path
      if api_key
        opts[:params] ||= {}
        opts[:params][:private_key] = api_key
      end

      JSON.parse Typhoeus::Request.new(url, opts).run.body
    end

    def servers
      request('/servers')
    end

    def character_search(server, char)
      data = request('/character/search', params: {server: server, name: char})
      return nil unless data["Results"].count == 1
      data["Results"][0]["ID"].to_s
    end

    def character(id)
      data = request("/character/#{id}", params: {data: 'CJ,FC'})
      Catgirls::Character.new(data)
    end

    memoize :api_key, :servers
  end
end
