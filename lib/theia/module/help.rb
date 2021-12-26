# frozen_string_literal: true

class Theia::Module::Help
  extend Theia::Command
  command "help", hidden: true

  def execute(cmdargs, opts = {})
    prefix = Theia.config['prefix']

    args = cmdargs[:args].map(&:strip)
    show_all = args.map { |w| /^-{1,2}a(?:ll)?$/ =~ w }.any?

    cmds_with_help = []
    replytext = ["**Commands:**"] + (Theia::Command.allcmds.map do |cmd, data|
      next if !show_all && data[:hidden]
      cmds_with_help << cmd if data[:klass].instance_methods.include?(:execute_help)

      htext = data[:help]&.first || "A mystery command."
      "`#{prefix}#{cmd}` - #{htext}"
    end.compact)

    replytext << ""
    replytext << "Most commands accept `--help` as a flag, which you can use to get more info."
    replytext << "For example, try `#{prefix}#{cmds_with_help.sample} --help`."

    opts[:message].reply! replytext.join("\n")
  end
end
