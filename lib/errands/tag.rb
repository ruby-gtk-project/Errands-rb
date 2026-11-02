# frozen_string_literal: true

require 'adwaita'

require_relative 'logging'

module Errands
  # Tag is one tag chip in a task's tags bar.
  #
  # Ported from the Tag class in upstream's errands/widgets/task.py.
  #
  class Tag
    def initialize(title, task)
      @title = title
      @task = task
    end

    attr_reader :title

    def build
      box.tap do |container|
        container.append(label)
        container.append(delete_button)

        delete_button.signal_connect('clicked') { delete }
      end
    end

    # Memoized widget methods

    def box
      @box ||= Gtk::Box.new(:horizontal, 0).tap do |container|
        container.hexpand = false
        container.valign = :center
        container.add_css_class('tag')
      end
    end

    def label
      @label ||= Gtk::Label.new(@title).tap do |text|
        text.max_width_chars = 15
        text.ellipsize = :end
        text.hexpand = true
        text.halign = :start
        text.add_css_class('caption-heading')
      end
    end

    def delete_button
      @delete_button ||= Gtk::Button.new.tap do |button|
        button.icon_name = 'errands-close-symbolic'
        button.tooltip_text = 'Delete Tag'
        button.cursor = Gdk::Cursor.new('pointer')
      end
    end

    private

      def delete
        Log.debug("Task '#{@task.uid}': Delete tag '#{@title}'")
        @task.update_props(%i[tags synced], [@task.task_data.tags.reject { |tag| tag == @title }, false])
        @task.update_tags_bar
      end
  end
end
