# Changes

## 0.1.1

- Publish as the RubyGems gem `rivescript-rb` (`require "rivescript"`)
- Ship the sample brain (`eg/brain`) inside the gem
- Add `RiveScript.brain_path` so any app can load the bundled replies
- `riveshell` uses the bundled brain when no path is given
- CI builds the gem and checks that the brain files are included
- Release workflow publishes to RubyGems.org via Trusted Publishing

## 0.1.0

- First Ruby 3.3 port of the RiveScript interpreter
