# frozen_string_literal: true

require 'rubocop/rake_task'

GEM_NAME = 'sensething'
GEM_VERSION = '0.0.2'

def del(pattern)
  pattern = File.join(__dir__, pattern)
  Dir.glob(pattern).each do |f|
    File.delete f
  end
end

task default: %i[build test]

RuboCop::RakeTask.new(:lint) do |task|
  task.patterns = ['lib/**/*.rb', 'test/**/*.rb']
  task.fail_on_error = true
end

task :build do
  system "gem build #{GEM_NAME} .gemspec"
end

task install: :build do
  system "gem install #{GEM_NAME}-#{GEM_VERSION}.gem"
end

task publish: :build do
  system "gem push #{GEM_NAME}-#{GEM_VERSION}.gem"
end

task :test do
  Dir.glob('test/*.rb').each do |f|
    ruby f
  end
end

task :clean do
  del '*.gem'
end
