# frozen_string_literal: true

require './cli'

logs '=====> Loading commands'
Dir['./commands/*.rb'].each do |p|
  name = Pathname.new(p).basename('.rb').to_s
  if ENV['COMMANDS_WHITELIST']
    next unless ENV['COMMANDS_WHITELIST'].split(',').include? name
  end

  require p
end

logs '=====> Preparing threads'

if ENV['RACK_ENV'] == 'production'
  Nguway.spinoff(:debug) do
    logs '=====> Preparing live debug port'
    binding.remote_pry
  end
end

Nguway.spinoff(:discord) do
  logs '=====> Starting Discord'
  Nguway.discord.run
end

Rogare.spinoff(:game_cycle) do
  logs '=====> Spinning up game cycler'
  loop do
    sleep 10.minutes

    game = Nguway.game
    logs "=====> Cycling game to: #{game}"
    Nguway.discord.update_status('online', game, nil)
  end
end

Nguway.spinall!
