A Mealy finite state machine.

[![Build Status](https://travis-ci.org/phaul/mealy.svg?branch=master)](https://travis-ci.org/phaul/mealy)

## Defining the machines

Define transition rules for your class, and include {Mealy} to make it a functioning state machine.

See {Mealy::DSL} for the class methods available for defining the machines.

Matching rules are chosen in the order of appearance, first match wins. {Mealy::ANY} represents a wildcard, so naturally rules with this token come last otherwise more specific rules can't match. The default token argument is
{Mealy::ANY} so it can be omitted.

### Simple example

read ones until a zero. Then return how many ones we read.

```ruby
class Counter
  include Mealy

  initial_state(:start) { @counter = 0 }

  transition(from: :start, to: :end, on: 0)

  read(state: :start, on: 1) { @counter += 1 }

  # once we are in this state we are stuck, but we still need to read the
  # rest of the input
  read(state: :end)

  finish { @counter }
end

counter = Counter.new
counter.execute([1, 1, 1, 1, 0, 1, 0, 0]) # => 4
```

### Float parser
![float FSM](https://raw.githubusercontent.com/phaul/mealy/master/doc/float.svg?sanitize=true)

```ruby
class FloatParser
  include Mealy

  initial_state(:first)

  transition(from: :first, to: :before_dot, on: '0'..'9')

  read(state: :before_dot, on: '0'..'9')

  transition(from: :before_dot, to: :after_dot, on: ?.)

  read(state: :after_dot, on: '0'..'9')

  transition(from: [ :first, :before_dot, :after_dot ], to: :error) do |c, from|
    @error = "unexpected char #{c} @ #{from.inspect}"
  end

  read(state: :error)

  finish { @error }
end

p = FloatParser.new
p.execute('1'.chars) # => nil
p.execute('1.0'.chars) # => nil
p.execute('.0'.chars) # => "unexpected char . @ :first"
p.execute('1.2.0'.chars) # => "unexpected char . @ :after_dot"
```

## Running the machine

There are two interfaces to run the machine and get results from it. {Mealy#run} and {Mealy#execute}.

{Mealy#run} can be used if one wants to {Mealy#emit} a stream of outputs as the machine is running. This can be useful for instance if we want to emit tokens from a lexer (our Mealy machine) to a parser.

{Mealy#execute} has a simpler interface. It is useful when we are just interested in a single value at the final state, let's say if something is parseable or not.

### Emitting tokens

This example shows how one can emit a stream of tokens from a Mealy machine.

```ruby
require 'mealy'

class TagParser
  include Mealy

  initial_state(:normal) { @text = '' }

  transition(from: :normal, to: :tag, on: ?<) do
    emit({text: @text}) unless @text.empty?
    @text = ''
  end

  transition(from: :tag, to: :close_tag, on: ?/)

  transition(from: [ :tag, :close_tag ], to: :normal, on: ?>) do |_, from|
    emit({from => @text}) unless @text.empty?
    @text = ''
  end

  read(state: [:normal, :tag, :close_tag]) { |c| @text << c }

  finish { emit @text unless @text.empty? }
end

p = TagParser.new
p.run('<h1>some title</h1>'.chars).entries # => [{:tag=>"h1"}, {:text=>"some title"}, {:close_tag=>"h1"}]
```

## API documentation

  - [Yard docs](https://www.rubydoc.info/github/phaul/mealy/master/Mealy)
