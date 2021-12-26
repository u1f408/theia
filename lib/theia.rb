# frozen_string_literal: true

require 'pluralkit_api'

module Theia
  module Module; end

  require 'theia/logline'
  require 'theia/config'
  require 'theia/datastore'
  require 'theia/command'
  require 'theia/subcommand'
  require 'theia/command_parser'
  require 'theia/module_hooks'

  class << self
    attr_reader :config
    attr_reader :cmdparser, :cmdhandler
    attr_reader :discord
    
    @@threads = []

    def spinoff(_name, &block)
      @@threads << Thread.new(&block)
    end

    def spinall!
      require 'thwait'
      ThreadsWait.all_waits(*@@threads)
    end

    def init!
      Theia::DataStore.connect!(ENV['REDIS_URL'] || 'redis://localhost/1')
      @config = Theia::Config.new(ENV['THEIA_CONFIG'] || 'theia.toml')
      
      # Instantiate the Discordrb::Bot
      @discord = Discordrb::Bot.new(token: ENV['THEIA_BOT_TOKEN'])
      @discord.reaction_add { |ev| Theia::ModuleHooks.execute_hook :on_reaction_add, ev }
      @discord.message { |ev| Theia::ModuleHooks.execute_hook :on_raw_message, ev.message }

      # Get modules to load
      enabled_modules = %w[core datacache help]
      @config['modules'].each do |modname, cfg|
        next unless cfg.key?('enabled')
        if cfg['enabled']
          enabled_modules << modname
        else
          enabled_modules.delete modname
        end
      end

      # And load the modules
      enabled_modules.map do |modname|
        Theia.logline("Loading module #{modname.inspect}...")
        require "theia/module/#{modname}"
        modname
      end
    end

    def start!
      spinoff(:discord) do 
        @discord.run
      end

      spinall!
    end
  end
end
