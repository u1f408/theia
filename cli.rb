# frozen_string_literal: true

ENV['RACK_ENV'] ||= 'development'
require './lib/logs'

logs "=====> Bootstrapping in #{ENV['RACK_ENV']}"
require 'bundler'
Bundler.require :default, ENV['RACK_ENV'].to_sym

logs '=====> Loading framework'
require './lib/theia'
require './lib/catgirls'
require './lib/pluralkit'

logs '=====> Loading sequel'
DB = Theia.sql
Sequel::Model.plugin :eager_each
Sequel::Model.plugin :pg_auto_constraint_validations
Sequel::Model.plugin :prepared_statements
Sequel::Model.plugin :prepared_statements_safe

logs '=====> Loading models'
Dir['./models/*.rb'].each do |p|
  logs "     > #{Pathname.new(p).basename('.rb').to_s.camelize}"
  require p
end
