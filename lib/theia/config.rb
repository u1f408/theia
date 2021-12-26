# frozen_string_literal: true

require 'toml'

module Theia
  # The bot config class
  class Config
    # Path to the config file
    attr_reader :config_path

    def initialize(path)
      @config_path = path
      @config = nil

      rehash!
    end

    # Retrieve a config entry
    def [](k)
      @config&.[](k)
    end

    # Reload the bot config from the config file.
    #
    # Returns +true+ on success, raises an exception on error
    def rehash!
      config = TOML.load_file(@config_path)
      @config = config

      true
    end
  end
end
