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
  spec.homepage      = "https://jvmlab.org/"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["homepage_uri"]    = spec.homepage
  spec.metadata["source_code_uri"] = "https://jvmlab.org/"
  spec.metadata["bug_tracker_uri"] = "https://jvmlab.org/"

  spec.files = Dir[
    "LICENSE",
    "README.md",
    "lib/**/*",
    "bin/*"
  ]
  spec.bindir        = "bin"
  spec.executables   = ["riveshell"]
  spec.require_paths = ["lib"]
end
