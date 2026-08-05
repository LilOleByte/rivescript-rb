# Miscellaneous utility functions.

## string strip (string)

Strip extra whitespace from both ends of the string, and remove
line breaks anywhere in the string.

## string trim (string)

Compatible implementation of `String#strip`. Strips whitespace
from the beginning and end of the string, but doesn't remove any
whitespace inside the string like `strip()` does.

## void extend (object a, object b)

Combine the properties of both objects into one. The properties from
object 'b' are inserted into 'a'.

## int word_count (string)

Count the number of real words in a string.

## string strip_nasties (string, bool utf8)

Stip special characters out of a string.

## string quotemeta (string)

Escape a string for a regexp.

## bool is_atomic (string trigger)

Determine whether a trigger is atomic.

## string string_format (string type, string)

Formats a string according to one of the following types:
- formal
- sentence
- uppercase
- lowercase

## []string parse_call_args

Parse a string and return shell-like arguments as an array. Normally this
means each word in the string becomes an item in the result, but quoted
sections of the input will come back as a single item.

Example:

```ruby
puts Utils.parse_call_args('please google "writing chat bot"').inspect
# ["please", "google", "writing chat bot"]
```

## object clone (object)

Clone an object.

## int n_index_of (string, string match, int index)

Finds a match in a string at a given index

Usage:
string = "My name is Rive"
match = " "
index = 2
return = 7

Summary: It will look for a second space in the string
