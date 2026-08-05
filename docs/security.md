# Security auditing

This project follows the open-source Ruby security tooling approach described in
[Securing your Ruby and Rails Codebase](https://www.occamslabs.com/ruby-on-rails/security/devsecops/2018/09/24/securing-your-ruby-and-rails-codebase/)
(OccamsLabs): **SCA** for dependencies and **SAST** for insecure code patterns.

## Tools

| Tool | Kind | Role here |
| --- | --- | --- |
| [bundler-audit](https://github.com/rubysec/bundler-audit) | SCA | Advisories against gems in the lockfile |
| [RuboCop](https://github.com/rubocop/rubocop) Security cops | SAST | `Security/*` + `Bundler/InsecureProtocolSource` only |
| Brakeman | SAST | **Not used** — this is a library gem, not Rails/Sinatra/Rack |

`rubocop-gitlab-security` from that article is archived; its successors live in
`gitlab-styles`. For this gem we stick to RuboCop’s built-in Security department
to avoid a heavy style stack.

## Install

Security gems live in the `:security` group:

```bash
bundle config set --local with security
bundle install
```

## Run locally

```bash
bundle exec rake security
```

That runs:

1. `bundle audit check --update` (via `rake bundle:audit`)
2. `rubocop` with [`.rubocop.yml`](../.rubocop.yml) (security cops only)

Or individually:

```bash
bundle exec bundle-audit check --update
bundle exec rubocop
```

## Known intentional finding

Ruby object macros use `Kernel#eval` in `lib/rivescript/lang/ruby.rb`. That is
required by the RiveScript object-macro design (same idea as JS `eval` in
rivescript-js). Mitigations:

* Default can be turned off: `RiveScript.new(enable_object_macros: false)`
* Or at runtime: `bot.set_handler("ruby", nil)`
* Only load brains you trust (see [lang.ruby.md](./lang.ruby.md))

The Security/Eval offense on that line is disabled with an inline comment.

## CI

The GitHub Actions **Security** job runs `rake security` on every push and PR.
