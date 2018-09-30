# frozen_string_literal: true

require 'singleton'

module Mealy
  # FSM state transition arrow labels. In effect we match the input tokens
  # against the labels to decide which transition to take.
  class Label
    # @param label Something that can be tested with input tokens
    def initialize(label)
      @label = label
    end

    # @param input Something that can match label
    def match?(input)
      @label === input
    end
  end

  # Singleton for a Label that matches anything. See {ANY}.
  class AnyLabel < Label
    include Singleton

    # made private as this is Singleton
    def initialize
    end

    # ignores any input and matches.
    def match?(*_)
      true
    end
  end

  # Wildcard for machine input tokens that match anything.
  ANY = AnyLabel.instance
end
