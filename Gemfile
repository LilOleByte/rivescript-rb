# frozen_string_literal: true

source "https://rubygems.org"

gemspec

group :development, :test do
  gem "minitest", "~> 5.25"
  gem "rake", "~> 13.2"
end

# Security auditing (SCA + SAST security cops).
# See docs/security.md and OccamsLabs' Ruby security tooling guide.
group :security do
  gem "bundler-audit", "~> 0.9"
  gem "rubocop", "~> 1.75", require: false
end
