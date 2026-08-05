# Production-style Bundler app

```bash
cd eg/bundler-app
bundle install
bundle exec ruby hello.rb
bundle exec ruby hello.rb What is your name?
bundle exec riveshell
```

This Gemfile uses `path: "../.."` while developing the gem in-tree.
In a real app, switch to a git tag or RubyGems version (see the main README).
