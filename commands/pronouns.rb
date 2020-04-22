# frozen_string_literal: true

class Nguway::Commands::Pronouns
  extend Nguway::Command

  command 'pronouns'
  aliases 'gender'
  usage '`!%` - You’re a sweetie'
  handle_help

  match_empty :execute
  def execute(m)
    m.reply 'My pronouns are fae/fer, thanks for asking :)'
  end
end
