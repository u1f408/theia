require 'digest/sha2'

class Caskbot::Plugins::Hash
  include Cinch::Plugin

  match %r{hash (https?://.+)}

  def execute(m, url)
    digest = Digest::SHA2.new(256)

    request = Typhoeus::Request.new url, followlocation: true
    request.on_headers do |res|
      if res.code == 200
        info "[hash] Getting checksum for #{url}"
      else
        info "[hash] Failed getting #{url}"
        m.reply "Request failed for #{url}: Error #{res.code}"
        return
      end
    end

    request.on_body do |chunk|
      digest.update chunk
    end

    request.on_complete do |res|
      m.reply "SHA256: #{digest.hexdigest} (#{url})"
    end

    info "[hash] Attempting to get #{url}"
    request.run
  end
end
