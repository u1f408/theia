# frozen_string_literal: true

class Nguway::Commands::Help
  extend Nguway::Command
  extend Memoist

  command 'help', hidden: true
  aliases 'list'

  match_command /.*/
  match_empty :execute

  def bot_prefix
    Nguway
      .prefix
      .to_s
      .gsub(/(
          ^\(
        | \)$
        | \^
        | \?-mix:
      )/x, '')
  end

  def command_list
    Nguway::Commands.constants.map do |cmd|
      command = Nguway::Commands.const_get cmd
      one = Nguway::Command.allmine[command.inspect.to_sym]
      next if one.nil?
      next if one[:hidden]

      [one[:command], one[:aliases]].flatten
    end.compact
  end

  def readable_commands
    command_list.map do |coms|
      coms.map! { |c| "`#{bot_prefix}#{c}`" }
      [
        coms.shift,
        ("(aliases: #{coms.join(', ')})" unless coms.empty?)
      ].compact.join ' '
    end.sort
  end

  def execute(m)
    m.reply "Commands: #{readable_commands.join(', ')}."
  end

  memoize :bot_prefix, :command_list, :readable_commands
end
