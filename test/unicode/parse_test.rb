# frozen_string_literal: true

require "test_helper"

class Unicode::ParseTest < Minitest::Test
  def test_version
    refute_nil ::Unicode::Parse::VERSION
  end
end
