# Asynchronous Second Reply

This example demonstrates how a Ruby object macro can send a second reply to
the user asynchronously after a timeout.

The host bot passes `self` as the `scope` to `reply()`, so inside the object
macro `self` refers to the `MyBot` instance and can call `send_message`.

## Usage

```bash
$ cd eg/second-reply
$ ruby bot.rb
```

## Example Output

```
% ruby bot.rb
> reply test
[Soandso] reply test
[Bot] @Soandso: Wait for it...
> [Bot] @Soandso: Second reply!
```

The "Second reply!" line is delivered about 2 seconds after "Wait for it...".
