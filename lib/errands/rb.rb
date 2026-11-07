# frozen_string_literal: true

require_relative 'rb/version'

# Loads without a display: today this is only the version constant.
#
# Mirrors the house split (see e.g. tally-rb's lib/tally/rb.rb) between a
# display-free require and `require "errands"`, which pulls in every widget
# and needs a display. `spec/spec_helper.rb` requires this file because the
# specs for the display-free half need nothing more; the ones that drive
# widgets require "errands" themselves.
module Errands
  module Rb
  end
end
