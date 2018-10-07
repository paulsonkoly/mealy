require_relative 'mealy/dsl'
require_relative 'mealy/label'
require_relative 'mealy/runner'

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

  # emit tokens from the DSL blocks
  # @param token the emitted token
  def emit(token)
    return unless @emit_runner
    @emit_runner.emit(token)
  end

  # Runs the Mealy machine on the given input. Outputs a stream of tokens by
  # yielding each emitted token to the given block.
  # @param enum [Enumerable] the input for the FSM
  # @return [Enumerator] if no block is given
  def run(enum, &block)
    return to_enum(:run, enum) unless block_given?

    @emit_runner = Runner.new(self)
    @emit_runner.run(enum, &block)
    @emit_runner = nil
  end

  # Runs the Mealy machine on the given input.
  # @param enum [Enumerable] the input for the FSM
  # @return the return value of the {Mealy::DSL#finish} block.
  def execute(enum)
    Executer.new(self).run(enum)
  end
end
