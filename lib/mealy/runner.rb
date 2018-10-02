# frozen_string_literal: true

module Mealy
  # This class should not be used directly.
  #
  # An object on which {#run} behaves like #{Mealy#execute}. The internal state
  # is tracked by this instance, the user state is in {Mealy}.
  class Executer
    # @param mealy [Mealy] mealy instance
    def initialize(mealy)
      @mealy = mealy
      @state = nil
    end

    # same as calling {Mealy#execute}
    def run(enum)
      begin_tokenization
      enum.each { |c| tokenize_token(c) { |token| yield(token) } }
      finish_tokenization { |token| yield(token) }
    end

    private

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
      on_not_found = -> { raise UnexpectedTokenError.new(@state, char) }
      _, params = transitions[@state].find(on_not_found) do |key, _|
        key.match?(char)
      end
      params
    end

    def move_state(to)
      yield(@state, to)
      @state = to
    end

    def user_action(user_action_block, *args)
      return if user_action_block.nil?

      @mealy.instance_exec(*args, &user_action_block)
    end

    %i[init transitions finish].each do |sym|
      define_method(sym) do
        @mealy.class.instance_variable_get(:"@#{sym}")
      end
    end
  end

  # This class should not be used directly.
  #
  # Extends {Runner} with emitting capabilities.
  class Runner < Executer
    # add an emit to the runner
    # @param emit token
    def add_emit(emit)
      @emits << emit
    end

    private

    def user_action(user_action_block, *args)
      @emits = []
      super
      @emits.each { |emit| yield(emit) }
    end
  end
end
