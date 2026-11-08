# frozen_string_literal: true

require 'adwaita'

require_relative 'datetime_picker'
require_relative 'state'
require_relative 'translations'

module Errands
  # DatetimeDialog edits one task's start and due dates.
  #
  # Ported from upstream's
  # errands/widgets/shared/task_toolbar/datetime_window.py: a view stack with a
  # date-time picker per page and a view switcher in the header bar. One dialog
  # is built at startup and re-shown for every task.
  #
  class DatetimeDialog < Adwaita::Dialog
    PICKER_MARGIN = 12

    def build
      tap do |dialog|
        dialog.title = Translations.gettext('Date and Time')
        dialog.follows_content_size = true
        dialog.child = toolbar_view

        toolbar_view.tap do |view|
          view.add_top_bar(header_bar)
          view.content = view_stack

          header_bar.title_widget = view_switcher

          view_stack.tap do |stack|
            stack.add_titled_with_icon(
              due_scroller,
              Translations.gettext('Due'),
              Translations.gettext('Due'),
              'errands-calendar-symbolic',
            )
            stack.add_titled_with_icon(
              start_scroller,
              Translations.gettext('Start'),
              Translations.gettext('Start'),
              'errands-calendar-symbolic',
            )

            due_scroller.child = due_picker.build
            start_scroller.child = start_picker.build
          end

          view_switcher.stack = view_stack
        end

        dialog.signal_connect('closed') { save }
      end
    end

    def show(task)
      @task = task
      start_picker.datetime = task.task_data.start_date
      due_picker.datetime = task.task_data.due_date
      present(State.main_window.root)
    end

    # Memoized widget methods

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new

    def header_bar = @header_bar ||= Adwaita::HeaderBar.new

    def view_stack = @view_stack ||= Adwaita::ViewStack.new

    def view_switcher
      @view_switcher ||= Adwaita::ViewSwitcher.new.tap do |switcher|
        switcher.policy = :wide
      end
    end

    def due_scroller = @due_scroller ||= picker_scroller

    def start_scroller = @start_scroller ||= picker_scroller

    def due_picker = @due_picker ||= DatetimePicker.new(margins: PICKER_MARGIN)

    def start_picker = @start_picker ||= DatetimePicker.new(margins: PICKER_MARGIN)

    private

      def picker_scroller
        Gtk::ScrolledWindow.new.tap do |window|
          window.propagate_natural_height = true
          window.propagate_natural_width = true
        end
      end

      def save
        @task.then do |task|
          if task
            save_due(task)
            save_start(task)
          end
        end
      end

      def save_due(task)
        if due_picker.datetime != task.task_data.due_date
          task.update_props(%i[due_date synced], [due_picker.datetime, false])
          task.update_toolbar
        end
      end

      def save_start(task)
        if start_picker.datetime != task.task_data.start_date
          task.update_props(%i[start_date synced], [start_picker.datetime, false])
        end
      end
  end
end
