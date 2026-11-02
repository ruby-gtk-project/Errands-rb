# frozen_string_literal: true

require 'adwaita'

module Errands
  # Animation animates a widget property and scrolling.
  #
  # Ported from upstream's errands/lib/animation.py, which exposes `property`
  # and `scroll`; `property` is renamed `animate_property` here because
  # `property` is taken by Object in Ruby.
  #
  module Animation
    SCROLL_DURATION = 250

    class << self
      def animate_property(widget, prop, from_value, to_value, time_ms)
        target = Adwaita::CallbackAnimationTarget.new { |value| widget.set_property(prop, value) }
        Adwaita::TimedAnimation.new(
          widget,
          from_value,
          to_value,
          time_ms,
          target,
        ).play
      end

      # Animates the scrolled window to its top or bottom, or down by the
      # height of `widget` when one is given.
      def scroll(window, scroll_down: true, widget: nil)
        adjustment = window.vadjustment
        target = Adwaita::CallbackAnimationTarget.new { |value| adjustment.value = value }
        Adwaita::TimedAnimation.new(
          window,
          adjustment.value,
          scroll_to(adjustment, scroll_down, widget),
          SCROLL_DURATION,
          target,
        ).play
      end

      private

        def scroll_to(adjustment, scroll_down, widget)
          if widget
            widget.allocated_height + adjustment.value
          elsif scroll_down
            adjustment.upper
          else
            adjustment.lower
          end
        end
    end
  end
end
