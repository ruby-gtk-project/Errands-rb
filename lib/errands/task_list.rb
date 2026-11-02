# frozen_string_literal: true

require 'adwaita'

require_relative 'animation'
require_relative 'data'
require_relative 'logging'
require_relative 'settings'
require_relative 'state'
require_relative 'task'
require_relative 'titled_separator'
require_relative 'utils'

module Errands
  # TaskList is one task list's page: its header bar, the entry that adds a
  # task, and the uncompleted and completed sections.
  #
  # Ported from the TaskList class in upstream's
  # errands/widgets/task_list/task_list.py.
  #
  # Upstream builds its "Scroll Up" button but never adds it to a container, so
  # the handler that shows and hides it has nothing to act on; here the button
  # sits at the end of the header bar.
  #
  class TaskList
    MARGIN = 12
    CLAMP_MAXIMUM = 1000
    CLAMP_THRESHOLD = 300
    DND_MARGIN = 100

    def initialize(sidebar_row)
      @list_uid = sidebar_row.uid
      @sidebar_row = sidebar_row
      @tasks = []
      @scrolling = false
    end

    attr_reader :list_uid, :sidebar_row

    def root = bin

    def build
      bin.tap do |root|
        root.child = toolbar_view
        root.add_controller(dnd_controller)

        dnd_controller.signal_connect('motion') { |_, _x, y| on_dnd_scroll(y) }

        toolbar_view.tap do |view|
          view.add_top_bar(header_bar)
          view.add_top_bar(entry_clamp)
          view.content = scroller

          header_bar.tap do |bar|
            bar.title_widget = title
            bar.pack_start(toggle_completed_button)
            bar.pack_start(delete_completed_button)
            bar.pack_end(scroll_up_button)

            toggle_completed_button.bind_property(
              'active',
              delete_completed_button,
              'visible',
              GLib::BindingFlags::SYNC_CREATE,
            )
            toggle_completed_button.signal_connect('toggled') { on_toggle_completed }
            delete_completed_button.signal_connect('clicked') { on_delete_completed }
            scroll_up_button.signal_connect('clicked') { Animation.scroll(scroller, scroll_down: false) }
          end

          entry_clamp.child = entry_row
          entry_row.signal_connect('entry-activated') { on_task_added }

          scroller.tap do |window|
            window.child = content_clamp
            window.vadjustment = adjustment

            adjustment.signal_connect('value-changed') { scroll_up_button.visible = adjustment.value.positive? }

            content_clamp.child = content_box

            content_box.tap do |box|
              box.append(uncompleted_task_list)
              box.append(separator_bin)
              box.append(completed_task_list)

              separator_bin.child = separator.build
            end
          end
        end

        load_tasks
      end
    end

    # ------ PROPERTIES ------ #

    # Top-level tasks.
    def tasks = uncompleted_tasks + completed_tasks

    def uncompleted_tasks = tasks_in(uncompleted_task_list)

    def completed_tasks = tasks_in(completed_task_list)

    # Every task in the list, sub-tasks included.
    def all_tasks = tasks.flat_map { |task| [task] + task.all_tasks }

    # ------ PUBLIC METHODS ------ #

    def add_task(task_data)
      Log.info("Task List: Add task '#{task_data.uid}'")
      Task.new(task_data, self).tap do |task|
        @tasks << task
        if task_data.completed
          completed_task_list.prepend(task.build)
        elsif Settings.get('task-list-new-task-position-top')
          uncompleted_task_list.prepend(task.build)
        else
          uncompleted_task_list.append(task.build)
        end
      end
    end

    # Takes the list's page and its sidebar row away.
    def purge
      State.sidebar.list_box.select_row(@sidebar_row.row.prev_sibling)
      State.sidebar.list_box.remove(@sidebar_row.row)
      State.view_stack.remove(root)
    end

    # - UPDATE UI FUNCTIONS - #

    def update_title
      Log.debug("Task List '#{@list_uid}': Update title")
      title.title = UserData.get_list_prop(@list_uid, :name).to_s

      total, completed = UserData.get_status(@list_uid)
      if total.positive?
        title.subtitle = "Completed: #{completed} / #{total}"
      else
        title.subtitle = ''
      end

      uncompleted = total - completed
      if uncompleted.positive?
        @sidebar_row.size_counter.label = uncompleted.to_s
      else
        @sidebar_row.size_counter.label = ''
      end
      delete_completed_button.sensitive = completed.positive?

      update_separator
    end

    # Adds, removes and re-sections the task widgets after a data change.
    def update_tasks
      tasks_data = UserData.tasks_as_dicts(@list_uid, '').reject(&:deleted)
      data_uids = tasks_data.map(&:uid)
      widget_uids = tasks.map(&:uid)

      tasks_data.each do |task_data|
        unless widget_uids.include?(task_data.uid)
          add_task(task_data)
        end
      end

      tasks.each { |task| resection(task, data_uids) }
    end

    def update_ui
      update_title
      update_tasks
    end

    # Memoized widget methods

    def bin = @bin ||= Adwaita::Bin.new

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new

    def header_bar = @header_bar ||= Adwaita::HeaderBar.new

    def title = @title ||= Adwaita::WindowTitle.new('', '')

    def toggle_completed_button
      @toggle_completed_button ||= Gtk::ToggleButton.new.tap do |button|
        button.icon_name = 'errands-check-toggle-symbolic'
        button.valign = :center
        button.tooltip_text = 'Toggle Completed Tasks'
      end
    end

    def delete_completed_button
      @delete_completed_button ||= Gtk::Button.new.tap do |button|
        button.icon_name = 'errands-delete-all-symbolic'
        button.valign = :center
        button.tooltip_text = 'Delete Completed Tasks'
      end
    end

    def scroll_up_button
      @scroll_up_button ||= Gtk::Button.new.tap do |button|
        button.icon_name = 'errands-up-symbolic'
        button.visible = false
        button.valign = :center
        button.tooltip_text = 'Scroll Up'
      end
    end

    def entry_clamp
      @entry_clamp ||= Adwaita::Clamp.new.tap do |clamp|
        clamp.maximum_size = CLAMP_MAXIMUM
        clamp.tightening_threshold = CLAMP_THRESHOLD
      end
    end

    def entry_row
      @entry_row ||= Adwaita::EntryRow.new.tap do |row|
        row.title = 'Add new Task'
        row.activatable = false
        row.height_request = 60
        row.margin_top = 3
        row.margin_bottom = 3
        row.margin_start = MARGIN
        row.margin_end = MARGIN
        row.add_css_class('card')
      end
    end

    def scroller = @scroller ||= Gtk::ScrolledWindow.new

    def adjustment = @adjustment ||= Gtk::Adjustment.new(
      0,
      0,
      0,
      0,
      0,
      0,
    )

    def content_clamp
      @content_clamp ||= Adwaita::Clamp.new.tap do |clamp|
        clamp.maximum_size = CLAMP_MAXIMUM
        clamp.tightening_threshold = CLAMP_THRESHOLD
      end
    end

    def content_box
      @content_box ||= Gtk::Box.new(:vertical, 0).tap do |box|
        box.margin_bottom = 32
      end
    end

    def uncompleted_task_list = @uncompleted_task_list ||= Gtk::Box.new(:vertical, 0)

    def completed_task_list
      @completed_task_list ||= Gtk::Box.new(:vertical, 0).tap do |box|
        box.visible = false
      end
    end

    def separator = @separator ||= TitledSeparator.new('Completed', [24, 24, 0, 0])

    def separator_bin = @separator_bin ||= Adwaita::Bin.new

    def dnd_controller = @dnd_controller ||= Gtk::DropControllerMotion.new

    private

      def load_tasks
        Log.info("Task List #{@list_uid}: Load Tasks")
        UserData.tasks_as_dicts(@list_uid, '').reject(&:deleted).each do |task_data|
          Task.new(task_data, self).tap do |task|
            @tasks << task
            if task_data.completed
              completed_task_list.append(task.build)
            else
              uncompleted_task_list.append(task.build)
            end
          end
        end

        toggle_completed_button.active = !UserData.get_list_prop(@list_uid, :show_completed).nil?
        update_title
      end

      def tasks_in(box)
        Utils.children(box).filter_map { |widget| @tasks.find { |task| task.root == widget } }
      end

      # The "Completed" rule shows only while the list holds both completed and
      # uncompleted top-level tasks.
      def update_separator
        toplevel = UserData.tasks_as_dicts(@list_uid, '').reject { |task| task.deleted || task.trash }
        completed = toplevel.count(&:completed)
        separator.visible = completed.positive? && completed != toplevel.length
      end

      def resection(task, data_uids)
        if !data_uids.include?(task.uid)
          task.purge
        elsif task.task_data.completed && uncompleted_tasks.include?(task)
          move_to_completed(task)
        elsif !task.task_data.completed && completed_tasks.include?(task)
          move_to_uncompleted(task)
        end
        unless task.root.reveal_child? || task.task_data.trash
          task.toggle_visibility(true)
        end
      end

      def move_to_completed(task)
        reorder_last(task)
        uncompleted_task_list.remove(task.root)
        completed_task_list.prepend(task.root)
      end

      def move_to_uncompleted(task)
        reorder_last(task)
        completed_task_list.remove(task.root)
        uncompleted_task_list.append(task.root)
      end

      def reorder_last(task)
        last = uncompleted_tasks.last
        if last && last.uid != task.uid
          UserData.move_task_after(@list_uid, task.uid, last.uid)
        end
      end

      # ------ SIGNAL HANDLERS ------ #

      def on_delete_completed
        Log.info("Task List '#{@list_uid}': Delete completed tasks")
        all_tasks.each do |task|
          if !task.task_data.trash && task.task_data.completed
            task.delete
          end
        end
        update_ui
      end

      def on_toggle_completed
        shown = toggle_completed_button.active?
        completed_task_list.visible = shown
        all_tasks.each { |task| task.completed_task_list.visible = shown }
        UserData.update_list_prop(@list_uid, :show_completed, shown)
      end

      def on_task_added
        text = entry_row.text.strip
        unless text.empty?
          add_task(UserData.add_task(list_uid: @list_uid, text: text))
          entry_row.text = ''
          unless Settings.get('task-list-new-task-position-top')
            Animation.scroll(scroller, scroll_down: true)
          end
          update_title
        end
      end

      # Scrolls while a drag hovers near the top or the bottom edge.
      def on_dnd_scroll(pos_y)
        if pos_y < DND_MARGIN
          @scrolling = true
          auto_scroll(true)
        elsif pos_y > root.allocated_height - DND_MARGIN
          @scrolling = true
          auto_scroll(false)
        else
          @scrolling = false
        end
      end

      def auto_scroll(scroll_up)
        GLib::Timeout.add(100) do
          if @scrolling && dnd_controller.contains_pointer?
            adjustment.value = adjustment.value - (scroll_up ? 2 : -2)
            true
          else
            false
          end
        end
      end
  end
end
