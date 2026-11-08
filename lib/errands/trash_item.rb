# frozen_string_literal: true

require 'adwaita'

require_relative 'data'
require_relative 'logging'
require_relative 'state'
require_relative 'task'
require_relative 'translations'

module Errands
  # TrashItem is one row in the Trash page: the trashed task's text, the
  # list it belongs to, and a button to restore it and its parents.
  #
  # Ported from the TrashItem class in upstream's
  # errands/widgets/trash/trash.py.
  #
  class TrashItem
    def initialize(task_data)
      @task_data = task_data
    end

    attr_reader :task_data

    def row = @row ||= build_row

    def build
      row
    end

    def update_ui
      row.title = @task_data.text
      row.subtitle = UserData.get_list_prop(@task_data.list_uid, 'name').to_s
    end

    def restore
      Log.info("Restore task: #{@task_data.uid}")
      parents_uids = UserData.parents_uids_tree(@task_data.list_uid, @task_data.uid)
      parents_uids << @task_data.uid
      parents_uids.each do |uid|
        UserData.update_props(
          @task_data.list_uid,
          uid,
          [:trash],
          [false],
        )
        task = State.get_task(@task_data.list_uid, uid)
        unless task
          next
        end

        task.task_list&.update_title
        task.toggle_visibility(true)
        if task.parent.is_a?(Task)
          task.parent.update_title
          task.parent.update_progress_bar
        end
      end

      State.trash_sidebar_row.update_ui
      State.today_page.update_ui
    end

    private

      def build_row
        Adwaita::ActionRow.new.tap do |action_row|
          action_row.height_request = 60
          action_row.title_selectable = true
          action_row.margin_top = 6
          action_row.margin_bottom = 6
          action_row.add_css_class('card')
          action_row.add_suffix(restore_button)

          restore_button.signal_connect('clicked') { restore }
        end
      end

      def restore_button
        @restore_button ||= Gtk::Button.new.tap do |button|
          button.tooltip_text = Translations.gettext('Restore')
          button.icon_name = 'errands-check-toggle-symbolic'
          button.valign = :center
          button.add_css_class('circular')
          button.add_css_class('flat')
        end
      end
  end
end
