# frozen_string_literal: true

require 'adwaita'

require_relative 'confirm_dialog'
require_relative 'data'
require_relative 'logging'
require_relative 'rename_list_dialog'
require_relative 'settings'
require_relative 'state'
require_relative 'task_list'
require_relative 'translations'
require_relative 'utils'

module Errands
  # TaskListSidebarRow is one task list's row in the sidebar: its colour
  # button, its name, the count of its uncompleted tasks, and the context menu
  # that renames, deletes or exports it.
  #
  # Ported from the TaskListSidebarRow class in upstream's
  # errands/widgets/task_list/task_list_sidebar_row.py. The row also owns the
  # list's page in the view stack, as upstream's does.
  #
  class TaskListSidebarRow
    HEIGHT = 45
    HOVER_SWITCH_DELAY = 0.7
    DEFAULT_COLOR = '#3584e4'

    def initialize(list_data)
      @list_data = list_data
      @uid = list_data.uid
      @name = list_data.name
      @block_signals = false
    end

    attr_reader :list_data, :uid, :name, :task_list

    def build
      row.tap do |widget|
        widget.child = box
        widget.insert_action_group('list_row', action_group)
        widget.add_controller(drop_target)
        widget.add_controller(drag_hover_controller)
        widget.add_controller(right_click_controller)
        widget.add_controller(long_press_controller)

        box.tap do |container|
          container.append(color_button)
          container.append(label)
          container.append(size_counter)
          container.append(popover_menu)
        end

        widget.signal_connect('activate') { on_row_activated }
        color_button.signal_connect('notify::rgba') { on_color_selected }
        drop_target.signal_connect('drop') { |_, value| on_task_drop(value) }
        drag_hover_controller.signal_connect('enter') { on_drop_hover }
        right_click_controller.signal_connect('released') { |_, _, x, y| popup_menu(x, y) }
        long_press_controller.signal_connect('pressed') { |_, x, y| popup_menu(x, y) }

        add_actions
        add_page
        update_ui(false)
      end
    end

    # Brings the row and, unless told otherwise, the list's page in step with
    # the stored data.
    def update_ui(update_task_list = true)
      Log.debug("Task List Row: Update UI '#{@uid}'")

      @name = UserData.get_list_prop(@uid, :name).to_s
      label.label = @name
      stack_page.name = @name
      stack_page.title = @name

      @block_signals = true
      color_button.rgba = Gdk::RGBA.parse(color_or_default)
      @block_signals = false

      if update_task_list
        @task_list.update_ui
      end
    end

    # Memoized widget methods

    def row
      @row ||= Gtk::ListBoxRow.new.tap do |widget|
        widget.height_request = HEIGHT
        widget.add_css_class('sidebar-item')
      end
    end

    def box = @box ||= Gtk::Box.new(:horizontal, 4)

    def color_button
      @color_button ||= Gtk::ColorDialogButton.new(color_dialog).tap do |button|
        button.tooltip_text = Translations.gettext('Color')
        button.valign = :center
      end
    end

    def color_dialog
      @color_dialog ||= Gtk::ColorDialog.new.tap do |dialog|
        dialog.with_alpha = false
      end
    end

    def label
      @label ||= Gtk::Label.new.tap do |text|
        text.hexpand = true
        text.halign = :start
        text.ellipsize = :end
      end
    end

    def size_counter
      @size_counter ||= Gtk::Button.new(label: '...').tap do |button|
        button.halign = :center
        button.valign = :center
        button.can_target = false
        button.add_css_class('dim-label')
        button.add_css_class('caption')
        button.add_css_class('flat')
        button.add_css_class('circular')
      end
    end

    def menu_model
      @menu_model ||= Gio::Menu.new.tap do |menu|
        menu.append(Translations.gettext('Rename'), 'list_row.rename')
        menu.append(Translations.gettext('Delete'), 'list_row.delete')
        menu.append(Translations.gettext('Export'), 'list_row.export')
      end
    end

    def popover_menu
      @popover_menu ||= Gtk::PopoverMenu.new(menu_model).tap do |menu|
        menu.halign = :start
        menu.has_arrow = false
      end
    end

    def action_group = @action_group ||= Gio::SimpleActionGroup.new

    def drop_target = @drop_target ||= Gtk::DropTarget.new(String, :move)

    def drag_hover_controller = @drag_hover_controller ||= Gtk::DropControllerMotion.new

    def right_click_controller
      @right_click_controller ||= Gtk::GestureClick.new.tap do |gesture|
        gesture.button = 3
      end
    end

    def long_press_controller
      @long_press_controller ||= Gtk::GestureLongPress.new.tap do |gesture|
        gesture.touch_only = true
      end
    end

    def stack_page = @stack_page

    private

      def add_page
        @task_list = TaskList.new(self)
        @stack_page = State.view_stack.add_titled(@task_list.build, @name, @name)
      end

      def add_actions
        create_action('delete') { confirm_delete }
        create_action('rename') { rename }
        create_action('export') { export }
      end

      def create_action(name, &callback)
        Gio::SimpleAction.new(name).tap do |action|
          action.signal_connect('activate') { callback.call }
          action_group.add_action(action)
        end
      end

      def color_or_default
        if @list_data.color.to_s.empty?
          DEFAULT_COLOR
        else
          @list_data.color
        end
      end

      def confirm_delete
        ConfirmDialog.show(Translations.gettext('List will be permanently deleted'), Translations.gettext('Delete'), :destructive) do |response|
          if response == 'cancel'
            Log.debug('ListItem: Deleting list is cancelled')
          else
            Log.info("Lists: Delete list '#{@uid}'")
            UserData.delete_list(@uid)
            State.sidebar.remove_task_list(self)
          end
        end
      end

      def rename
        RenameListDialog.show(label.label) do |text|
          Log.info("ListItem: Rename list '#{@uid}'")
          UserData.update_list_props(@uid, %i[name synced], [text, false])
          update_ui
        end
      end

      def export
        Gtk::FileDialog.new.tap do |dialog|
          dialog.initial_name = "#{@uid}.ics"
          dialog.default_filter = ical_filter
          dialog.save(State.main_window.root, nil) do |_source, result|
            write_export(dialog.save_finish(result))
          rescue StandardError => e
            Log.debug("List: Export cancelled. #{e.message}")
          end
        end
      end

      def ical_filter
        Gtk::FileFilter.new.tap do |filter|
          filter.add_pattern('*.ics')
          filter.name = 'iCal'
        end
      end

      def write_export(file)
        Log.info("List: Export '#{@uid}'")
        File.write(file.path, @list_data.to_ical)
        State.main_window.add_toast(Translations.gettext('Exported'))
      rescue StandardError => e
        Log.error("List: Export failed. #{e.message}")
        State.main_window.add_toast(Translations.gettext('Export failed'))
      end

      # ------ SIGNAL HANDLERS ------ #

      def on_row_activated
        Log.debug("Sidebar: Switch to list '#{@uid}'")
        State.view_stack.visible_child_name = label.label
        State.split_view.show_content = true
        Settings.set('last-open-list', @name)
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

      # Switches to this list when a drag hovers over its row for long enough.
      def on_drop_hover
        entered_at = Time.now
        GLib::Timeout.add(100) do
          if drag_hover_controller.contains_pointer?
            switch_after_delay(entered_at)
          else
            false
          end
        end
      end

      def switch_after_delay(entered_at)
        if Time.now - entered_at >= HOVER_SWITCH_DELAY
          row.activate
          false
        else
          true
        end
      end

      # Moves a dropped task and its sub-tasks into this list.
      def on_task_drop(value)
        list_uid, uid = value.to_s.split(Task::PAYLOAD_SEPARATOR)
        State.get_task(list_uid, uid).then do |task|
          if task && task.list_uid != @uid
            move_here(task)
          end
        end
        true
      end

      def move_here(task)
        old_task_list = task.task_list
        Log.info("Lists: Move '#{task.uid}' to '#{@uid}' list")
        UserData.move_task_to_list(
          task.uid,
          task.list_uid,
          @uid,
          '',
        )

        if task.parent.is_a?(Task)
          task.parent.update_progress_bar
          task.parent.update_title
        end

        task.purge
        old_task_list&.update_title
        @task_list.update_ui
      end

      def on_color_selected
        unless @block_signals
          color = hex_from_button
          Log.debug("Task List '#{@uid}': Set color to '#{color}'")
          @list_data.color = color
          UserData.update_list_props(@uid, %i[color synced], [color, false])
        end
      end

      # Gdk::RGBA prints itself as "rgb(r,g,b)"; upstream picks the three
      # components out of that string the same way.
      def hex_from_button
        components = color_button.rgba.to_s.delete('rgba()').split(',')
        if components.length >= 3
          Utils.rgb_to_hex(components[0], components[1], components[2])
        else
          DEFAULT_COLOR
        end
      end
  end
end
