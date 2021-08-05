# frozen_string_literal: true

require "logger"
require "open-uri"
require "zip"

module Unicode
  module Data
    class Generate
      attr_reader :zipfile, :outfile, :logger

      def initialize(zipfile, outfile, logger: Logger.new(STDOUT))
        @zipfile = zipfile
        @outfile = outfile
        @logger = logger
      end

      def generate
        generate_general_categories
        generate_ages
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

      GeneralCategory = Struct.new(:name, :abbrev, :aliased, :subsets, :values, keyword_init: true)

      # https://www.unicode.org/reports/tr44/#General_Category_Values
      def generate_general_categories
        general_categories = {} # abbrev => GeneralCategory

        # Get all of the general category metadata
        zipfile.get_input_stream("PropertyValueAliases.txt").each_line do |line|
          if line.start_with?("# General_Category") .. line.start_with?("# @missing")
            match = /^gc ; (?<abbrev>[^\s]+)\s+; (?<name>[^\s]+)\s+(?:; (?<aliased>[^\s]+)\s+)?(?:\# (?<subsets>[^\s]+))?/.match(line)
            next if match.nil?
  
            general_categories[match[:abbrev]] =
              GeneralCategory.new(
                name: match[:name],
                abbrev: match[:abbrev],
                aliased: match[:aliased],
                subsets: match[:subsets]&.split(" | "),
                values: []
              )
          end
        end
  
        # Get all of the character to general category mappings
        zipfile.get_input_stream("extracted/DerivedGeneralCategory.txt").each_line do |line|
          match = line.match(/\A(?<start>\h+)(?:\.\.(?<finish>\h+))?\s+; (?<category>\w+) \#/)
          next unless match
  
          value = match[:start].to_i(16)
          value = (value..match[:finish].to_i(16)) if match[:finish]
  
          general_categories[match[:category]].values << value
        end

        # Write out each general category to its own file
        general_categories.each do |abbrev, general_category|
          queries = [abbrev, general_category.name]
          queries << general_category.aliased if general_category.aliased

          queries.each do |query|
            logger.info("Generating #{query}")

            # Get all of the values that are contained within this general
            # category
            values =
              if general_category.subsets
                general_category.subsets.flat_map do |subset|
                  general_categories[subset].values
                end
              else
                general_category.values
              end
    
            # Make sure we flatten out any ranges
            values
              .flat_map { |value| [*value] }
              .chunk_while { |prev, curr| curr - prev == 1 }
              .map { |chunk| chunk.length > 1 ? "#{chunk[0]}..#{chunk[-1]}" : chunk[0] }
              .then { |mapped| outfile.puts("#{query} #{mapped.join(",")}") }
          end
        end
      end

      Age = Struct.new(:version, :values, keyword_init: true)

      # https://www.unicode.org/reports/tr44/#Character_Age
      def generate_ages
        ages = {} # version => Age

        # Get all of the age metadata
        zipfile.get_input_stream("PropertyValueAliases.txt").each_line do |line|
          if line.start_with?("# Age") .. line.match?(/\n\n\#/m)
            match = /^age; (?<version>\d+\.\d+)\s+/.match(line)
            next if match.nil?
  
            age = Age.new(version: match[:version], values: [])
            ages[age.version] = age
          end
        end
  
        # Get all of the character to age mappings
        zipfile.get_input_stream("DerivedAge.txt").each_line do |line|
          match = line.match(/\A(?<start>\h+)(?:\.\.(?<finish>\h+))?\s+; (?<version>\d+\.\d)+/)
          next unless match
  
          value = match[:start].to_i(16)
          value = (value..match[:finish].to_i(16)) if match[:finish]
  
          ages[match[:version]].values << value
        end

        # Write out each age to its own file
        ages = ages.to_a
        ages.each_with_index do |(version, age), index|
          query = "age=#{version}"
          logger.info("Generating #{query}")

          # When querying by age, something that was added in 1.1 will also
          # match at \p{age=2.0} query, so we need to get every value from all
          # of the preceeding ages as well.
          values =
            ages[0..index]
              .flat_map do |(_version, age)|
                age.values.flat_map { |value| [*value] }
              end
              .sort
  
          # Write it out to a file that will be used later for matching.
          values
            .chunk_while { |prev, curr| curr - prev == 1 }
            .map { |chunk| chunk.length > 1 ? "#{chunk[0]}..#{chunk[-1]}" : chunk[0] }
            .then { |mapped| outfile.puts("#{query} #{mapped.join(",")}") }
        end
      end
    end
  end
end
