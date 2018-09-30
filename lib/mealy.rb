require_relative 'mealy/dsl'
require_relative 'mealy/label'

# A Mealy finite state machine.
#
# For usage information please read {file:README.md README}.
module Mealy
  # Error indicating that there is no transition from the current state with
  # the token read.
  class UnexpectedTokenError < StandardError
    def initialize(state, on)
      super("FSM error #{self.class} in state #{state.inspect} reading #{on}")
    end
  end

  # Error indicating that the user code calls {DSL#emit} twice.
  class AlreadyEmmited < StandardError; end
end
