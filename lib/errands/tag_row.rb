# frozen_string_literal: true

require 'adwaita'

require_relative 'data'
require_relative 'logging'
require_relative 'state'
require_relative 'translations'

module Errands
  # TagRow is one row in the Tags page: a tag's name, how many tasks carry
  # it, and a button to delete it everywhere.
  #
  # Ported from the Tag class in upstream's errands/widgets/tags/tags.py.
  #
  class TagRow
    def initialize(title, tags_page)
      @title = title
      @tags_page = tags_page
    end

    attr_reader :title

    def row = @row ||= build_row

    def build
      row
    end

    def update_ui(tags_in_tasks = nil)
      counted = tags_in_tasks || UserData.tasks.map(&:tags).reject(&:empty?)
      count = counted.count { |tags| tags.include?(@title) }
      row.activatable = false
      if count.positive?
        number_of_tasks.label = count.to_s
      else
        number_of_tasks.label = ''
      end
    end

    private

      def build_row
        Adwaita::ActionRow.new.tap do |action_row|
          action_row.title = @title
          action_row.add_prefix(delete_button)
          action_row.add_suffix(number_of_tasks)

          delete_button.signal_connect('clicked') { delete }
        end
      end

      def delete_button
        @delete_button ||= Gtk::Button.new.tap do |button|
          button.icon_name = 'errands-trash-symbolic'
          button.add_css_class('flat')
          button.add_css_class('error')
          button.tooltip_text = Translations.gettext('Delete')
          button.valign = :center
        end
      end

      def number_of_tasks
        @number_of_tasks ||= Gtk::Button.new.tap do |button|
          button.add_css_class('flat')
          button.add_css_class('dim-label')
          button.add_css_class('circular')
          button.can_target = false
          button.halign = :center
          button.valign = :center
        end
      end

      # UserData.remove_tag already drops the tag from every task's stored
      # tags; update_tags_bar on each task then removes its chip, the same
      # path a tag's own delete button goes through.
      def delete
        Log.info("Tags: Delete Tag '#{@title}'")
        UserData.remove_tag(@title)
        State.tasks.each(&:update_tags_bar)
        @tags_page.update_ui(false)
      end
  end
end
