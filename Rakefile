# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"
require "fileutils"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/test_*.rb"]
  t.warning = false
end

task default: :test

REQUIRED_BRAIN = %w[
  begin.rive
  clients.rive
  myself.rive
  eliza.rive
  admin.rive
  rpg.rive
].freeze

desc "Build the gem and check the small publish set (lib + brain + docs)"
task :package do
  Rake::Task["build"].invoke

  gem_path = Dir["pkg/rivescript-*.gem"].max_by { |p| File.mtime(p) }
  abort "No gem built under pkg/" unless gem_path

  listing = `gem unpack #{gem_path} --target /tmp 2>&1`
  version = File.basename(gem_path, ".gem").sub(/\Arivescript-/, "")
  unpack_dir = "/tmp/rivescript-#{version}"
  abort "gem unpack failed:\n#{listing}" unless File.directory?(unpack_dir)

  missing = []
  %w[lib/rivescript.rb bin/riveshell LICENSE README.md Changes.md].each do |path|
    missing << path unless File.exist?(File.join(unpack_dir, path))
  end
  REQUIRED_BRAIN.each do |name|
    path = File.join("eg/brain", name)
    missing << path unless File.exist?(File.join(unpack_dir, path))
  end

  FileUtils.rm_rf(unpack_dir)

  unless missing.empty?
    abort "Gem is missing required publish files:\n  - #{missing.join("\n  - ")}"
  end

  puts "OK package #{gem_path}"
  puts "Includes bundled brain (#{REQUIRED_BRAIN.size} .rive files)"
end
