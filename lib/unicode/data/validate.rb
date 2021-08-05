# frozen_string_literal: true

require "logger"

module Unicode
  module Data
    class Validate
      module Mode
        # Just test the first value in the range of characters
        class First
          def apply(values, &block)
            block.call(values.first)
          end
        end

        # Test a sample of 50 random values from the range of characters
        class Sample
          def apply(values, &block)
            values.to_a.sample(50).each(&block)
          end
        end

        # Test every value from the range of characters
        class Full
          def apply(values, &block)
            values.each(&block)
          end
        end
      end

      attr_reader :logger, :mode, :surrogates

      def initialize(logger: Logger.new(STDOUT), mode: ENV.fetch("MODE", "first"))
        @logger = logger
        @mode =
          case mode
          when "first"  then Mode::First.new
          when "sample" then Mode::Sample.new
          when "full"   then Mode::Full.new
          else
            raise ArgumentError, "invalid mode: #{mode}"
          end

        # This is a list of all of the surrogate characters that exist so that
        # we can skip them when validating since they're not valid in UTF-8.
        @surrogates =
          each_value(
            File.join(__dir__, "derived/general_categories/Surrogate.txt"),
            Mode::Full.new
          ).to_a
      end

      def validate
        validate_general_categories
        validate_ages
      end

      def self.call
        new.validate
      end

      private

      def each_value(filepath, mode, &block)
        return enum_for(__method__, filepath, mode) unless block_given?

        File.foreach(filepath, chomp: true) do |line|
          case line
          when /^(\d+)$/
            block.call($1.to_i)
          when /^(\d+)..(\d+)$/
            mode.apply($1.to_i..$2.to_i, &block)
          end
        end
      end

      def validate_each(directory, &block)
        Dir[File.join(__dir__, "derived/#{directory}/*")].each do |filepath|
          property = block.call(filepath)
          pattern = /\p{#{property}}/

          logger.info("Validating #{filepath}")

          each_value(filepath, mode) do |value|
            next if surrogates.include?(value)
            raise unless pattern.match?([value].pack("U"))
          end
        end
      end

      def validate_general_categories
        validate_each("general_categories") do |filepath|
          File.basename(filepath, ".txt")
        end
      end

      def validate_ages
        validate_each("ages") do |filepath|
          "age=#{File.basename(filepath, ".txt")}"
        end
      end
    end
  end
end
