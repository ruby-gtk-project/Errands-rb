# frozen_string_literal: true

require 'adwaita'

require_relative 'data'
require_relative 'state'
require_relative 'translations'

module Errands
  # RenameListDialog asks for a task list's new name.
  #
  # Ported from the _rename action in upstream's
  # errands/widgets/task_list/task_list_sidebar_row.py: the add-list dialog
  # with the current name pre-filled and a "Save" response.
  #
  class RenameListDialog < Adwaita::AlertDialog
    def initialize(current_name, &on_save)
      super()
      @current_name = current_name
      @on_save = on_save
      @names = UserData.lists_as_dicts.map(&:name)
    end

    def build
      tap do |dialog|
        dialog.heading = Translations.gettext('Rename List')
        dialog.extra_child = entry
        dialog.add_response('cancel', Translations.gettext('Cancel'))
        dialog.add_response('save', Translations.gettext('Save'))
        dialog.set_response_enabled('save', false)
        dialog.set_response_appearance('save', :suggested)
        dialog.default_response = 'save'
        dialog.close_response = 'cancel'

        dialog.signal_connect('response') do |_, response|
          if response == 'save'
            @on_save.call(name)
          end
        end

        entry.tap do |field|
          field.buffer.text = @current_name.to_s
          field.signal_connect('notify::text') { dialog.set_response_enabled('save', valid?) }
          field.signal_connect('activate') { confirm }
        end
      end
    end

    def self.show(current_name, &on_save)
      new(current_name, &on_save).build.present(State.main_window.root)
    end

    # Memoized widget methods

    def entry
      @entry ||= Gtk::Entry.new.tap do |field|
        field.placeholder_text = Translations.gettext('New Name')
      end
    end

    private

      def name = entry.text.strip

      def valid? = !name.empty? && !@names.include?(name)

      def confirm
        if valid?
          @on_save.call(name)
          close
        end
      end
  end
end
