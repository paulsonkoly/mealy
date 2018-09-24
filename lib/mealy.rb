# A Mealy finite state machine. Define transition rules for your class, and
# include Mealy::DSL to make it a functioning state machine. The output can be
# emitted from the user code, each emit is yielded to the block of
# {DSL#run_mealy}.
#
# == Example
#
# read ones until a zero. Then emit how many ones we read.
#
#
#     class Counter
#       include Mealy::DSL
#
#       initial_state(:start) { @counter = 0 }
#
#       transition(from: :start, to: :end, on: 0)
#
#       read(state: :start, on: 1) { @counter += 1 }
#
#       # once we are in this state we are stuck, but we still need to read the
#       # rest of the input
#       read(state: :end)
#
#       finish { emit(@counter) }
#     end
#
#     counter = Counter.new
#     counter.run_mealy([1,1,1,1,0,1,0,0]).first # => 4
#
# @note states can be represented with any type not just Symbols
module Mealy
  UnexpectedTokenError = Class.new(StandardError)
  AlreadyEmitted = Class.new(StandardError)

  # The class level DSL for defining machines.
  module DSL
    # Wildcard for machine input tokens that match anything.
    Any = :any

    module ClassMethods
      # Declares the initial state of the lexer FSM.
      # @param sym [Symbol] the initial state
      # @param block user code executed in the instance of the lexer on
      #              start up
      def initial_state(sym, &block)
        @init = [sym, block]
      end

      # An FSM transition.
      # @param from [Array|Symbol] the state or Array of states we transition
      #             away from
      # @param to [Symbol] the state we transition to
      # @param on [token|Any] only allows this rule to trigger if the read
      #           token matches
      # @param block user code executed when the rule fires. The read input,
      #              and the from and to states are passed to the block
      def transition(from:, to:, on: Any, &block)
        hash = { on => { to: to, block: block } }
        [* from].each do |origin|
          @transitions[origin] = @transitions[origin].merge(hash)
        end
      end

      # An FSM loop
      # @param state [Array|Symbol] the state or states we loop on
      # @param on [token|Any] loop while this matches the read token
      # @param block user code executed on each iteration of the loop
      def read(state:, on: Any, &block)
        [* state].each do |one_state|
          transition(from: one_state, to: one_state, on: on, &block)
        end
      end

      # final FSM state
      # @param block fires on FSM shutdown
      def finish(&block)
        @finish = block
      end
    end

    def self.included(klass)
      klass.class_eval { @transitions = Hash.new { Hash.new({}) } }
      klass.extend(ClassMethods)
    end

    # emit tokens from the DSL blocks
    def emit(token)
      raise AlreadyEmitted unless @emit.nil?

      @emit = token
    end

    # yields each emitted token in turn
    # @param enum the input for the lexer
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
      new, params = transitions[@state].find do |k, _|
        k == Any || k === char
      end
      previous = @state
      @state = params[:to]
      block = params[:block]
      raise UnexpectedCharError if new.nil?

      user_action(block, char, previous, @state) { |token| yield(token) }
    end

    def finish_tokenization
      user_action(finish) { |token| yield(token) }
    end

    def user_action(block, *args)
      @emit = nil
      return if block.nil?

      instance_exec(*args, &block)
      yield(@emit) unless @emit.nil?
    end
  end
end

