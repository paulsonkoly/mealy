# frozen_string_literal: true

require_relative 'label'

module Mealy
  # Various helper methods
  module HelperMethods
    # Converts types to Labels. {Mealy::DSL#transition} calls this to convert
    # anything to a {Label}.
    # @return [Label]
    def self.Label(convertee)
      if convertee.kind_of?(Label) then convertee
      else Label.new(convertee)
      end
    end
  end
end
