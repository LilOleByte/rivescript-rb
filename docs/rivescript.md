# Notice to Developers

The methods prefixed with the word "private" *should not be used* by you. They
are documented here to help the RiveScript library developers understand the
code; they are not considered 'stable' API functions and they may change or
be removed at any time, for any reason, and with no advance notice.

The most commonly used private function I've seen developers use is the
`parse()` function, when they want to load RiveScript code from a string
instead of a file. **Do not use this function.** The public API equivalent
function is `stream()`. The parse function will probably be removed in the
near future.

# RiveScript (hash options)

Create a new RiveScript interpreter. `options` is a Hash with the
following keys:

* bool debug:     Debug mode               (default false)
* int  depth:     Recursion depth limit    (default 50)
* bool strict:    Strict mode              (default true)
* bool utf8:      Enable UTF-8 mode        (default false, see below)
* bool force_case: Force-lowercase triggers (default false, see below)
* proc on_debug:  Set a custom handler to catch debug log messages (default nil)
* hash errors:    Customize certain error messages (see below)
* str  concat:    Globally replace the default concatenation mode when parsing
                  RiveScript source files (default `nil`. be careful when
                  setting this option if using somebody else's RiveScript
                  personality; see below)
* session_manager: provide a custom session manager to store user variables.
                  The default is to store variables in memory, but you may
                  use any data store by providing an implementation of
                  RiveScript's SessionManager. See the
                  [sessions](./sessions.md) documentation.
* bool case_sensitive:
                  The user's message will not be lowercased when processed
                  by the bot; so their original capitalization will be
                  preserved when repeated back in <star> tags.
* regexp unicode_punctuation:
                  You may provide a custom regexp for what you define to be
                  punctuation characters to be stripped from the user's
                  message in UTF-8 mode.
* bool enable_object_macros:
                  Register the default Ruby object macro handler
                  (default true). Set to `false` to disable executing Ruby
                  object macros defined in RiveScript source.

## UTF-8 Mode

In UTF-8 mode, most characters in a user's message are left intact, except for
certain metacharacters like backslashes and common punctuation characters like
`/[.,!?;:]/`.

If you want to override the punctuation regexp, you can provide a new one by
assigning the `unicode_punctuation` attribute of the bot object after
initialization. Example:

```ruby
bot = RiveScript.new(utf8: true)
bot.unicode_punctuation = /[.,!?;:]/
```

## Force Case

This option to the constructor will make RiveScript lowercase all the triggers
it sees during parse time. This may ease the pain point that authors
experience when they need to write a lowercase "i" in triggers, for example
a trigger of `i am *`, where the lowercase `i` feels unnatural to type.

By default a capital ASCII letter in a trigger would raise a parse error.
Setting the `force_case` option to `true` will instead silently lowercase the
trigger and thus avoid the error.

Do note, however, that this can have side effects with certain Unicode symbols
in triggers, see [case folding in Unicode](https://www.w3.org/International/wiki/Case_folding).
If you need to support Unicode symbols in triggers this may cause problems with
certain symbols when made lowercase.

## Global Concat Mode

The concat (short for concatenation) mode controls how RiveScript joins two
lines of code together when a `^Continue` command is used in a source file.
By default, RiveScript simply joins them together with no symbols inserted in
between ("none"); the other options are "newline" which joins them with line
breaks, or "space" which joins them with a single space character.

RiveScript source files can define a *local, file-scoped* setting for this
by using e.g. `! local concat = newline`, which affects how the continuations
are joined in the lines that follow.

Be careful when changing the global concat setting if you're using a RiveScript
personality written by somebody else; if they were relying on the default
concat behavior (didn't specify a `! local concat` option), then changing the
global default will potentially cause formatting issues or trigger matching
issues when using that personality.

I strongly recommend that you **do not** use this option if you intend to ever
share your RiveScript personality with others; instead, explicitly spell out
the local concat mode in each source file. It might sound like it will save
you a lot of typing by not having to copy and paste a `! local concat` option,
but it will likely lead to misbehavior in your RiveScript personality when you
give it to somebody else to use in their bot.

## Custom Error Messages

You can provide any or all of the following properties in the `errors`
argument to the constructor to override certain internal error messages:

* `replyNotMatched`: The message returned when the user's message does not
match any triggers in your RiveScript code.

The default is "ERR: No Reply Matched"

**Note:** the recommended way to handle this case is to provide a trigger of
simply `*`, which serves as the catch-all trigger and is the default one
that will match if nothing else matches the user's message. Example:

```
+ *
- I don't know what to say to that!
```
* `replyNotFound`: This message is returned when the user *did* in fact match
a trigger, but no response was found for the user. For example, if a trigger
only checks a set of conditions that are all false and provides no "normal"
reply, this error message is given to the user instead.

The default is "ERR: No Reply Found"

**Note:** the recommended way to handle this case is to provide at least one
normal reply (with the `-` command) to every trigger to cover the cases
where none of the conditions are true. Example:

```
+ hello
* <get name> != undefined => Hello there, <get name>.
- Hi there.
```
* `objectNotFound`: This message is inserted into the bot's reply in-line when
it attempts to call an object macro which does not exist (for example, its
name was invalid or it was written in a programming language that the bot
couldn't parse, or that it had compile errors).

The default is "[ERR: Object Not Found]"
* `deepRecursion`: This message is inserted when the bot encounters a deep
recursion situation, for example when a reply redirects to a trigger which
redirects back to the first trigger, creating an infinite loop.

The default is "ERR: Deep Recursion Detected"

These custom error messages can be provided during the construction of the
RiveScript object, or set afterwards on the object's `errors` property.

Examples:

```ruby
bot = RiveScript.new(
  errors: {
    "replyNotFound" => "I don't know how to reply to that."
  }
)

bot.errors["objectNotFound"] = "Something went terribly wrong."
```

## string version ()

Returns the version number of the RiveScript Ruby library.

## private string runtime ()

Detect the runtime environment of this module. In the Ruby port this
returns `"ruby"`.

## private void say (string message)

This is the debug function. If debug mode is enabled, the 'message' will be
sent to standard output via `puts`, or to your `on_debug` handler if you
defined one.

## private void warn (string message[, filename, lineno])

Print a warning or error message. This is like debug, except it's GOING to
be given to the user one way or another. If the `on_debug` handler is
defined, this is sent there. Otherwise it is printed with `puts`.

## bool load_file(string path || array path)

Load a RiveScript document from a file. The path can either be a string that
contains the path to a single file, or an array of paths to load multiple
files. This method is synchronous: it reads and parses each file immediately
and returns when finished. Raises on error.

## bool load_directory (string path)

Load RiveScript documents from a directory recursively.

This function loads `*.rive` and `*.rs` files under `path`.

## bool stream (string code[, func onError])

Load RiveScript source code from a string. `code` should be the raw
RiveScript source code, with line breaks separating each line.

This function is synchronous. It parses the code immediately and returns.
Do not fear: the parser runs very quickly.

Returns `true` if the code parsed with no error.

onError function receives: `(err string[, filename str, line_no int])`

## private bool parse (string name, string code[, func onError(string)])

Parse RiveScript code and load it into memory. `name` is a file name in case
syntax errors need to be pointed out. `code` is the source code.

Returns `true` if the code parsed with no error.

## void sort_replies()

After you have finished loading your RiveScript code, call this method to
populate the various sort buffers. This is absolutely necessary for reply
matching to work efficiently!

## data deparse()

Translate the in-memory representation of the loaded RiveScript documents
into a Hash data structure. This may be useful for developing
a user interface to edit RiveScript replies without having to edit the
RiveScript code manually, in conjunction with the `write()` method.

The format of the deparsed data structure is out of scope for this document,
but there is additional information and examples available in the `eg/`
directory of the [rivescript-js](https://github.com/aichaos/rivescript-js/tree/master/eg/deparse)
source distribution. The Ruby port uses the same structure.

## string stringify([data deparsed])

Translate the in-memory representation of the RiveScript brain back into
RiveScript source code. This is like `write()`, but it returns the text of
the source code as a string instead of writing it to a file.

You can optionally pass the parameter `deparsed`, which should be a data
structure of the same format that the `deparse()` method returns. If not
provided, the current internal data is used (this function calls `deparse()`
itself and uses that).

Warning: the output of this function won't be pretty. For example, no word
wrapping will be done for your longer replies. The only guarantee is that
what comes out of this function is valid RiveScript code that can be loaded
back in later.

## void write (string filename[, data deparsed])

Write the in-memory RiveScript data into a RiveScript text file. This
method requires filesystem access.

This calls the `stringify()` method and writes the output into the filename
specified. You can provide your own deparse-compatible data structure,
or else the current state of the bot's brain is used instead.

## void set_handler(string lang, object)

Set a custom language handler for RiveScript object macros. See the source
for the built-in Ruby handler (`lib/rivescript/lang/ruby.rb`) as an
example.

By default, Ruby object macros are enabled. If you want to disable
these (e.g. for security purposes when loading untrusted third-party code),
just set the Ruby handler to nil (or construct with
`enable_object_macros: false`):

```ruby
bot = RiveScript.new
bot.set_handler("ruby", nil)

# or:
bot = RiveScript.new(enable_object_macros: false)
```

## void set_subroutine(string name, function)

Define a Ruby object macro from your program.

This is equivalent to having a Ruby object defined in the RiveScript code,
except your Ruby code is defining it instead.

## void set_global (string name, string value)

Set a global variable. This is equivalent to `! global` in RiveScript.
Omit the value (or pass `:__unset__`) to delete a global.

## void set_variable (string name, string value)

Set a bot variable. This is equivalent to `! var` in RiveScript.
Omit the value (or pass `:__unset__`) to delete a bot variable.

## void set_substitution (string name, string value)

Set a substitution. This is equivalent to `! sub` in RiveScript.
Omit the value (or pass `:__unset__`) to delete a substitution.

## void set_person (string name, string value)

Set a person substitution. This is equivalent to `! person` in RiveScript.
Omit the value (or pass `:__unset__`) to delete a person substitution.

## void set_uservar (string user, string name, string value)

Set a user variable for a user.

## void set_uservars (string user, object data)

Set multiple user variables by providing a Hash of key/value pairs.
Equivalent to calling `set_uservar()` for each pair in the Hash.

## string get_variable (string name)

Gets a variable. This is equivalent to `<bot name>` in RiveScript.

## string get_uservar (string user, string name) -> value

Get a variable from a user. Returns the string "undefined" if it isn't
defined.

## object get_uservars ([string user]) -> object

Get all variables about a user. If no user is provided, returns all data
about all users.

## void clear_uservars ([string user])

Clear all a user's variables. If no user is provided, clears all variables
for all users.

## void freeze_uservars (string user)

Freeze the variable state of a user. This will clone and preserve the user's
entire variable state, so that it can be restored later with
`thaw_uservars()`

## void thaw_uservars (string user[, string action])

Thaw a user's frozen variables. The action can be one of the following:
* discard: Don't restore the variables, just delete the frozen copy.
* keep: Keep the frozen copy after restoring
* thaw: Restore the variables and delete the frozen copy (default)

## string last_match (string user) -> string

Retrieve the trigger that the user matched most recently.

## string initial_match (string user) -> string

Retrieve the trigger that the user matched initially. This will return
only the first matched trigger and will not include subsequent redirects.

This value is reset on each `reply()` call.

## object last_triggers (string user) -> object

Retrieve the triggers that have been matched for the last reply. This
will contain all matched trigger with every subsequent redirects.

This value is reset on each `reply()` or `reply_async()` call.

## object get_user_topic_triggers (string username) -> object

Retrieve the triggers in the current topic for the specified user. It can
be used to create a UI that gives the user options based on trigges, e.g.
using buttons, select boxes and other UI resources. This also includes the
triggers available in any topics inherited or included by the user's current
topic.

This will return `nil` if the user cant be find

## string current_user ()

Retrieve the current user's ID. This is most useful within a Ruby
object macro to get the ID of the user who invoked the macro (e.g. to
get/set user variables for them).

This will return nil if called from outside of a reply context
(the value is unset at the end of the `reply()` method)

## string reply (string username, string message[, scope])

Fetch a reply from the RiveScript brain. The message doesn't require any
special pre-processing to be done to it, i.e. it's allowed to contain
punctuation and weird symbols. The username is arbitrary and is used to
uniquely identify the user, in the case that you may have multiple
distinct users chatting with your bot.

This function returns a String. Object macros and session managers in the
Ruby port are synchronous.

The optional `scope` parameter will be passed down into any Ruby
object macros that the RiveScript code executes. If you pass an object
as the scope parameter, then `self` in the context of an
object macro will refer to that object (via `instance_exec`),
so for example the object macro will have access to any local methods
or attributes that your code has access to, from the location that `reply()`
was called. For an example of this, refer to the `eg/scope` directory in
the source distribution of RiveScript-rb.

Example:

```ruby
reply = bot.reply(username, message)
puts "Bot> #{reply}"

# With scope for object macros:
reply = bot.reply(username, message, self)
puts "Bot> #{reply}"
```

## string reply_async (string username, string message [[, scope], block])

**Obsolete** -- use `reply()` instead in new code.

Compatibility shim around `reply()`. If a block is given, yields
`(nil, reply)`. Returns the reply string.
