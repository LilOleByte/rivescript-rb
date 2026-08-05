# Telnet Server Example

This is a simple Ruby TCP server that implements RiveScript. It listens on
port 2001 and chats with any connected users.

## Usage

From the root of the rivescript-rb repo:

```bash
$ ruby eg/telnet-server/tcp_server.rb
```

Or from this directory:

```bash
$ ruby tcp_server.rb
```

Then in a different shell, connect via telnet:

```bash
% telnet localhost 2001
Trying 127.0.0.1...
Connected to localhost.
Escape character is '^]'.
Hello 127.0.0.1:50529! This is RiveScript.rb v0.1.0 running on Ruby!
Type /quit to disconnect.

You> Hello bot.
Bot> Hi. What seems to be your problem?
```

Type `/quit` to disconnect.
