# frozen_string_literal: true

require 'adwaita'

require_relative 'logging'
require_relative 'state'

module Errands
  # AttachmentRow is one attached file in the attachments dialog.
  #
  # Ported from the ErrandsAttachment class in upstream's
  # errands/widgets/shared/task_toolbar/attachments_window.py.
  #
  class AttachmentRow < Adwaita::ActionRow
    def initialize(path)
      super()
      @path = path
    end

    attr_reader :path

    def build
      tap do |row|
        row.activatable = true
        row.tooltip_text = 'Open File'
        row.title = File.basename(@path)
        row.add_prefix(folder_button)
        row.add_suffix(delete_button)

        folder_button.signal_connect('clicked') { open_containing_folder }
        delete_button.signal_connect('clicked') { delete }
        row.signal_connect('activated') { open_file }
      end
    end

    # Memoized widget methods

    def folder_button
      @folder_button ||= Gtk::Button.new.tap do |button|
        button.icon_name = 'errands-folder-symbolic'
        button.tooltip_text = 'Open Containing Folder'
        button.valign = :center
        button.add_css_class('flat')
      end
    end

    def delete_button
      @delete_button ||= Gtk::Button.new.tap do |button|
        button.icon_name = 'errands-trash-symbolic'
        button.tooltip_text = 'Delete'
        button.valign = :center
        button.add_css_class('error')
        button.add_css_class('flat')
      end
    end

    private

      def file = Gio::File.new_for_path(@path)

      def open_file
        Log.info("Attachments: Open file '#{@path}'")
        Gtk::FileLauncher.new(file).launch(State.main_window.root, nil) { nil }
      end

      def open_containing_folder
        Log.info("Attachments: Open folder '#{@path}'")
        Gtk::FileLauncher.new(file).open_containing_folder(State.main_window.root, nil) { nil }
      end

      def delete
        State.attachments_dialog.remove_attachment(self)
      end
  end
end
