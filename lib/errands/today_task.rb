# frozen_string_literal: true

require 'adwaita'

require_relative 'data'
require_relative 'logging'
require_relative 'markup'
require_relative 'state'
require_relative 'tag'
require_relative 'task_toolbar'
require_relative 'utils'

module Errands
  # TodayTask is one task row on the Today page: a lighter copy of Task's
  # title row, tags bar and toolbar with no sub-tasks and no drag-and-drop.
  #
  # Ported from the TodayTask class in upstream's
  # errands/widgets/today/today_task.py.
  #
  class TodayTask
    PURGE_DELAY = 300

    def initialize(task_data, today_page)
      @task_data = task_data
      @list_uid = task_data.list_uid
      @uid = task_data.uid
      @today_page = today_page
      @block_signals = true
      @purging = false
      @tags = []
    end

    attr_reader :task_data, :list_uid, :uid

    def block_signals? = @block_signals

    attr_writer :block_signals

    def root = revealer

    def build
      revealer.tap do |root|
        root.child = main_box

        main_box.tap do |box|
          box.append(title_box)
          box.append(popover_menu)
          box.append(tags_bar_revealer)
          box.append(toolbar_revealer)

          title_box.tap do |list|
            list.append(title_row)
            list.append(edit_row)
            list.add_controller(right_click_controller)

            right_click_controller.signal_connect('released') { |_, _, x, y| popup_menu(x, y) }

            title_row.tap do |row|
              row.add_prefix(complete_button)

              complete_button.signal_connect('toggled') { on_complete_button_toggled }
            end

            edit_row.tap do |row|
              row.add_suffix(cancel_edit_button)
              row.signal_connect('apply') { on_edit_row_applied }
              cancel_edit_button.signal_connect('clicked') { cancel_edit }
            end
          end

          tags_bar_revealer.child = tags_bar
        end
      end

      add_actions
      update_ui
      @block_signals = false
      revealer
    end

    # ------ PROPERTIES ------ #

    def task = State.get_task(@task_data.list_uid, @task_data.uid)

    def task_list = State.get_task_list(@task_data.list_uid)

    def tags = @tags

    # ------ PUBLIC METHODS ------ #

    def add_rm_crossline(add)
      if add
        title_row.add_css_class('task-completed')
      else
        title_row.remove_css_class('task-completed')
      end
    end

    def add_tag(tag)
      Tag.new(tag, self).tap do |chip|
        tags_bar.append(chip.build)
        @tags << chip
      end
    end

    def get_prop(prop) = UserData.get_prop(@list_uid, @uid, prop)

    def get_status = UserData.get_status(@list_uid, @uid)

    def delete
      toggle_visibility(false)
      task&.delete
      @today_page.update_status
    end

    def purge
      unless @purging
        @purging = true
        toggle_visibility(false)
        GLib::Timeout.add(PURGE_DELAY) do
          Utils.idle_add { root.parent&.remove(root) }
          false
        end
      end
    end

    LOCAL_PROPS = %w[deleted expanded synced toolbar_shown trash].freeze

    def update_props(props, values)
      stored_props = props.map(&:to_s)
      stored_values = values.dup
      if stored_props.any? { |prop| !LOCAL_PROPS.include?(prop) }
        stored_props << 'changed_at'
        stored_values << Time.now.strftime('%Y%m%dT%H%M%S')
      end
      UserData.update_props(
        @list_uid,
        @uid,
        stored_props,
        stored_values,
      )
      if stored_props == ['expanded'] || stored_props == ['toolbar_shown']
        @today_page.update_ui
      end
    end

    def toggle_visibility(shown)
      Utils.idle_add { revealer.reveal_child = shown }
    end

    def update_title
      title_row.title = Markup.find_url(Markup.escape(@task_data.text))
      title_row.subtitle = UserData.get_list_prop(@task_data.list_uid, 'name').to_s
      update_completion
    end

    def update_tags_bar
      stored = @task_data.tags
      @tags.select { |chip| !stored.include?(chip.title) }.each { |chip| remove_tag_chip(chip) }
      shown = @tags.map(&:title)
      stored.each do |tag|
        unless shown.include?(tag)
          add_tag(tag)
        end
      end
      tags_bar_revealer.reveal_child = !stored.empty?
      task&.update_tags_bar
    end

    def update_toolbar
      if @toolbar.nil?
        build_toolbar
      end
      @toolbar.update_ui
      task&.update_toolbar
    end

    def update_color
      main_box.css_classes.grep(/\Atask-/).each { |css| main_box.remove_css_class(css) }
      complete_button.css_classes.grep(/\Acheckbtn-/).each { |css| complete_button.remove_css_class(css) }

      @task_data.color.then do |color|
        unless color.to_s.empty?
          main_box.add_css_class("task-#{color}")
          complete_button.add_css_class("checkbtn-#{color}")
        end
      end
    end

    def update_ui
      toggle_visibility(!@task_data.trash)
      update_color
      update_title
      update_tags_bar
      update_toolbar
    end

    # Memoized widget methods

    def revealer = @revealer ||= Gtk::Revealer.new

    def main_box
      @main_box ||= Gtk::Box.new(:vertical, 0).tap do |box|
        box.margin_start = 12
        box.margin_end = 12
        box.margin_bottom = 6
        box.margin_top = 6
        box.add_css_class('card')
        box.add_css_class('fade')
      end
    end

    def title_box
      @title_box ||= Gtk::ListBox.new.tap do |list|
        list.add_css_class('transparent')
        list.add_css_class('rounded-corners')
      end
    end

    def title_row
      @title_row ||= Adwaita::ActionRow.new.tap do |row|
        row.height_request = 60
        row.use_markup = true
        row.add_css_class('transparent')
        row.add_css_class('rounded-corners')
      end
    end

    def complete_button
      @complete_button ||= Gtk::CheckButton.new.tap do |button|
        button.tooltip_text = 'Toggle Completion'
        button.valign = :center
        button.add_css_class('selection-mode')
      end
    end

    def edit_row
      @edit_row ||= Adwaita::EntryRow.new.tap do |row|
        row.title = 'Edit'
        row.visible = false
        row.height_request = 60
        row.show_apply_button = true
        row.add_css_class('transparent')
        row.add_css_class('rounded-corners')
      end
    end

    def cancel_edit_button
      @cancel_edit_button ||= Gtk::Button.new.tap do |button|
        button.tooltip_text = 'Cancel'
        button.valign = :center
        button.icon_name = 'window-close-symbolic'
        button.add_css_class('circular')
      end
    end

    def tags_bar
      @tags_bar ||= Gtk::FlowBox.new.tap do |flow|
        flow.height_request = 20
        flow.margin_start = 12
        flow.margin_end = 12
        flow.margin_bottom = 3
        flow.selection_mode = :none
        flow.max_children_per_line = 1000
      end
    end

    def tags_bar_revealer = @tags_bar_revealer ||= Gtk::Revealer.new

    def toolbar_revealer = @toolbar_revealer ||= Gtk::Revealer.new

    def popover_menu
      @popover_menu ||= Gtk::PopoverMenu.new(menu_model).tap do |menu|
        menu.halign = :start
        menu.has_arrow = false
      end
    end

    def menu_model
      @menu_model ||= Gio::Menu.new.tap do |menu|
        menu.append('Edit', 'task.edit')
        menu.append('Move to Trash', 'task.move_to_trash')
        menu.append('Copy to Clipboard', 'task.copy_to_clipboard')
        menu.append('Export', 'task.export')
      end
    end

    def action_group = @action_group ||= Gio::SimpleActionGroup.new

    def right_click_controller
      @right_click_controller ||= Gtk::GestureClick.new.tap do |gesture|
        gesture.button = 3
      end
    end

    private

      def add_actions
        revealer.insert_action_group('task', action_group)
        create_action('edit') { start_edit }
        create_action('copy_to_clipboard') { copy_to_clipboard }
        create_action('export') { export }
        create_action('move_to_trash') { delete }
      end

      def create_action(name, &callback)
        Gio::SimpleAction.new(name).tap do |action|
          action.signal_connect('activate') { callback.call }
          action_group.add_action(action)
        end
      end

      def build_toolbar
        @toolbar = TaskToolbar.new(self)
        toolbar_revealer.child = @toolbar.build
      end

      def remove_tag_chip(chip)
        Utils.children(tags_bar).find { |child| child.child == chip.box }.then do |flow_child|
          unless flow_child.nil?
            tags_bar.remove(flow_child)
          end
        end
        @tags.delete(chip)
      end

      def update_completion
        completed = @task_data.completed
        add_rm_crossline(completed)
        unless complete_button.active? == completed
          @block_signals = true
          complete_button.active = completed
          @block_signals = false
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

      def start_edit
        edit_row.text = @task_data.text
        edit_row.visible = true
        title_row.visible = false
        edit_row.grab_focus
      end

      def cancel_edit
        edit_row.text = ''
        edit_row.signal_emit('apply')
      end

      def copy_to_clipboard
        Log.info('TodayTask: Copy text to clipboard')
        revealer.clipboard.set(@task_data.text)
        State.main_window.add_toast('Copied to Clipboard')
      end

      def export
        Gtk::FileDialog.new.tap do |dialog|
          dialog.initial_name = "#{@uid}.ics"
          dialog.save(State.main_window.root, nil) do |_source, result|
            write_export(dialog.save_finish(result))
          rescue StandardError => e
            Log.debug("TodayTask: Export cancelled. #{e.message}")
          end
        end
      end

      def write_export(file)
        Log.info("TodayTask: Export '#{@uid}'")
        File.write(file.path, @task_data.to_ical(as_calendar: true))
        State.main_window.add_toast('Exported')
      end

      def on_complete_button_toggled
        add_rm_crossline(complete_button.active?)
        unless @block_signals
          task.then { |linked| linked.complete_button.active = complete_button.active? }
          if complete_button.active?
            purge
            @today_page.update_status
          end
        end
      end

      def on_edit_row_applied
        text = edit_row.text.strip
        edit_row.visible = false
        title_row.visible = true
        unless text.empty? || text == @task_data.text
          update_props(%i[text synced], [text, false])
          update_title
          task&.update_title
        end
      end
  end
end
