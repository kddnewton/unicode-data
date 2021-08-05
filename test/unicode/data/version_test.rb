# frozen_string_literal: true

require "test_helper"

module Unicode
  module Data
    class VersionTest < Minitest::Test
      def test_version
        refute_nil VERSION
      end
    end
  end
end
