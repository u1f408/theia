# frozen_string_literal: true

class Theia::Module::DataCache
  extend Theia::ModuleHooks

  hook_to :on_message do |message|
    cache_user(message.author)
    cache_server(message.server)
    cache_server_user(message.server, message.author)
  end

  hook_to :on_reaction_add do |event|
    cache_user(event.user)
    cache_server(event.server)
    cache_server_user(event.server, event.user)
  end

  class << self
    def cache_user(user)
      cfg = Theia::DataStore.user(user)
      cfg[:user_distinct] = user.distinct
    end

    def cache_server(server)
      cfg = Theia::DataStore.server(server)
      cfg[:server_name] = server.name
    end

    def cache_server_user(server, user)
      cfg = Theia::DataStore.server(server).user(user)
      cfg[:user_distinct] = user.distinct
      cfg[:user_displayname] = user.display_name
    end
  end
end
