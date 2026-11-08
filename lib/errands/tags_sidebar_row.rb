# frozen_string_literal: true

require 'adwaita'

require_relative 'data'
require_relative 'logging'
require_relative 'settings'
require_relative 'state'
require_relative 'translations'

module Errands
  # TagsSidebarRow is the "Tags" row in the sidebar, above the task lists.
  #
  # Ported from the TagsSidebarRow class in upstream's
  # errands/widgets/tags/tags_sidebar_row.py.
  #
  class TagsSidebarRow
    NAME = 'errands_tags_page'

    def name = NAME

    def row = @row ||= build_row

    def build
      row.tap do
        State.tags_sidebar_row = self
        update_ui
      end
    end

    def update_ui
      size = UserData.tags.length
      if size.positive?
        size_counter.label = size.to_s
      else
        size_counter.label = ''
      end
    end

    def size_counter = @size_counter ||= build_size_counter

    private

      def build_row
        Gtk::ListBoxRow.new.tap do |list_row|
          list_row.height_request = 45
          list_row.add_css_class('sidebar-item')
          list_row.child = content_box
          list_row.signal_connect('activate') { on_row_activated }
        end
      end

      def content_box
        @content_box ||= Gtk::Box.new(:horizontal, 12).tap do |box|
          box.margin_start = 6
          box.append(icon)
          box.append(label)
          box.append(size_counter)
        end
      end

      def icon = @icon ||= Gtk::Image.new(icon_name: 'errands-tag-symbolic')

      def label
        @label ||= Gtk::Label.new(Translations.gettext('Tags')).tap do |text|
          text.hexpand = true
          text.halign = :start
        end
      end

      def build_size_counter
        Gtk::Button.new.tap do |button|
          button.add_css_class('dim-label')
          button.add_css_class('caption')
          button.add_css_class('flat')
          button.add_css_class('circular')
          button.halign = :center
          button.valign = :center
          button.can_target = false
        end
      end

      def on_row_activated
        Log.debug('Sidebar: Open Tags')
        State.view_stack.visible_child_name = name
        State.split_view.show_content = true
        Settings.set('last-open-list', name)
        State.tags_page.update_ui
      end
  end
end
