# frozen_string_literal: true

require 'bundler/setup'
Bundler.require

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), "lib"))

task :setup do
  require 'theia'
end

task :console => [:setup] do
  require 'pry'
  Pry.start
end
