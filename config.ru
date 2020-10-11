# frozen_string_literal: true

require 'roda'

require './app.rb'

run App.freeze.app
