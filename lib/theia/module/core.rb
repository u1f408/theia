# frozen_string_literal: true

class Theia::Module::Core
  extend Theia::ModuleHooks

  @@message_cache = LruRedux::TTL::ThreadSafeCache.new(100, 10)
  def self.message_cache
    @@message_cache
  end

  hook_to :on_raw_message do |msg|
    # Cache the message object
    @@message_cache[msg.id.to_s] = msg

    # Run message hooks
    hook_method = msg.webhook? ? :on_webhook_message : :on_message
    Theia::ModuleHooks.execute_hook(hook_method, msg)
  end

  hook_to :on_message do |srcmsg|
    # Get user object in datastore for this message's author
    userds = Theia::DataStore.user(srcmsg.author)

    # Check if this message has been proxied by PluralKit, using the
    # PluralKit proxied message if it has been, otherwise using the source
    # message -- allowing for a PluralKit user to start a command with their
    # proxy tags (assuming they don't have keepproxy on), and also allowing
    # us to reply to the proxied message with our command response.
    msg, pkdata = srcmsg, nil
    if userds.get(:pluralkit_enabled, 1).to_i.positive?
      pkdata = PluralKitAPI.message(srcmsg)
      unless pkdata.nil? || pkdata[:message].nil?
        pkmsg = @@message_cache[pkdata[:message]['id'].to_s]
        msg = pkmsg unless pkmsg.nil?
      end
    end

    # Attempt to parse out a command, returning early if there isn't one
    cmdargs = Theia::CommandParser.parse(msg)
    next if cmdargs.nil?

    # Run command hook
    Theia::ModuleHooks.execute_hook(:on_command, cmdargs, {
      message: msg,
      source_message: srcmsg,
      pluralkit_data: pkdata,
    })
  end

  hook_to :on_command do |cmdargs, opts|
    Theia.logline("Calling command handler, let's go", cmdargs: cmdargs)
    Theia::Command.handle_command!(cmdargs, opts)
  end
end