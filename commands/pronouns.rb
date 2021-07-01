# frozen_string_literal: true

class Theia::Commands::Pronouns
  extend Theia::Command

  command 'pronouns'
  aliases 'gender'
  usage '`!%` - You’re a sweetie'
  handle_help

  match_empty :execute
  def execute(m)
    m.reply 'My pronouns are it/its, thanks for asking :)'
  end
end
