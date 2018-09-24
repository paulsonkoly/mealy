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
