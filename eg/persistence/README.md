# User Data Persistence Example

This example demonstrates a way to persist user variables across sessions of
a chatbot, so that the bot may be shut down and restarted and it can still
remember where it left off with each user — keeping track of user variables
such as their name, as well as the recent history of inputs and replies.

In this example, the bot asks you for a username when it starts up. After each
reply, the user's variables are exported to a JSON file named after the
username (example: `soandso.json`).

## Usage

```bash
$ cd eg/persistence
$ ruby bot.rb
```

## Example Output

```
$ ruby bot.rb
Enter your username [default: soandso]: kirsle
Hello kirsle
Type /quit to quit.

> Hello bot
Bot> How do you do. Please state your problem.
> My name is Noah
Bot> Noah, nice to meet you.
> /quit

$ ruby bot.rb
Enter your username [default: soandso]: kirsle
Hello kirsle
Type /quit to quit.

> What is my name?
Bot> Your name is Noah.
> /quit
```

After running the bot, check the current working directory for a JSON file
named after your username.
