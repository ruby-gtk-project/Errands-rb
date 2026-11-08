# frozen_string_literal: true

require 'adwaita'

require_relative 'logging'
require_relative 'state'
require_relative 'translations'

module Errands
  # NotesDialog edits one task's notes.
  #
  # Ported from upstream's
  # errands/widgets/shared/task_toolbar/notes_window.py. Upstream's text view
  # is a GtkSource.View with markdown highlighting, a style scheme bound to the
  # dark state and line numbers; GtkSourceView has no binding in this port's
  # dev shell, so a Gtk::TextView carries the same buffer. One dialog is built
  # at startup and re-shown for every task, as upstream does.
  #
  class NotesDialog < Adwaita::Dialog
    CONTENT_SIZE = 600

    def build
      tap do |dialog|
        dialog.title = Translations.gettext('Notes')
        dialog.content_width = CONTENT_SIZE
        dialog.content_height = CONTENT_SIZE
        dialog.child = toolbar_view

        toolbar_view.tap do |view|
          view.add_top_bar(header_bar)
          view.top_bar_style = :raised
          view.content = scrolled_window

          scrolled_window.child = text_view
        end

        dialog.signal_connect('closed') { save }
      end
    end

    # Shows the dialog for a task.
    def show(task)
      @task = task
      buffer.text = task.task_data.notes.to_s
      present(State.main_window.root)
    end

    # Memoized widget methods

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new

    def header_bar = @header_bar ||= Adwaita::HeaderBar.new

    def scrolled_window
      @scrolled_window ||= Gtk::ScrolledWindow.new.tap do |window|
        window.propagate_natural_height = true
        window.propagate_natural_width = true
      end
    end

    def buffer = @buffer ||= Gtk::TextBuffer.new

    def text_view
      @text_view ||= Gtk::TextView.new(buffer).tap do |view|
        view.wrap_mode = :word_char
        view.top_margin = 6
        view.bottom_margin = 6
        view.left_margin = 6
        view.right_margin = 6
      end
    end

    private

      def save
        @task.then do |task|
          if task && buffer.text != task.task_data.notes
            Log.info('Task: Change notes')
            task.update_props(%i[notes synced], [buffer.text, false])
            task.update_toolbar
          end
        end
      end
  end
end
