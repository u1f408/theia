# frozen_string_literal: true

module Theia
  @@logline_id = 0

  class << self
    def logline(msg, data = {})
      msgid = (@@logline_id += 1).to_s(16)
      msgid.insert(0, '0') while msgid.length < 8
      loc = caller_locations(1, 1)[0].to_s
      
      final = [msg].flatten.join("\n").split("\n")
      final[0] = "#{loc} >> #{final[0]}"
      unless data.empty?
        data.map do |k, v|
          final << "#{k.inspect} => #{v.inspect}"
        end
      end

      $stderr.puts final
        .flatten
        .join("\n")
        .split("\n")
        .map { |l| "[#{msgid}] #{l}"}
        .join("\n")

      $stderr.flush
      nil
    end
  end
end
