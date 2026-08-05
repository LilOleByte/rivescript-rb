# frozen_string_literal: true

require_relative "lib/rivescript/version"

Gem::Specification.new do |spec|
  spec.name          = "rivescript"
  spec.version       = RiveScript::VERSION
  spec.authors       = ["Byte"]
  spec.email         = ["byte@jvmlab.org"]

  spec.summary       = "RiveScript interpreter for Ruby"
  spec.description   = "RiveScript is a scripting language for chatterbots. " \
                       "This gem is a Ruby 3.3 port of the RiveScript interpreter."
  spec.homepage      = "https://github.com/LilOleByte/rivescript-rb"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata = {
    "homepage_uri" => "https://jvmlab.org/",
    "source_code_uri" => "https://github.com/LilOleByte/rivescript-rb",
    "changelog_uri" => "https://github.com/LilOleByte/rivescript-rb/blob/main/Changes.md",
    "bug_tracker_uri" => "https://github.com/LilOleByte/rivescript-rb/issues",
    "rubygems_mfa_required" => "true"
  }

  # Small publish set: library, shell, license/docs, and bundled brain.
  spec.files = Dir[
    "LICENSE",
    "README.md",
    "Changes.md",
    "docs/**/*",
    "lib/**/*",
    "bin/*",
    "eg/brain/**/*.rive"
  ]
  spec.bindir        = "bin"
  spec.executables   = ["riveshell"]
  spec.require_paths = ["lib"]
end
