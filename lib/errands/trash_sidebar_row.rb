# frozen_string_literal: true

require 'adwaita'

require_relative 'logging'
require_relative 'settings'
require_relative 'state'

module Errands
  # TrashSidebarRow is the "Trash" row in the sidebar, below the task lists:
  # its icon switches between empty and full, and a right-click menu offers
  # Clear and Restore.
  #
  # Ported from the TrashSidebarRow class in upstream's
  # errands/widgets/trash/trash_sidebar_row.py.
  #
  class TrashSidebarRow
    NAME = 'errands_trash_page'

    def name = NAME

    def row = @row ||= build_row

    def build
      row.tap do
        State.trash_sidebar_row = self
        add_actions
      end
    end

    def update_ui
      State.trash_page.update_ui
      size = State.trash_page.trash_items.length
      action_group.lookup_action('restore').enabled = size.positive?
      action_group.lookup_action('clear').enabled = size.positive?
      if size.positive?
        icon.icon_name = 'errands-trash-full-symbolic'
      else
        icon.icon_name = 'errands-trash-symbolic'
      end
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
          list_row.add_css_class('sidebar-item-trash')
          list_row.child = content_box
          list_row.add_controller(right_click_controller)
          list_row.signal_connect('activate') { on_row_activated }

          right_click_controller.signal_connect('released') { |_, _, x, y| popup_menu(x, y) }
        end
      end

      def content_box
        @content_box ||= Gtk::Box.new(:horizontal, 12).tap do |box|
          box.margin_start = 6
          box.append(icon)
          box.append(label)
          box.append(size_counter)
          box.append(popover_menu)
        end
      end

      def icon = @icon ||= Gtk::Image.new(icon_name: 'errands-trash-symbolic')

      def label
        @label ||= Gtk::Label.new('Trash').tap do |text|
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

      def popover_menu
        @popover_menu ||= Gtk::PopoverMenu.new(menu_model).tap do |menu|
          menu.halign = :start
          menu.has_arrow = false
        end
      end

      def menu_model
        @menu_model ||= Gio::Menu.new.tap do |menu|
          menu.append('Clear', 'trash_row.clear')
          menu.append('Restore', 'trash_row.restore')
        end
      end

      def action_group = @action_group ||= Gio::SimpleActionGroup.new

      def right_click_controller
        @right_click_controller ||= Gtk::GestureClick.new.tap do |gesture|
          gesture.button = 3
        end
      end

      def add_actions
        row.insert_action_group('trash_row', action_group)
        create_action('clear') { State.trash_page.on_trash_clear }
        create_action('restore') { State.trash_page.on_trash_restore }
      end

      def create_action(name, &callback)
        Gio::SimpleAction.new(name).tap do |action|
          action.signal_connect('activate') { callback.call }
          action_group.add_action(action)
        end
      end

      def popup_menu(pos_x, pos_y)
        popover_menu.pointing_to = Gdk::Rectangle.new(
          pos_x,
          pos_y,
          1,
          1,
        )
        popover_menu.popup
      end

      def on_row_activated
        Log.debug('Sidebar: Open Trash')
        State.view_stack.visible_child_name = name
        State.split_view.show_content = true
        Settings.set('last-open-list', name)
      end
  end
end
