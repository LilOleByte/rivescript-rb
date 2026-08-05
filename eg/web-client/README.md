# Web Client Example

This example embeds a RiveScript bot in a web page backed by Ruby.

Unlike the JavaScript web-client (which runs RiveScript entirely in the
browser), this Ruby version serves the brain from a small WEBrick HTTP server
and exposes a JSON chat API.

## Usage

```bash
$ cd eg/web-client
$ ruby server.rb
```

Then open <http://127.0.0.1:8080/chat.html>

Optional: `PORT=9090 ruby server.rb`

## API

* `GET /api/version` → `{ "version": "0.1.0" }`
* `POST /api/reply` with `{ "username": "soandso", "message": "Hello" }`
  → `{ "reply": "...", "version": "0.1.0" }`

Static files (`chat.html`, `chat.css`) are served from this directory.
The bot loads replies from `../brain/`.
