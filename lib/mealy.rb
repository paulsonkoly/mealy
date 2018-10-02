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

  # emit tokens from the DSL blocks
  # @param token the emitted token
  def emit(token)
    __emit(token)
  end

  # Runs the Mealy machine on the given input. Outputs a stream of tokens by
  # yielding each emitted token to the given block.
  # @param enum [Enumerable] the input for the FSM
  # @return [Enumerator] if no block is given
  def run(enum, &block)
    return to_enum(:run, enum) unless block_given?

    __run(enum, :with_emits, &block)
  end

  # Runs the Mealy machine on the given input.
  # @param enum [Enumerable] the input for the FSM
  # @return the return value of the {Mealy::DSL#finish} block.
  def execute(enum)
    __run(enum, :without_emits)
  end

  -> {
    # we don't want to leak @emits, @state out to the user code, therefore we
    # made them block local variables in this lambda. In essence no instance
    # variable should appear in this code, otherwise the user blocks might
    # interfere with them
    emits = []
    state = nil
    mode = :without_emits

    private

    def __run(enum, mode)
      set_mode(mode)

      begin_tokenization
      enum.each { |c| tokenize_token(c) { |token| yield(token) } }
      finish_tokenization { |token| yield(token) }
    end

    define_method(:set_mode) { |_mode| mode = _mode }
    define_method(:__emit) { |token| emits << token }

    define_method(:begin_tokenization) do
      state, block = init
      user_action block
    end

    def tokenize_token(char)
      params = lookup_transition_for(char)
      block = params[:block]
      move_state(params[:to]) do |from, to|
        user_action(block, char, from, to) do |token|
          yield(token)
        end
      end
    end

    def finish_tokenization
      user_action(finish) { |token| yield(token) }
    end

    define_method(:lookup_transition_for) do |char|
      on_not_found = -> { raise UnexpectedTokenError.new(state, char) }
      _, params = transitions[state].find(on_not_found) do |key, _|
        key.match?(char)
      end
      params
    end

    define_method(:move_state) do |to, &block|
      block.call(state, to)
      state = to
    end

    define_method(:user_action) do |user_action_block, *args, &block|
      emits = []
      return if user_action_block.nil?

      retval = instance_exec(*args, &user_action_block)

      case mode
      when :without_emits
        retval
      when :with_emits
        emits.each { |emit| block.call(emit) }
      end
    end
  }.call
end
