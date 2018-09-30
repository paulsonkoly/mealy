A Mealy finite state machine.

[![Build Status](https://travis-ci.com/phaul/mealy.svg?branch=master)](https://travis-ci.com/phaul/mealy)

Define transition rules for your class, and include {Mealy::DSL} to make it a functioning state machine. The output can be emitted from the user code, each emit is yielded to the block of {Mealy::DSL#run_mealy}.

Matching rules are chosen in the order of appearance, first match wins. {Mealy::ANY} represents a wildcard, so naturally rules with this token come last otherwise more specific rules can't match. The default token argument is
{Mealy::ANY} so it can be omitted.

## Examples

### Simple example

read ones until a zero. Then emit how many ones we read.

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

### Float parser

    class FloatParser
      include Mealy::DSL

      initial_state(:first)

      transition(from: :first, to: :before_dot, on: '0'..'9')

      read(state: :before_dot, on: '0'..'9')

      transition(from: :before_dot, to: :after_dot, on: ?.)

      read(state: :after_dot, on: '0'..'9')

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
