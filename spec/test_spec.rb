# frozen_string_literal: true

require 'test/unit'
require 'rack/test'

require './app.rb'

APP = Rack::Builder.parse_file('config.ru').first
