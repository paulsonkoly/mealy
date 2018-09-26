A Mealy finite state machine.

Define transition rules for your class, and include Mealy::DSL to make it a
functioning state machine. The output can be emitted from the user code, each
emit is yielded to the block of `DSL#run_mealy`.

Example
=======

read ones until a zero. Then emit how many ones we read.

```ruby
class Counter
  include Mealy::DSL

  initial_state(:start) { @counter = 0 }

  transition(from: :start, to: :end, on: 0)

  read(state: :start, on: 1) { @counter += 1 }

  # once we are in this state we are stuck, but we still need to read the
  # rest of the input
  read(state: :end)

  finish { emit(@counter) }
end

counter = Counter.new
counter.run_mealy([1,1,1,1,0,1,0,0]).first # => 4
```

### Float parser

This example could be simplified with regexps, but we demonstrate how to
parse floats with single character based rules. One could also use regexps to
match tokens in their FSM rules.

![float FSM](http://github.com/phaul/mealy/raw/master/doc/float.svg&sanitize=true)

```ruby
class FloatParser
  include Mealy::DSL

  initial_state(:first)

  10.times { |ix| transition(from: :first, to: :before_dot, on: ix.to_s ) }

  10.times { |ix| read(state: :before_dot, on: ix.to_s) }

  transition(from: :before_dot, to: :after_dot, on: ?.)

  10.times { |ix| read(state: :after_dot, on: ix.to_s) }

  transition(from: [ :first, :before_dot, :after_dot ], to: :error) do |c, from|
    @error = "unexpected char #{c} @ #{from.inspect}"
  end

  read(state: :error)

  attr_reader :error
end

p = FloatParser.new
p.run_mealy('1'.chars) {}
p.error # => nil
p.run_mealy('1.0'.chars) {}
p.error # => nil
p.run_mealy('.0'.chars) {}
p.error # => "unexpected char . @ :first"
p.run_mealy('1.2.0'.chars) {}
p.error # => "unexpected char . @ :after_dot"
```
