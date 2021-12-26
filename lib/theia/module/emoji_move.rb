# frozen_string_literal: true

class Theia::Module::EmojiMove
  extend Theia::Command
  include Theia::Subcommand

  derive_help_subcommand
  command "emojimove", hidden: true, help: [
    "Move emoji between servers."
  ]

  subcommand("export", help: "Generate a list of all emoji in this server") do |cmdargs, opts|
    opts[:message].react "🔄"

    server = opts[:source_message].server
    emoji = server.emoji.map do |emid, em|
      [em.name, emid]
    end.to_h

    emjson = JSON.generate(emoji)
    emreq = Typhoeus::Request.new("http://sprunge.us", {
      method: :post,
      body: {
        sprunge: emjson,
      },
    }).run

    return opts[:message].reply! "❌ Emoji JSON dump upload failed" unless emreq.success?
    opts[:message].reply! "✅ #{emoji.count} emoji dumped: <#{emreq.body.strip}>"
  end

  subcommand("import", help: "Import a JSON hash of emoji names to IDs") do |cmdargs, opts|
    opts[:message].react "🔄"
    server = opts[:source_message].server

    emoji = cmdargs[:args][1..].each do |url|
      req = Typhoeus::Request.new(url).run
      next nil unless req.success?
      json = JSON.parse(req.body.strip)
      next nil unless json.is_a?(Hash)

      json.map do |emname, emid|
        emurl = "https://cdn.discordapp.com/emojis/#{emid}.webp"
        emdata = Typhoeus::Request.new(emurl).run.body
        emfile = StringIO.new(emdata)

        server.add_emoji(emname, emfile)
      end
    end.flatten

    opts[:message].reply! "✅ Imported #{emoji.count} emoji :3"
  end
end
