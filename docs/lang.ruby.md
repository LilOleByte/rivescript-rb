# RubyObjectHandler (RiveScript master)

Ruby Language Support for RiveScript Macros. This support is enabled by
default in RiveScript-rb; if you don't want it, override the `ruby`
language handler to nil, like so:

```ruby
bot.set_handler("ruby", nil)

# or:
bot = RiveScript.new(enable_object_macros: false)
```

## void load (string name, string[]|function code)

Called by the RiveScript object to load Ruby code.

## string call (RiveScript rs, string name, string[] fields[, scope])

Called by the RiveScript object to execute Ruby code.
