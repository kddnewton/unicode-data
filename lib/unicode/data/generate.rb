# frozen_string_literal: true

require "fileutils"
require "logger"
require "open-uri"
require "zip"

module Unicode
  module Data
    class Generate
      attr_reader :target, :zipfile, :logger

      def initialize(target, zipfile, logger: Logger.new(STDOUT))
        @target = target
        @zipfile = zipfile
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
            new(File.expand_path("derived", __dir__), zipfile).generate
          end
        end
      end

      private

      GeneralCategory = Struct.new(:name, :abbrev, :aliased, :subsets, :values, keyword_init: true)

      # https://www.unicode.org/reports/tr44/#General_Category_Values
      def generate_general_categories
        FileUtils.mkdir_p(File.join(target, "general_categories"))
        general_categories = {} # abbrev => GeneralCategory

        # Get all of the general category metadata
        zipfile.get_input_stream("PropertyValueAliases.txt").each_line do |line|
          if line.start_with?("# General_Category") .. line.start_with?("# @missing")
            match = /^gc ; (?<abbrev>[^\s]+)\s+; (?<name>[^\s]+)\s+(?:; (?<aliased>[^\s]+)\s+)?(?:\# (?<subsets>[^\s]+)\s+)?$/.match(line)
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
          # Write it out to a file that will be used later for matching.
          filename = "#{abbrev}-#{general_category.name}"
          filename = "#{filename}-#{general_category.aliased}" if general_category.aliased

          filepath = "#{target}/general_categories/#{filename}.txt"
          logger.info("Generating #{filepath}")

          # Get all of the values that are contained within this general
          # category
          values =
            if general_category.subsets
              general_category.subsets.flat_map { |subset| general_categories[subset].values }
            else
              general_category.values
            end
  
          # Make sure we flatten out any ranges
          values = values.flat_map { |value| [*value] }
  
          File.open(filepath, "w") do |file|
            values
              .chunk_while { |prev, curr| curr - prev == 1 }
              .each do |chunk|
                file.puts(chunk.length > 1 ? "#{chunk[0]}..#{chunk[-1]}" : chunk[0])
              end
          end
        end
      end

      Age = Struct.new(:version, :values, keyword_init: true)

      # https://www.unicode.org/reports/tr44/#Character_Age
      def generate_ages
        FileUtils.mkdir_p(File.join(target, "ages"))
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
          filepath = "#{target}/ages/#{version}.txt"
          logger.info("Generating #{filepath}")

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
          File.open(filepath, "w") do |file|
            values
              .chunk_while { |prev, curr| curr - prev == 1 }
              .each do |chunk|
                file.puts(chunk.length > 1 ? "#{chunk[0]}..#{chunk[-1]}" : chunk[0])
              end
          end
        end
      end
    end
  end
end
