# frozen_string_literal: true

require 'adwaita'

module Errands
  # ShortcutsDialog lists the keyboard shortcuts.
  #
  # Ported from upstream's data/resources/gtk/help-overlay.ui, which GTK loads
  # as the window's help overlay. Gtk::ShortcutsWindow — the widget that file
  # describes — is unusable from the Ruby bindings (constructing one raises
  # "GtkWindow is not subtype of GtkShortcutsWindow"), so the same sections are
  # built with Adwaita::ShortcutsDialog, the widget that replaces it.
  #
  # Upstream's "Sync", "Preferences" and "Toggle Details" entries are left out
  # until the components behind them are ported: this dialog lists the
  # accelerators the application actually binds.
  #
  class ShortcutsDialog < Adwaita::ShortcutsDialog
    SECTIONS = {
      'General' => [
        ['Show keyboard shortcuts', '<Control>question'],
        ['Quit', '<Control>q <Control>w'],
      ],
      'Lists'   => [
        ['Add List', '<Control><Shift>A'],
        ['Import List', '<Control>I'],
      ],
    }.freeze

    def initialize
      super()
      self.title = 'Keyboard Shortcuts'
    end

    def build
      tap do |dialog|
        SECTIONS.each { |title, items| dialog.add(section(title, items)) }
      end
    end

    private

      def section(title, items)
        Adwaita::ShortcutsSection.new.tap do |group|
          group.title = title
          items.each { |label, accelerator| group.add(Adwaita::ShortcutsItem.new(label, accelerator)) }
        end
      end
  end
end
