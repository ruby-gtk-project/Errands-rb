# frozen_string_literal: true

require 'adwaita'

require_relative 'attachment_row'
require_relative 'logging'
require_relative 'state'
require_relative 'utils'

module Errands
  # AttachmentsDialog lists and edits one task's attached files.
  #
  # Ported from the ErrandsAttachmentsWindow class in upstream's
  # errands/widgets/shared/task_toolbar/attachments_window.py. One dialog is
  # built at startup and re-shown for every task.
  #
  class AttachmentsDialog < Adwaita::Dialog
    WIDTH = 360

    def build
      tap do |dialog|
        dialog.title = 'Attachments'
        dialog.follows_content_size = true
        dialog.child = toolbar_view

        toolbar_view.tap do |view|
          view.add_top_bar(header_bar)
          view.content = scrolled_window
          view.width_request = WIDTH

          header_bar.pack_start(add_button)
          add_button.signal_connect('clicked') { choose_file }

          scrolled_window.tap do |window|
            window.child = content_box
            window.propagate_natural_height = true

            content_box.tap do |box|
              box.append(status_page)
              box.append(attachments_list)
            end
          end
        end

        dialog.signal_connect('closed') { @task&.update_toolbar }
      end
    end

    def show(task)
      @task = task
      attachments_list.remove_all
      task.task_data.attachments.each { |path| attachments_list.append(AttachmentRow.new(path).build) }
      update_ui
      present(State.main_window.root)
    end

    def update_ui
      size = @task.task_data.attachments.length
      status_page.visible = size.zero?
      attachments_list.visible = size.positive?
    end

    # Drops one row's file from the task and from the list.
    def remove_attachment(row)
      @task.update_props([:attachments], [@task.task_data.attachments.reject { |path| path == row.path }])
      attachments_list.remove(row)
      update_ui
    end

    # Memoized widget methods

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new

    def header_bar = @header_bar ||= Adwaita::HeaderBar.new

    def add_button
      @add_button ||= Gtk::Button.new.tap do |button|
        button.icon_name = 'errands-add-symbolic'
        button.tooltip_text = 'Add Attachment'
      end
    end

    def scrolled_window = @scrolled_window ||= Gtk::ScrolledWindow.new

    def content_box = @content_box ||= Gtk::Box.new(:vertical, 0)

    def status_page
      @status_page ||= Adwaita::StatusPage.new.tap do |page|
        page.title = 'No Files Attached'
        page.icon_name = 'errands-attachment-symbolic'
        page.vexpand = true
        page.add_css_class('compact')
      end
    end

    def attachments_list
      @attachments_list ||= Gtk::ListBox.new.tap do |list|
        list.selection_mode = :none
        list.valign = :start
        list.margin_top = 6
        list.margin_bottom = 12
        list.margin_start = 12
        list.margin_end = 12
        list.add_css_class('boxed-list')
      end
    end

    def file_dialog = @file_dialog ||= Gtk::FileDialog.new

    private

      def choose_file
        file_dialog.open(State.main_window.root, nil) do |_source, result|
          attach(file_dialog.open_finish(result).path)
        rescue StandardError => e
          Log.debug("Attachments: Selecting file cancelled. #{e.message}")
        end
      end

      def attach(path)
        unless @task.task_data.attachments.include?(path)
          @task.update_props([:attachments], [@task.task_data.attachments + [path]])
          attachments_list.append(AttachmentRow.new(path).build)
          update_ui
        end
      end
  end
end
