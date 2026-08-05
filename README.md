# RiveScript-RB

A [RiveScript](https://www.rivescript.com/) interpreter for Ruby 3.3+.

RiveScript is a scripting language for chatterbots, making it easy to write
trigger/response pairs for building up a bot's intelligence.

This project is a clean Ruby port maintained at [jvmlab.org](https://jvmlab.org/)
by Byte (`byte@jvmlab.org`). It is derived from the MIT-licensed
[rivescript-js](https://github.com/aichaos/rivescript-js) implementation.

## Requirements

* Ruby **3.3.8** (or compatible Ruby `>= 3.3.0`)

## Installation

Add to your Gemfile:

```ruby
gem "rivescript", path: "/path/to/rivescript-rb"
```

Or build and install locally:

```bash
gem build rivescript.gemspec
gem install rivescript-*.gem
```

## Usage

```ruby
require "rivescript"

bot = RiveScript.new
bot.load_directory("./eg/brain")
bot.sort_replies

reply = bot.reply("localuser", "Hello bot")
puts reply
```

Load from a string instead of files:

```ruby
bot = RiveScript.new
bot.stream(<<~RIVE)
  + hello bot
  - Hello, human!
RIVE
bot.sort_replies
puts bot.reply("user", "hello bot")
```

## Interactive shell

```bash
./bin/riveshell eg/brain
# or after install:
riveshell eg/brain
```

Options: `--debug`, `--utf8`.

## Object macros (Ruby)

```rive
> object setname ruby
  return args[0]
< object

+ my name is *
- <set name=<call>setname <star></call>>Nice to meet you, <get name>.
```

Object macros are evaluated with Ruby (`eval`). Only load trusted RiveScript.
Disable them entirely with `RiveScript.new(enable_object_macros: false)`.

## Testing

```bash
rake test
# or:
ruby -Ilib:test -e 'Dir["test/**/test_*.rb"].each { |f| require "./#{f}" }'
```

The suite covers RiveScript language behavior: triggers, replies, topics,
begin blocks, math tags, substitutions, Unicode, options, API, and Ruby
object macros.

## License

MIT — see [LICENSE](LICENSE).

Original RiveScript copyright (c) Noah Petherbridge / AiChaos.
Ruby port copyright (c) 2026 Byte \<byte@jvmlab.org\> ([jvmlab.org](https://jvmlab.org/)).
