# frozen_string_literal: true

require "unicode/data/version"

module Unicode
  module Data
    class Property
      attr_reader :values

      def initialize(query)
        @values =
          case query
          when /^age=(\d+\d)$/
            load_file(File.expand_path("data/derived/ages/#{$1}.txt", __dir__))
          else
            load_file(find_candidates[query])
          end
      end

      def include?(string)
        values.include?(string.ord)
      end

      private

      def find_candidates
        Dir[File.expand_path("data/derived/general_categories/*", __dir__)].each_with_object({}) do |filepath, queries|
          File.basename(filepath, ".txt").split("-").each do |query|
            queries[query] = filepath
          end
        end
      end

      def load_file(filepath)
        File.foreach(filepath, chomp: true).flat_map do |line|
          case line
          when /^(\d+)$/
            [$1.to_i]
          when /^(\d+)..(\d+)$/
            [*($1.to_i..$2.to_i)]
          end
        end
      end
    end

    def self.generate
      require "unicode/data/generate"
      Generate.call
    end

    def self.validate
      require "unicode/data/validate"
      Validate.call
    end

    def self.property(query)
      Property.new(query)
    end
  end
end
