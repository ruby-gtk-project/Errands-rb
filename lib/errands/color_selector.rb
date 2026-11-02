# frozen_string_literal: true

require 'adwaita'

require_relative 'logging'

module Errands
  # ColorSelector is the row of accent colour radio buttons in a task's menu.
  #
  # Ported from upstream's errands/widgets/shared/color_selector.py. Upstream
  # declares a "color-selected" GObject signal and connects the caller to it;
  # here the caller's block is called directly, which is the same contract
  # without registering a signal.
  #
  class ColorSelector
    COLORS = [
      %w[none None],
      %w[blue Blue],
      %w[green Green],
      %w[yellow Yellow],
      %w[orange Orange],
      %w[red Red],
      %w[purple Purple],
      %w[brown Brown],
    ].freeze

    def initialize(&on_color_selected)
      @on_color_selected = on_color_selected
    end

    def build
      box.tap do |container|
        COLORS.each do |name, _|
          container.append(buttons[name])

          buttons[name].tap do |button|
            button.signal_connect('toggled') { @on_color_selected.call(button, name) }
          end
        end
      end
    end

    # Marks the stored colour as the active one. An empty colour is "none",
    # exactly as upstream maps it.
    def select_color(color)
      if color.to_s.empty?
        name = 'none'
      else
        name = color
      end
      Log.debug("Color Selector: set color to '#{name}'")
      buttons[name]&.active = true
    end

    # Memoized widget methods

    def box = @box ||= Gtk::Box.new(:horizontal, 0)

    # The "none" button is the radio group's head, so it is memoized on its
    # own and the rest join it.
    def none_button = @none_button ||= color_button('none', 'None')

    def buttons
      @buttons ||= {}.tap do |collected|
        collected['none'] = none_button
        COLORS.drop(1).each do |name, tooltip|
          collected[name] = color_button(name, tooltip).tap { |button| button.group = none_button }
        end
      end
    end

    private

      def color_button(name, tooltip)
        Gtk::CheckButton.new.tap do |button|
          button.name = name
          button.tooltip_text = tooltip
          button.add_css_class('accent-color-btn')
          button.add_css_class("accent-color-btn-#{name}")
        end
      end
  end
end
