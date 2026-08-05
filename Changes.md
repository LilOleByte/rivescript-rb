# Changes

## Unreleased

- Preserve `%previous` context when a turn returns `ERR: No Reply Matched`
  or `ERR: No Reply Found` (do not overwrite `history.reply[0]`)
- Add `eg/previous` demo for `%previous` surviving unmatched replies

## 0.1.1

- Ship the sample brain (`eg/brain`) inside the gem
- Add `RiveScript.brain_path` so any app can load the bundled replies
- `riveshell` uses the bundled brain when no path is given
- CI builds the gem and checks that the brain files are included
- Release workflow publishes to RubyGems.org via Trusted Publishing

## 0.1.0

- First Ruby 3.3 port of the RiveScript interpreter
