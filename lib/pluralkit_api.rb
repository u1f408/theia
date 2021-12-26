# frozen_string_literal: true

module PluralKitAPI
  API_BASE = "https://api.pluralkit.me/v2"

  class << self
    def message(message, opts = {})
      opts.merge!({ timeout: 3 })
      (opts[:headers] ||= {}).merge!({
        "User-Agent" => "Theia/0.0.0 (https://github.com/u1f408/theia)",
      })

      unless ENV['PLURALKIT_TOKEN'].nil?
        (opts[:headers] ||= {}).merge!({
          "Authorization" => "Bearer #{ENV['PLURALKIT_TOKEN']}",
        })
      end

      msg_id = message.id
      msg_author = message.author.id

      # Get the message author's PluralKit system - if they don't have one,
      # bail early, to avoid having to repeatedly hit the PluralKit API for
      # a message that will never be proxied
      Theia.logline("Trying PluralKitAPI #{"/systems/#{msg_author}"}")
      author_req = Typhoeus::Request.new((PluralKitAPI::API_BASE + "/systems/#{msg_author}"), opts).run
      unless author_req.success?
        Theia.logline("System request unsuccessful, probably not a system?", {
          request: author_req,
        })

        return nil
      end

      author = JSON.parse author_req.body

      # Message author has a PluralKit system, let's ask PluralKit for info
      # on this message (with a rudimentary backoff thing in case PluralKit
      # is lagging slightly on message proxying)
      message, tries, delay = nil, 1, 0.5
      while tries <= 3
        sleep delay

        Theia.logline("Trying PluralKitAPI #{"/messages/#{msg_id}"}")
        req = Typhoeus::Request.new((PluralKitAPI::API_BASE + "/messages/#{msg_id}"), opts).run
        unless req.success?
          tries += 1
          delay *= tries

          next Theia.logline("Message request unsuccessful, maybe trying again in #{delay}", {
            request: req,
          })
        end

        message = JSON.parse req.body
        break
      end

      {
        system: author,
        message: message,
      }
    end
  end
end
