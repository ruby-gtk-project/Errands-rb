# frozen_string_literal: true

require 'adwaita'

require_relative 'data'
require_relative 'state'
require_relative 'translations'

module Errands
  # AddListDialog asks for the name of a new task list.
  #
  # Ported from the _on_add_list_btn_clicked handler in upstream's
  # errands/widgets/sidebar.py: an Adw.MessageDialog (Adwaita::AlertDialog
  # here, its replacement) with an entry, and an "Add" response that stays
  # insensitive until the name is both filled in and unused.
  #
  class AddListDialog < Adwaita::AlertDialog
    def initialize(&on_add)
      super()
      @on_add = on_add
      @names = UserData.lists_as_dicts.map(&:name)
    end

    def build
      tap do |dialog|
        dialog.heading = Translations.gettext('Add List')
        dialog.extra_child = entry
        dialog.add_response('cancel', Translations.gettext('Cancel'))
        dialog.add_response('add', Translations.gettext('Add'))
        dialog.set_response_enabled('add', false)
        dialog.set_response_appearance('add', :suggested)
        dialog.default_response = 'add'
        dialog.close_response = 'cancel'

        dialog.signal_connect('response') do |_, response|
          if response == 'add'
            @on_add.call(name)
          end
        end

        entry.tap do |field|
          field.signal_connect('notify::text') { dialog.set_response_enabled('add', valid?) }
          field.signal_connect('activate') { confirm }
        end
      end
    end

    def self.show(&on_add)
      new(&on_add).build.present(State.main_window.root)
    end

    # Memoized widget methods

    def entry
      @entry ||= Gtk::Entry.new.tap do |field|
        field.placeholder_text = Translations.gettext('New List Name')
      end
    end

    private

      def name = entry.text.strip

      def valid? = !name.empty? && !@names.include?(name)

      def confirm
        if valid?
          @on_add.call(name)
          close
        end
      end
  end
end
