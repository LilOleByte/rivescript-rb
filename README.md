# RiveScript-rb

A [RiveScript](https://www.rivescript.com/) interpreter for Ruby 3.3+.

Maintained at [jvmlab.org](https://jvmlab.org/) by Byte (`byte@jvmlab.org`).
Derived from the MIT-licensed [rivescript-js](https://github.com/aichaos/rivescript-js)
implementation.

## Requirements

* Ruby `>= 3.3.0` (developed on **3.3.8**)

## Install (recommended)

### In an application (Bundler)

Add to your `Gemfile`:

```ruby
gem "rivescript", "~> 0.1.2"
```

Then:

```bash
bundle install
```

Use it only through Bundler:

```bash
bundle exec ruby app.rb
bundle exec riveshell
```

### System / user gem (CLI and scripts)

```bash
gem install rivescript
```

Put Ruby gem binaries on your `PATH` if needed:

```bash
export PATH="$(ruby -e 'print Gem.user_dir')/bin:$PATH"
```

Then:

```bash
riveshell
```

### From GitHub or this repository

```ruby
# Gemfile (development / unreleased tip)
gem "rivescript",
    git: "https://github.com/LilOleByte/rivescript-rb.git",
    tag: "v0.1.2"
```

```bash
bundle install
bundle exec rake package          # builds pkg/rivescript-0.1.2.gem + verifies contents
gem install --user-install pkg/rivescript-0.1.2.gem
```

## Usage

```ruby
require "rivescript"

bot = RiveScript.new
bot.load_directory(RiveScript.brain_path)  # bundled sample brain
# or: bot.load_directory("./my-custom-brain")
bot.sort_replies

puts bot.reply("localuser", "Hello bot")
```

Load from a string:

```ruby
bot = RiveScript.new
bot.stream(<<~RIVE)
  + hello bot
  - Hello, human!
RIVE
bot.sort_replies
puts bot.reply("user", "hello bot")
```

Full API reference: [docs/](docs/README.md) (same layout as
[rivescript-js/docs](https://github.com/aichaos/rivescript-js/tree/master/docs),
adapted for Ruby).

Security audits: [docs/security.md](docs/security.md) (`bundle exec rake security`).

## Interactive shell

```bash
bundle exec riveshell                 # Bundler apps
riveshell                             # after gem install
riveshell /path/to/custom-brain       # your own replies
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

Object macros run real Ruby. Only load brains you trust.
Disable with `RiveScript.new(enable_object_macros: false)`.

## Develop / test this gem

```bash
bundle install
bundle exec rake test
bundle exec rake package
```

## License

MIT — see [LICENSE](LICENSE).

Original RiveScript copyright (c) Noah Petherbridge / AiChaos.
Ruby port copyright (c) 2026 Byte \<byte@jvmlab.org\> ([jvmlab.org](https://jvmlab.org/)).
