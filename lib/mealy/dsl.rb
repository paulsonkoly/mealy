# frozen_string_literal: true

require_relative 'label'
require_relative 'helper_methods'

module Mealy
  # The class level DSL for defining machines.
  module DSL
    # Declares the initial state of the FSM.
    # @param sym [Symbol] the initial state
    # @param block user code executed in the instance of the FSM on start up
    def initial_state(sym, &block)
      @start_data = [sym, block]
    end

    # An FSM transition.
    # @param from [Array|Symbol] the state or Array of states we transition
    #             away from
    # @param to [Symbol] the state we transition to
    # @param on [Label] only allows this rule to trigger if the read
    #           token matches ({HelperMethods.Label} is automatically called
    #           on this)
    # @param block user code executed when the rule fires
    # @yieldparam input The read input, that matches the rules {Label}
    # @yieldparam from The state we are transitioning away from
    # @yieldparam to  The state we are transitioning to
    def transition(from:, to:, on: ANY, &block)
      hash = { HelperMethods.Label(on) => { to: to, block: block } }
      [* from].each do |origin|
        @transitions[origin] = @transitions[origin].merge(hash)
      end
    end

    # An FSM loop
    # @param state [Array|Symbol] the state or states we loop on
    # @param on [Label] only allows this rule to trigger if the read
    #           token matches ({HelperMethods.Label} is automatically called
    #           on this)
    # @param block user code executed on each iteration of the loop
    def read(state:, on: ANY, &block)
      [* state].each do |one_state|
        transition(from: one_state, to: one_state, on: on, &block)
      end
    end

    # final FSM state
    # @param block fires on FSM shutdown
    def finish(&block)
      @finish_data = block
    end
  end

  # @private
  # Module.included hook. Resets the state transitions for a class
  def self.included(klass)
    klass.class_eval { @transitions = Hash.new { Hash.new({}) } }
    klass.extend(DSL)
  end
end
