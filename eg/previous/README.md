# %Previous Context

Shows how `%previous` short conversations work, and that unmatched replies
no longer wipe that context.

When no trigger matches, RiveScript returns `ERR: No Reply Matched`. Older
interpreters always pushed that string into `history.reply[0]`, so the next
turn could no longer match `% how many arms do i have`. This port keeps the
previous bot reply in history for those error turns
([rivescript-js#411](https://github.com/aichaos/rivescript-js/issues/411)).

## Usage

```bash
$ cd eg/previous
$ ruby bot.rb
```

## Example

```
> explain previous
Bot> %previous matches the bot's last reply.
...
> ask me a question
Bot> How many arms do I have?
> lol
Bot> That isn't a number.
> ask me a question
Bot> How many arms do I have?
> xyzzy nonsense
Bot> That isn't a number.
> ask me a question
Bot> How many arms do I have?
> 2
Bot> Yes!
```

To see the engine fix directly, temporarily remove the `+ *` / `% how many
arms do i have` block from `previous.rive`. Then:

```
> ask me a question
Bot> How many arms do I have?
> lol
Bot> ERR: No Reply Matched
> 2
Bot> Yes!
```

`reply[0]` is still the question after the error, so `%previous` still matches.

## Notes

* A catch-all `+ *` is still a good idea in real bots so users never see
  `ERR:` strings; it is just no longer required to keep `%previous` alive.
* `ERR: No Reply Found` is treated the same way (history reply slot unchanged).
