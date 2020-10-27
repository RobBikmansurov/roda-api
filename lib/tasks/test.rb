# frozen_string_literal: true

require 'rake/testtask'

desc 'Run tests'
Rake::TestTask.new do |t|
  t.test_files = FileList['spec/**/*_spec.rb']
  t.verbose = true
end

task default: :test
