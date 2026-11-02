# frozen_string_literal: true

require 'adwaita'

module Errands
  # Markup prepares task text for Pango markup labels.
  #
  # Ported from upstream's errands/lib/markup.py. Upstream escapes with
  # GLib.markup_escape_text; the Ruby bindings don't expose that function, so
  # the same five entities are substituted here.
  #
  module Markup
    ENTITIES = {
      '&' => '&amp;',
      '<' => '&lt;',
      '>' => '&gt;',
      '"' => '&quot;',
      "'" => '&apos;',
    }.freeze

    URL_PATTERN = %r{(https?://\S+)}

    class << self
      def escape(text) = text.to_s.gsub(/[&<>"']/, ENTITIES)

      # Turns urls into links. Escape the text before calling, exactly as
      # upstream's docstring says.
      def find_url(text)
        text.to_s.gsub(URL_PATTERN) { |url| "<a href=\"#{url}\">#{url}</a>" }
      end
    end
  end
end
