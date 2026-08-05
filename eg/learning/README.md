# Learning Example

This implements a RiveScript bot that is able to learn new triggers and
responses from the user.

> **User:** Hello bot.
> **Bot:** I don't know how to reply to that. Can you teach me?
> **User:** When I say hello bot you say hello human! :)
> **Bot:** Got it.
> **User:** Hello bot!
> **Bot:** Hello human! :)

## Usage

```bash
$ cd eg/learning
$ ruby bot.rb
```

Learned replies are saved in `learned.rive` and reloaded on the next run.

## Example

```
% ruby bot.rb
> Hello
[Soandso] Hello
[Bot] I don't know how to reply to that. Why not teach me?
...
> when I say hello you say Hello human!
[Bot] I have learned: when you say "hello" I should say "Hello human!"
> Hello
[Bot] Hello human!
```

## Notes

* Object macros use Ruby (`eval`). Only use with trusted input.
* Duplicate triggers are not updated — the first learned trigger wins.
* This is a toy example; see the JS original for security caveats.
