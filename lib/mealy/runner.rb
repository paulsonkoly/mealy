# frozen_string_literal: true

module Mealy
  # @api private
  #
  # An object on which {#run} behaves like Mealy{Mealy#execute}. The internal state
  # is tracked by this instance, the user state is in {Mealy}.
  class Executer
    # @param mealy [Mealy] mealy instance
    def initialize(mealy)
      @mealy = mealy
      @state = nil
    end

    # same as calling {Mealy#execute}
    def run(enum)
      start

      enum.each { |c| run_for_token(c) }

      finish
    end

    private

    def start
      @state, block = start_data
      user_action(block)
    end

    def run_for_token(token)
      params = lookup_transition_for(token)
      block = params[:block]
      from = @state
      to = params[:to]
      @state = to
      user_action(block, token, from, to)
    end

    def finish
      user_action(finish_data)
    end

    def lookup_transition_for(char)
      on_not_found = -> { raise UnexpectedTokenError.new(@state, char) }
      _, params = transitions[@state].find(on_not_found) do |key, _|
        key.match?(char)
      end
      params
    end

    def user_action(user_action_block, *args)
      return if user_action_block.nil?

      @mealy.instance_exec(*args, &user_action_block)
    end

    %i[start_data transitions finish_data].each do |sym|
      define_method(sym) do
        @mealy.class.instance_variable_get(:"@#{sym}")
      end
    end
  end

  # @api private
  #
  # Extends {Executer} with emitting capabilities.
  class Runner < Executer
    # emit tokens from the DSL blocks
    # @param token the emitted token
    def emit(emit)
      @emit_block.call(emit)
    end

    # same as calling {Mealy#run}
    def run(enum, &emit_block)
      @emit_block = emit_block

      super
    end
  end
end
