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
  Theia.spinoff(:debug) do
    logs '=====> Preparing live debug port'
    binding.remote_pry
  end
end

Theia.spinoff(:discord) do
  logs '=====> Starting Discord'
  Theia.discord.run
end

if ENV['RACK_ENV'] == 'production' && ENV['LEAVE_STATUS'].nil?
  Theia.spinoff(:game_cycle) do
    logs '=====> Spinning up game cycler'
    loop do
      sleep 10.minutes

      game = Theia.game
      logs "=====> Cycling game to: #{game}"
      Theia.discord.update_status('online', game, nil)
    end
  end
end

Theia.spinall!
