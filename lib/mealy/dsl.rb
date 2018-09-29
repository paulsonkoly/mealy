module Mealy
  # The class level DSL for defining machines.
  module DSL
    # Wildcard for machine input tokens that match anything.
    ANY = :any

    module ClassMethods
      # Declares the initial state of the FSM.
      # @param sym [Symbol] the initial state
      # @param block user code executed in the instance of the FSM instance on
      #              start up
      def initial_state(sym, &block)
        @init = [sym, block]
      end

      # An FSM transition.
      # @param from [Array|Symbol] the state or Array of states we transition
      #             away from
      # @param to [Symbol] the state we transition to
      # @param on [token|ANY] only allows this rule to trigger if the read
      #           token matches
      # @param block user code executed when the rule fires. The read input,
      #              and the from and to states are passed to the block
      def transition(from:, to:, on: ANY, &block)
        hash = { on => { to: to, block: block } }
        [* from].each do |origin|
          @transitions[origin] = @transitions[origin].merge(hash)
        end
      end

      # An FSM loop
      # @param state [Array|Symbol] the state or states we loop on
      # @param on [token|ANY] loop while this matches the read token
      # @param block user code executed on each iteration of the loop
      def read(state:, on: ANY, &block)
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
      raise AlreadyEmitted if @has_emit

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
        key == ANY || key === char
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
end
