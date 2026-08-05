# Scope Example

This example demonstrates the use of the `scope` parameter as passed to the
`reply()` function.

The `scope` changes what `self` means inside a Ruby object macro — it points
at the same host object that called `reply()`. That lets macros read and
modify instance variables and call methods on your bot wrapper.

## Usage

```bash
$ cd eg/scope
$ ruby bot.rb
```

## Example Output

```
% ruby bot.rb
> scope test
Bot> Testing the scope!
Function result: It works!
this.hello: Hello world
this.counter: 1
> scope test
Bot> Testing the scope!
Function result: It works!
this.hello: Hello world
this.counter: 2
```
