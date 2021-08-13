# frozen_string_literal: true

require "logger"
require "open-uri"
require "zip"

module Unicode
  module Data
    class Generate
      class PropertyValueAliases
        attr_reader :aliases

        def initialize(aliases)
          @aliases = aliases
        end

        def keys
          aliases.keys
        end

        def find(property, value)
          aliases[property].find { |alias_set| alias_set.include?(value) }
        end
      end

      attr_reader :zipfile, :outfile, :logger

      def initialize(zipfile, outfile, logger: Logger.new(STDOUT))
        @zipfile = zipfile
        @outfile = outfile
        @logger = logger
      end

      def generate
        property_aliases = read_property_aliases
        property_value_aliases = PropertyValueAliases.new(read_property_value_aliases)

        generate_general_categories
        generate_ages(property_value_aliases)
        generate_scripts(property_value_aliases)
        generate_core_properties(property_aliases, property_value_aliases)
      end

      def self.call
        unicode_version = RbConfig::CONFIG["UNICODE_VERSION"]

        URI.open("https://www.unicode.org/Public/#{unicode_version}/ucd/UCD.zip") do |file|
          Zip::File.open_buffer(file) do |zipfile|
            File.open(File.join(__dir__, "derived.txt"), "w") do |outfile|
              new(zipfile, outfile).generate
            end
          end
        end
      end

      private

      def each_line(filepath)
        zipfile.get_input_stream(filepath).each_line do |line|
          line.tap(&:chomp!).gsub!(/\s*#.*$/, "")
          yield line unless line.empty?
        end
      end

      def read_property_aliases
        [].tap do |aliases|
          each_line("PropertyAliases.txt") do |line|
            aliases << line.split(/\s*;\s*/).uniq
          end
        end
      end

      def read_property_value_aliases
        {}.tap do |aliases|
          each_line("PropertyValueAliases.txt") do |line|
            type, *values = line.split(/\s*;\s*/)
            (aliases[type] ||= []) << values
          end
        end
      end

      GeneralCategory = Struct.new(:name, :abbrev, :aliased, :subsets, keyword_init: true)

      # https://www.unicode.org/reports/tr44/#General_Category_Values
      def generate_general_categories
        properties = {}

        zipfile.get_input_stream("PropertyValueAliases.txt").each_line do |line|
          if line.start_with?("# General_Category") .. line.start_with?("# @missing")
            match = /^gc ; (?<abbrev>[^\s]+)\s+; (?<name>[^\s]+)\s+(?:; (?<aliased>[^\s]+)\s+)?(?:\# (?<subsets>[^\s]+))?/.match(line)
            next if match.nil?
  
            properties[match[:abbrev]] =
              GeneralCategory.new(
                name: match[:name],
                abbrev: match[:abbrev],
                aliased: match[:aliased],
                subsets: match[:subsets]&.split(" | ")
              )
          end
        end
  
        general_categories = read_property_codepoints("extracted/DerivedGeneralCategory.txt")
        general_categories.each do |abbrev, codepoints|
          general_category = properties[abbrev]

          queries = [abbrev, general_category.name]
          queries << general_category.aliased if general_category.aliased
          queries.map! { |value| "General_Category=#{value}" }

          if general_category.subsets
            codepoints =
              general_category.subsets.flat_map do |subset|
                general_categories[subset]
              end
          end

          write_queries(queries, codepoints)
        end
      end

      # https://www.unicode.org/reports/tr44/#Character_Age
      def generate_ages(property_value_aliases)
        ages = read_property_codepoints("DerivedAge.txt").to_a
        ages.each_with_index do |(version, _values), index|
          # When querying by age, something that was added in 1.1 will also
          # match at \p{age=2.0} query, so we need to get every value from all
          # of the preceeding ages as well.
          write_queries(
            property_value_aliases.find("age", version).map { |value| "Age=#{value}" },
            ages[0..index].flat_map(&:last)
          )
        end
      end

      # https://www.unicode.org/reports/tr24/
      def generate_scripts(property_value_aliases)
        read_property_codepoints("Scripts.txt").each do |script, codepoints|
          write_queries(
            property_value_aliases.find("sc", script).map { |value| "Script=#{value}" },
            codepoints
          )
        end
      end

      def generate_core_properties(property_aliases, property_value_aliases)
        read_property_codepoints("DerivedCoreProperties.txt").each do |property, codepoints|
          property_alias_set =
            property_aliases.find { |alias_set| alias_set.include?(property) }

          property_value_alias_key =
            (property_alias_set & property_value_aliases.keys).first

          queries =
            property_value_aliases.find(property_value_alias_key, "True")
              .map { |value| "#{property}=#{value}" }

          write_queries(queries, codepoints)
        end
      end

      def read_property_codepoints(filepath)
        {}.tap do |properties|
          each_line(filepath) do |line|
            codepoint, property = line.split(/\s*;\s*/)
            codepoint =
              if codepoint.include?("..")
                left, right = codepoint.split("..").map { |value| value.to_i(16) }
                left..right
              else
                codepoint.to_i(16)
              end

            (properties[property] ||= []) << codepoint
          end
        end
      end

      def write_queries(queries, codepoints)
        serialized =
          codepoints
            .flat_map { |codepoint| [*codepoint] }
            .sort
            .chunk_while { |prev, curr| curr - prev == 1 }
            .map { |chunk| chunk.length > 1 ? "#{chunk[0]}..#{chunk[-1]}" : chunk[0] }
            .join(",")

        queries.each do |query|
          logger.info("Generating #{query}")
          outfile.puts("%-80s %s" % [query, serialized])
        end
      end
    end
  end
end
