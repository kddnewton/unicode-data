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

    def self.properties
      @properties ||=
        File.readlines(File.expand_path("data/derived.txt", __dir__), chomp: true).to_h do |line|
          line.split(/\s+/, 2)
        end
    end

    def self.property?(query, value)
      properties[query].split(",").any? do |segment|
        case segment
        when /^(\d+)$/
          $1.to_i == value.ord
        when /^(\d+)..(\d+)$/
          ($1.to_i..$2.to_i).cover?(value.ord)
        end
      end
    end
  end
end
