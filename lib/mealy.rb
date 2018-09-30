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
  class AlreadyEmmitedError < StandardError; end

  # emit tokens from the DSL blocks
  def emit(token)
    raise AlreadyEmittedError if @has_emit

    @has_emit = true
    @emit = token
  end

  # yields each emitted token in turn
  # @param enum [Enumerable] the input for the FSM
  # @return Enumerator if no block is given
  def run_mealy(enum)
    return to_enum(:run_mealy, enum) unless block_given?

    begin_tokenization
    enum.each { |c| tokenize_token(c) { |token| yield(token) } }
    finish_tokenization { |token| yield(token) }
  end

  private

  %i[init transitions finish].each do |sym|
    define_method(sym) do
      self.class.instance_variable_get(:"@#{sym}")
    end
  end

  def begin_tokenization
    @state, block = init
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

  def lookup_transition_for(char)
    on_not_found = -> { raise UnexpectedTokenError.new(state, char) }
    _, params = transitions[@state].find(on_not_found) do |key, _|
      key.match?(char)
    end
    params
  end

  def move_state(to)
    yield(@state, to)
    @state = to
  end

  def user_action(block, *args)
    @has_emit = false
    return if block.nil?

    instance_exec(*args, &block)
    yield(@emit) if @has_emit
  end
end
