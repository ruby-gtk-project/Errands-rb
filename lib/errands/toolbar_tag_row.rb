# frozen_string_literal: true

require 'adwaita'

require_relative 'data'

module Errands
  # ToolbarTagRow is one tag in a task toolbar's tags popover: a check button
  # that adds the tag to the task or takes it away.
  #
  # Ported from the ErrandsToolbarTagsListItem class in upstream's
  # errands/widgets/shared/task_toolbar/toolbar.py.
  #
  class ToolbarTagRow
    SPACING = 6

    def initialize(title, task)
      @title = title
      @task = task
      @block_signals = false
    end

    attr_reader :title

    def build
      box.tap do |container|
        container.append(toggle_button)
        container.append(label)
        container.append(icon)

        toggle_button.signal_connect('toggled') { toggle }
      end
    end

    # Sets the check without running the handler, which is how the popover
    # reflects the task's tags when it opens.
    def active=(active)
      @block_signals = true
      toggle_button.active = active
      @block_signals = false
    end

    # Memoized widget methods

    def box = @box ||= Gtk::Box.new(:horizontal, SPACING)

    def toggle_button = @toggle_button ||= Gtk::CheckButton.new

    def label
      @label ||= Gtk::Label.new(@title).tap do |text|
        text.hexpand = true
        text.halign = :start
        text.max_width_chars = 20
      end
    end

    def icon
      @icon ||= Gtk::Image.new.tap do |image|
        image.icon_name = 'errands-tag-symbolic'
        image.add_css_class('dim-label')
      end
    end

    private

      def toggle
        unless @block_signals
          @task.update_props(%i[tags synced], [tags, false])
          @task.update_tags_bar
        end
      end

      def tags
        stored = @task.task_data.tags
        if toggle_button.active?
          (stored + [@title]).uniq
        else
          stored.reject { |tag| tag == @title }
        end
      end
  end
end
