# frozen_string_literal: true

require 'adwaita'

require_relative 'translations'

module Errands
  # Utils holds the small helpers upstream keeps as module-level functions.
  #
  # Ported from upstream's errands/lib/utils.py. `threaded` and `idle_add` are
  # Python decorators there; here they are methods taking a block, which is
  # what the same call sites need in Ruby.
  #
  module Utils
    HEX_CHARS = '0123456789ABCDEF'

    class << self
      # Formats an iCal-ish timestamp ("20240102T131500" or "20240102") the way
      # the toolbar's date button shows it. An empty value reads as "Date".
      def human_datetime(date_time)
        if date_time.to_s.empty?
          Translations.gettext('Date')
        else
          format_datetime(date_time)
        end
      end

      # The children of a widget, in order. GTK4 dropped get_children, so
      # upstream walks the sibling chain; so does this.
      def children(widget)
        [].tap do |collected|
          child = widget.first_child
          while child
            collected << child
            child = child.next_sibling
          end
        end
      end

      # Runs the block in a daemon thread. Anything touching the UI from there
      # has to come back through idle_add.
      def threaded(&block)
        Thread.new do
          block.call
        rescue StandardError => e
          Log.error("Thread: #{e.message}")
        end.tap { |thread| thread.abort_on_exception = false }
      end

      def idle_add(&block)
        GLib::Idle.add do
          block.call
          false
        end
      end

      def rgb_to_hex(red, green, blue)
        format('#%<r>02x%<g>02x%<b>02x', r: red.to_i, g: green.to_i, b: blue.to_i)
      end

      def random_hex_color
        "##{Array.new(6) { HEX_CHARS[rand(HEX_CHARS.length)] }.join}"
      end

      # Parses the two timestamp shapes the data layer stores: a bare date and
      # a date with a time part.
      def parse_datetime(date_time)
        digits = date_time.to_s.delete('^0-9')
        if digits.length >= 14
          Time.new(
            digits[0, 4].to_i,
            digits[4, 2].to_i,
            digits[6, 2].to_i,
            digits[8, 2].to_i,
            digits[10, 2].to_i,
            digits[12, 2].to_i,
          )
        else
          Time.new(digits[0, 4].to_i, digits[4, 2].to_i, digits[6, 2].to_i)
        end
      end

      private

        def format_datetime(date_time)
          time = parse_datetime(date_time)
          if date_time.to_s.include?('T')
            format_with_time(time)
          else
            time.strftime('%d %B')
          end
        end

        def format_with_time(time)
          out = time.strftime('%d %B %H:%M')
          if out.end_with?('00:00')
            out.delete_suffix('00:00').strip
          else
            out
          end
        end
    end
  end
end
