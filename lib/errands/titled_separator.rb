# frozen_string_literal: true

require 'adwaita'

module Errands
  # TitledSeparator is a horizontal rule with a caption in the middle.
  #
  # Ported from upstream's errands/widgets/shared/titled_separator.py. Upstream
  # declares a `title` GObject property and binds the label to it; here the
  # title is a plain accessor, which is what every call site uses it as.
  #
  class TitledSeparator
    SPACING = 12

    def initialize(title = '', margins = [0, 0, 0, 0])
      @title = title
      @margins = margins
    end

    attr_reader :title

    def build
      box.tap do |container|
        container.append(start_separator)
        container.append(label)
        container.append(end_separator)

        label.label = @title
        container.margin_start = @margins[0]
        container.margin_end = @margins[1]
        container.margin_top = @margins[2]
        container.margin_bottom = @margins[3]
      end
    end

    def title=(text)
      @title = text
      label.label = text
    end

    def visible=(shown)
      box.visible = shown
    end

    # Memoized widget methods

    def box
      @box ||= Gtk::Box.new(:horizontal, SPACING).tap do |container|
        container.add_css_class('dim-label')
      end
    end

    def label
      @label ||= Gtk::Label.new.tap do |text|
        text.add_css_class('caption')
      end
    end

    def start_separator = @start_separator ||= separator

    def end_separator = @end_separator ||= separator

    private

      def separator
        Gtk::Separator.new(:horizontal).tap do |line|
          line.hexpand = true
          line.valign = :center
        end
      end
  end
end
