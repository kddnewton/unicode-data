# frozen_string_literal: true

require "unicode/data/version"

module Unicode
  module Data
    def self.generate
      require "unicode/data/generate"
      Generate.call
    end

    def self.validate
      require "unicode/data/validate"
      Validate.call
    end
  end
end
