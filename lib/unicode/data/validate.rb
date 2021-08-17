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
        File.foreach(File.join(__dir__, "derived.txt"), chomp: true) do |line|
          property, values = line.split(" ", 2)

          if property.start_with?("\\p{General_Category=Surrogate}")
            @surrogates = each_value(values, Mode::Full.new).to_a
            break
          end
        end
      end

      def validate
        File.foreach(File.join(__dir__, "derived.txt"), chomp: true) do |line|
          property, values = line.split(/\s+/, 2)

          # For general categories and scripts, we don't actually want the
          # prefix in the property name, so here leave it out.
          property.gsub!(/(General_Category|Script)=/, "")

          # Ruby doesn't support Block= syntax, it expects you to instead have
          # no property name and have the block name begin with In_.
          property.gsub!(/Block=/, "In_")

          # Ruby doesn't support boolean property querying with values, it only
          # supports the plain property name.
          property.gsub!(/=(Yes|Y|True|T)/, "")

          pattern =
            begin
              /#{property}/
            rescue RegexpError
              # There are a fair amount of properties that we have in this gem
              # that Ruby doesn't support natively. Things like aliases for the
              # various blocks, script extensions, aliases for the ages, etc.
              # In this case just rescue the error and move on since we can't
              # validate against native.
              logger.warn("Skipping   #{property}")
              next
            end

          logger.info("Validating #{property}")

          each_value(values, mode) do |value|
            next if surrogates.include?(value)

            unless pattern.match?([value].pack("U"))
              raise "Expected #{value} to match #{property}"
            end
          end
        end
      end

      def self.call
        new.validate
      end

      private

      def each_value(values, mode, &block)
        return enum_for(__method__, values, mode) unless block_given?

        values.split(",").each do |value|
          case value
          when /^(\d+)$/
            block.call($1.to_i)
          when /^(\d+)..(\d+)$/
            mode.apply($1.to_i..$2.to_i, &block)
          end
        end
      end
    end
  end
end
