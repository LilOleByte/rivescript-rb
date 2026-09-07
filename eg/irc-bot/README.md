# IRC Chatbot Example

A RiveScript bot that speaks IRC. It uses only the Ruby standard library
(`socket` / `openssl`) — no extra gems — and loads replies from `../brain/`.

The bot joins a channel and answers:

* Channel messages that start with its nick (`rsbot: hello` or `@rsbot hello`)
* Direct private messages

Each IRC nick is used as the RiveScript username, so the brain can remember
per-user variables (name, age, and so on) across the session.

## Usage

From the root of the rivescript-rb repo:

```bash
$ ruby eg/irc-bot/bot.rb
```

Or from this directory:

```bash
$ ruby bot.rb
```

By default the bot connects to `127.0.0.1:6667` as `rsbot` and joins
`#rivescript`. Point it at a real network with environment variables:

```bash
$ IRC_HOST=irc.libera.chat IRC_PORT=6697 IRC_TLS=1 \
    IRC_NICK=rsbot IRC_CHANNEL=#botters-test ruby bot.rb
```

Then in the channel:

```
<alice> rsbot: Hello bot.
<rsbot> Hi. What seems to be your problem?
<alice> rsbot: my name is Alice
<rsbot> Alice, nice to meet you.
```

Private messages are answered without needing the nick prefix. Type `/quit` in
your IRC client to leave; send `SIGINT` (`Ctrl-C`) to the bot process to
disconnect cleanly.

## Configuration

| Variable | Default | Meaning |
| --- | --- | --- |
| `IRC_HOST` | `127.0.0.1` | IRC server hostname |
| `IRC_PORT` | `6667` | IRC server port (`6697` is typical for TLS) |
| `IRC_NICK` | `rsbot` | Nickname |
| `IRC_CHANNEL` | `#rivescript` | Channel to join (`#` is added if omitted) |
| `IRC_PASSWORD` | _(none)_ | Server password (`PASS`) |
| `IRC_NICKSERV_PASSWORD` | _(none)_ | Sent as `IDENTIFY` to NickServ after welcome |
| `IRC_TLS` | unset | Set to `1` to wrap the socket in TLS |
| `IRC_ALWAYS` | unset | Set to `1` to reply to every channel message, not only mentions |
| `IRC_BRAIN` | `../brain` | Directory of `.rive` files |

`ruby bot.rb --help` prints the same table.

TLS uses certificate verification (`VERIFY_PEER`). This example does not
implement SASL; NickServ identify is the optional auth path.

## Notes

* Object macros in the sample brain are loaded. Only point `IRC_BRAIN` at
  brains you trust.
* Replies are split on newlines and wrapped to stay under IRC's 512-byte line
  limit.
* This is a teaching adapter, not a full IRC client: no SASL, no multi-channel
  config file, no flood throttle.
