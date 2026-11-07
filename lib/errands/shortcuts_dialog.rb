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
  # Upstream's "Toggle Details" entry is left out: the task-details panel it
  # toggles has not been ported. "Sync" and "Preferences" are now ported
  # (window.rb's ACTIONS binds both accelerators) and listed below.
  #
  class ShortcutsDialog < Adwaita::ShortcutsDialog
    SECTIONS = {
      'General' => [
        ['Show keyboard shortcuts', '<Control>question'],
        ['Preferences', '<Control>comma'],
        ['Quit', '<Control>q <Control>w'],
      ],
      'Lists'   => [
        ['Add List', '<Control><Shift>A'],
        ['Import List', '<Control>I'],
      ],
      'Sync'    => [
        ['Sync / Fetch Tasks', 'F5 <Control>f'],
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
