# frozen_string_literal: true

require 'adwaita'

require_relative 'animation'
require_relative 'data'
require_relative 'logging'
require_relative 'markup'
require_relative 'settings'
require_relative 'state'
require_relative 'tag'
require_relative 'task_toolbar'
require_relative 'titled_separator'
require_relative 'utils'

module Errands
  # Task is one task: its title row, its tags, its progress bar, its toolbar
  # and its sub-tasks.
  #
  # Ported from the Task class in upstream's errands/widgets/task.py.
  #
  # Upstream drags a Task widget itself: its drop targets take the Task GType
  # and its drag source hands over a GObject value holding the widget. A Task
  # here is a plain Ruby object rather than a GObject subclass, so the drag
  # carries the task's "list uid / task uid" pair as text and the receiving end
  # looks the widget back up through State — the same move, addressed by uid
  # instead of by pointer.
  #
  class Task
    PAYLOAD_SEPARATOR = "\t"
    LOCAL_PROPS = %w[deleted expanded synced toolbar_shown trash color notified].freeze
    PURGE_DELAY = 300
    MARGIN = 12

    def initialize(task_data, parent)
      @task_data = task_data
      @list_uid = task_data.list_uid
      @uid = task_data.uid
      @parent = parent
      @block_signals = true
      @purging = false
      @sub_tasks = []
      @tags = []
    end

    attr_reader :task_data, :list_uid, :uid, :parent, :toolbar

    def block_signals? = @block_signals

    attr_writer :block_signals

    # The widget this task lives in, which is what the parent box holds.
    def root = revealer

    def build
      revealer.tap do |root|
        root.child = outer_box
        root.add_controller(drop_motion_controller)

        drop_motion_controller.bind_property(
          'contains-pointer',
          top_drop_area,
          'reveal-child',
          GLib::BindingFlags::SYNC_CREATE,
        )

        outer_box.tap do |box|
          box.append(top_drop_area)
          box.append(main_box)

          top_drop_area.tap do |area|
            area.child = top_drop_area_image

            top_drop_area_image.add_controller(top_drop_target)
            top_drop_target.signal_connect('drop') { |_, value| on_top_area_drop(value) }
          end

          main_box.tap do |content|
            content.append(title_box)
            content.append(popover_menu)
            content.append(tags_bar_revealer)
            content.append(progress_bar_revealer)
            content.append(toolbar_revealer)
            content.append(sub_tasks_revealer)

            title_box.tap do |list|
              list.append(title_row)
              list.append(edit_row)
              list.add_controller(hover_controller)
              list.add_controller(click_controller)
              list.add_controller(drop_target)
              list.add_controller(drag_source)

              click_controller.signal_connect('released') { on_title_clicked }
              drop_target.signal_connect('drop') { |_, value| on_task_drop(value) }
              drag_source.signal_connect('prepare') { on_drag_prepare }
              drag_source.signal_connect('drag-end') { on_drag_end }
              drag_source.signal_connect('drag-cancel') { on_drag_end }

              title_row.tap do |row|
                row.add_prefix(complete_button)
                row.add_suffix(suffix_box)
                row.add_controller(right_click_controller)
                row.add_controller(long_press_controller)

                complete_button.signal_connect('toggled') { on_complete_button_toggled }
                right_click_controller.signal_connect('released') { |_, _, x, y| popup_menu(x, y) }
                long_press_controller.signal_connect('pressed') { |_, x, y| popup_menu(x, y) }

                suffix_box.tap do |suffixes|
                  suffixes.append(expand_indicator_revealer)
                  suffixes.append(toolbar_toggle_button)

                  expand_indicator_revealer.child = expand_indicator
                  hover_controller.bind_property(
                    'contains-pointer',
                    expand_indicator_revealer,
                    'reveal-child',
                    GLib::BindingFlags::SYNC_CREATE,
                  )
                  toolbar_toggle_button.bind_property(
                    'active',
                    toolbar_revealer,
                    'reveal-child',
                    GLib::BindingFlags::SYNC_CREATE | GLib::BindingFlags::BIDIRECTIONAL,
                  )
                  toolbar_toggle_button.signal_connect('toggled') { on_toolbar_toggle_button_toggled }
                end
              end

              edit_row.tap do |row|
                row.add_suffix(cancel_edit_button)
                row.signal_connect('apply') { on_edit_row_applied }
                cancel_edit_button.signal_connect('clicked') { cancel_edit }
              end
            end

            tags_bar_revealer.child = tags_bar
            progress_bar_revealer.child = progress_bar

            sub_tasks_revealer.tap do |revealer|
              revealer.child = sub_tasks_box

              sub_tasks_box.tap do |box|
                box.append(sub_task_entry)
                box.append(uncompleted_task_list)
                box.append(separator_bin)
                box.append(completed_task_list)

                separator_bin.child = separator.build
                sub_task_entry.signal_connect('activate') { on_sub_task_added }
              end
            end
          end
        end

        add_actions
        load_sub_tasks
        @block_signals = false
      end
    end

    # ------ PROPERTIES ------ #

    def task_list = State.get_task_list(@task_data.list_uid)

    # The chain of parent tasks, nearest first.
    def parents_tree
      [].tap do |parents|
        task = self
        while task.parent.is_a?(Task)
          parents << task.parent
          task = task.parent
        end
      end
    end

    def tags = @tags

    def tasks = uncompleted_tasks + completed_tasks

    def uncompleted_tasks = tasks_in(uncompleted_task_list)

    def completed_tasks = tasks_in(completed_task_list)

    # Every sub-task, however deep.
    def all_tasks = tasks.flat_map { |task| [task] + task.all_tasks }

    # ------ PUBLIC METHODS ------ #

    def add_tag(tag)
      Tag.new(tag, self).tap do |chip|
        tags_bar.append(chip.build)
        @tags << chip
      end
    end

    def add_rm_crossline(add)
      if add
        title_row.add_css_class('task-completed')
      else
        title_row.remove_css_class('task-completed')
      end
    end

    # Builds a sub-task's widget and puts it in the right section.
    def add_task(task_data)
      Log.info("Task '#{@uid}': Add sub-task '#{task_data.uid}'")
      Task.new(task_data, self).tap do |task|
        @sub_tasks << task
        if task_data.completed
          completed_task_list.prepend(task.build)
        elsif Settings.get('task-list-new-task-position-top')
          uncompleted_task_list.prepend(task.build)
        else
          uncompleted_task_list.append(task.build)
        end
      end
    end

    def get_prop(prop) = UserData.get_prop(@list_uid, @uid, prop)

    def get_status = UserData.get_status(@list_uid, @uid)

    # Moves the task to the trash: hides it and marks the record.
    def delete
      Log.info("Task: Move to trash: '#{@uid}'")
      toggle_visibility(false)
      update_props([:trash], [true])
      complete_button.active = true
      State.today_page.update_ui
      State.trash_sidebar_row.update_ui
      State.tags_page.update_ui
      task_list&.update_title
      if @parent.is_a?(Task)
        @parent.update_title
        @parent.update_progress_bar
      end
    end

    def expand(expanded)
      unless expanded == @task_data.expanded
        update_props([:expanded], [expanded])
      end
      sub_tasks_revealer.reveal_child = expanded
      if expanded
        expand_indicator.remove_css_class('expand-indicator-expanded')
      else
        expand_indicator.add_css_class('expand-indicator-expanded')
      end
    end

    # Hides the task, then takes its widget out of its parent box.
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

    # Writes properties through to the data layer, adding the bookkeeping
    # upstream adds: a new changed_at for anything that is not a local-only
    # property, and synced = false alongside it.
    def update_props(props, values)
      stored_props = props.map(&:to_s)
      stored_values = values.dup
      if stored_props.any? { |prop| !LOCAL_PROPS.include?(prop) }
        stored_props << 'changed_at'
        stored_values << Time.now.strftime('%Y%m%dT%H%M%S')
      end
      if !stored_props.include?('synced') && stored_props.include?('changed_at')
        stored_props << 'synced'
        stored_values << false
      end
      UserData.update_props(
        @list_uid,
        @uid,
        stored_props,
        stored_values,
      )
    end

    def toggle_visibility(shown)
      Utils.idle_add { revealer.reveal_child = shown }
    end

    # - UPDATE UI FUNCTIONS - #

    def update_title
      title_row.title = Markup.find_url(Markup.escape(@task_data.text))
      total, completed = get_status
      if total.positive?
        title_row.subtitle = "Completed: #{completed} / #{total}"
      else
        title_row.subtitle = ''
      end
      toolbar_toggle_button.active = @task_data.toolbar_shown
      update_completion
      separator.visible = completed.positive? && completed != total
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
    end

    def update_progress_bar
      total, completed = get_status
      percent = progress_percent(total, completed)
      unless @task_data.percent_complete == percent
        update_props(%i[percent_complete synced], [percent, false])
      end
      progress_bar.fraction = percent / 100.0
      progress_bar_revealer.reveal_child = total.positive?
    end

    def update_toolbar
      @toolbar&.update_ui
    end

    # Adds, removes and re-sections the sub-task widgets after a data change.
    def update_tasks
      sub_tasks_data = UserData.tasks_as_dicts(@list_uid, @uid)
      data_uids = sub_tasks_data.map(&:uid)
      widget_uids = tasks.map(&:uid)

      sub_tasks_data.each do |task_data|
        unless widget_uids.include?(task_data.uid)
          add_task(task_data)
        end
      end

      tasks.each { |task| resection(task, data_uids) }
    end

    def update_color
      main_box.css_classes.grep(/\Atask-/).each { |css| main_box.remove_css_class(css) }
      complete_button.css_classes.grep(/\Acheckbtn-/).each { |css| complete_button.remove_css_class(css) }
      progress_bar.css_classes.grep(/\Aprogressbar-/).each { |css| progress_bar.remove_css_class(css) }

      @task_data.color.then do |color|
        unless color.to_s.empty?
          main_box.add_css_class("task-#{color}")
          complete_button.add_css_class("checkbtn-#{color}")
          progress_bar.add_css_class("progressbar-#{color}")
        end
      end
    end

    def update_ui
      update_title
      update_tags_bar
      update_toolbar
      update_progress_bar
      update_tasks
      update_color
    end

    # Memoized widget methods

    def revealer = @revealer ||= Gtk::Revealer.new

    def outer_box
      @outer_box ||= Gtk::Box.new(:vertical, 0).tap do |box|
        box.margin_top = 6
        box.margin_bottom = 6
      end
    end

    def top_drop_area = @top_drop_area ||= Gtk::Revealer.new

    def top_drop_area_image
      @top_drop_area_image ||= Gtk::Image.new.tap do |image|
        image.icon_name = 'errands-add-symbolic'
        image.margin_start = MARGIN
        image.margin_end = MARGIN
        image.add_css_class('task-drop-area')
      end
    end

    def main_box
      @main_box ||= Gtk::Box.new(:vertical, 0).tap do |box|
        box.margin_start = MARGIN
        box.margin_end = MARGIN
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
        row.tooltip_text = 'Toggle Sub-Tasks'
        row.cursor = Gdk::Cursor.new('pointer')
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

    def suffix_box = @suffix_box ||= Gtk::Box.new(:horizontal, 6)

    def expand_indicator
      @expand_indicator ||= Gtk::Image.new.tap do |image|
        image.icon_name = 'errands-up-symbolic'
        image.halign = :end
        image.add_css_class('expand-indicator')
      end
    end

    def expand_indicator_revealer
      @expand_indicator_revealer ||= Gtk::Revealer.new.tap do |revealer|
        revealer.transition_type = :crossfade
        revealer.reveal_child = false
        revealer.can_target = false
      end
    end

    def toolbar_toggle_button
      @toolbar_toggle_button ||= Gtk::ToggleButton.new.tap do |button|
        button.icon_name = 'errands-toolbar-symbolic'
        button.valign = :center
        button.tooltip_text = 'Toggle Toolbar'
        button.add_css_class('circular')
        button.add_css_class('flat')
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
        flow.margin_start = MARGIN
        flow.margin_end = MARGIN
        flow.margin_bottom = 3
        flow.selection_mode = :none
        flow.max_children_per_line = 1000
      end
    end

    def tags_bar_revealer = @tags_bar_revealer ||= Gtk::Revealer.new

    def progress_bar
      @progress_bar ||= Gtk::ProgressBar.new.tap do |bar|
        bar.margin_start = MARGIN
        bar.margin_end = MARGIN
        bar.margin_bottom = 2
        bar.add_css_class('osd')
        bar.add_css_class('dim-label')
      end
    end

    def progress_bar_revealer
      @progress_bar_revealer ||= Gtk::Revealer.new.tap do |revealer|
        revealer.reveal_child = true
      end
    end

    def toolbar_revealer = @toolbar_revealer ||= Gtk::Revealer.new

    def sub_tasks_revealer = @sub_tasks_revealer ||= Gtk::Revealer.new

    def sub_tasks_box
      @sub_tasks_box ||= Gtk::Box.new(:vertical, 0).tap do |box|
        box.add_css_class('sub-tasks')
      end
    end

    def sub_task_entry
      @sub_task_entry ||= Gtk::Entry.new.tap do |entry|
        entry.margin_start = MARGIN
        entry.margin_end = MARGIN
        entry.margin_top = 3
        entry.margin_bottom = 4
        entry.placeholder_text = 'Add new Sub-Task'
      end
    end

    def uncompleted_task_list = @uncompleted_task_list ||= Gtk::Box.new(:vertical, 0)

    def completed_task_list = @completed_task_list ||= Gtk::Box.new(:vertical, 0)

    def separator = @separator ||= TitledSeparator.new('Completed', [24, 24, 0, 0])

    def separator_bin = @separator_bin ||= Adwaita::Bin.new

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

    def hover_controller = @hover_controller ||= Gtk::EventControllerMotion.new

    def click_controller = @click_controller ||= Gtk::GestureClick.new

    def drop_target = @drop_target ||= Gtk::DropTarget.new(String, :move)

    def top_drop_target = @top_drop_target ||= Gtk::DropTarget.new(String, :move)

    def drop_motion_controller = @drop_motion_controller ||= Gtk::DropControllerMotion.new

    def drag_source
      @drag_source ||= Gtk::DragSource.new.tap do |source|
        source.actions = :move
      end
    end

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

      def load_sub_tasks
        UserData.tasks.select { |task| sub_task?(task) }.each do |task_data|
          Task.new(task_data, self).tap do |task|
            @sub_tasks << task
            if task_data.completed
              completed_task_list.append(task.build)
            else
              uncompleted_task_list.append(task.build)
            end
          end
        end

        revealer.reveal_child = @task_data.expanded
        toggle_visibility(!@task_data.trash)
        expand(@task_data.expanded)
        update_color
        update_title
        update_progress_bar
        update_tags_bar
        update_toolbar
      end

      def sub_task?(task_data)
        !task_data.deleted && task_data.list_uid == @list_uid && task_data.parent == @uid
      end

      # Builds the toolbar on first use. Upstream does the same, so a list of
      # tasks whose toolbars are hidden costs nothing to show.
      def build_toolbar
        @toolbar = TaskToolbar.new(self)
        toolbar_revealer.child = @toolbar.build
      end

      def tasks_in(box)
        Utils.children(box).filter_map { |widget| @sub_tasks.find { |task| task.root == widget } }
      end

      # A flow box wraps every child in a Gtk::FlowBoxChild, so the chip's box
      # has to be matched through that wrapper.
      def remove_tag_chip(chip)
        Utils.children(tags_bar).find { |child| child.child == chip.box }.then do |flow_child|
          unless flow_child.nil?
            tags_bar.remove(flow_child)
          end
        end
        @tags.delete(chip)
      end

      def progress_percent(total, completed)
        if total.positive?
          (completed.to_f / total * 100).to_i
        elsif @task_data.completed
          100
        else
          0
        end
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

      # Moves one sub-task widget into the section its data says it belongs in,
      # or takes it away when the data is gone.
      def resection(task, data_uids)
        if !data_uids.include?(task.uid)
          task.purge
        elsif task.task_data.completed && uncompleted_tasks.include?(task)
          move_to_completed(task)
        elsif !task.task_data.completed && completed_tasks.include?(task)
          move_to_uncompleted(task)
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

      # Keeps the stored order in step with the move: a task leaving a section
      # goes after the last uncompleted one, as upstream does.
      def reorder_last(task)
        last = uncompleted_tasks.last
        if last && last.uid != task.uid
          UserData.move_task_after(@list_uid, task.uid, last.uid)
        end
      end

      # ------ SIGNAL HANDLERS ------ #

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
        Log.info('Task: Copy text to clipboard')
        revealer.clipboard.set(@task_data.text)
        State.main_window.add_toast('Copied to Clipboard')
      end

      def export
        Gtk::FileDialog.new.tap do |dialog|
          dialog.initial_name = "#{@uid}.ics"
          dialog.save(State.main_window.root, nil) do |_source, result|
            write_export(dialog.save_finish(result))
          rescue StandardError => e
            Log.debug("Task: Export cancelled. #{e.message}")
          end
        end
      end

      def write_export(file)
        Log.info("Task: Export '#{@uid}'")
        File.write(file.path, @task_data.to_ical(as_calendar: true))
        State.main_window.add_toast('Exported')
      end

      def on_complete_button_toggled
        add_rm_crossline(complete_button.active?)
        unless @block_signals
          Log.debug("Task '#{@uid}': Set completed to '#{complete_button.active?}'")
          update_props(%i[completed synced], [complete_button.active?, false])
          move_section
          cascade_completion
          update_parents
        end
      end

      def move_section
        root.parent&.remove(root)
        if complete_button.active?
          @parent.completed_task_list.prepend(root)
        else
          @parent.uncompleted_task_list.append(root)
        end
      end

      # Completing a task completes its sub-tasks; uncompleting one uncompletes
      # its parents.
      def cascade_completion
        if complete_button.active?
          uncompleted_tasks.each { |task| task.complete_button.active = true }
        else
          parents_tree.each do |task|
            if task.complete_button.active?
              task.complete_button.active = false
            end
          end
        end
      end

      def update_parents
        if @parent.is_a?(Task)
          @parent.update_progress_bar
          @parent.update_title
        end
        task_list&.update_title
        update_title
        update_progress_bar
      end

      def on_edit_row_applied
        text = edit_row.text.strip
        edit_row.visible = false
        title_row.visible = true
        unless text.empty? || text == @task_data.text
          update_props(%i[text synced], [text, false])
          update_title
        end
      end

      def on_toolbar_toggle_button_toggled
        unless toolbar_toggle_button.active? == @task_data.toolbar_shown
          update_props([:toolbar_shown], [toolbar_toggle_button.active?])
          if @toolbar.nil? && toolbar_toggle_button.active?
            build_toolbar
            update_toolbar
          end
        end
      end

      def on_title_clicked
        expand(!sub_tasks_revealer.child_revealed?)
      end

      def on_sub_task_added
        text = sub_task_entry.text.strip
        unless text.empty?
          add_task(UserData.add_task(list_uid: @list_uid, text: text, parent: @uid))
          sub_task_entry.text = ''
          if @task_data.completed
            update_props(%i[completed synced], [false, false])
          end
          update_title
          update_progress_bar
          task_list&.update_title
        end
      end

      # --- DND --- #

      def payload = [@list_uid, @uid].join(PAYLOAD_SEPARATOR)

      def dragged_task(value)
        list_uid, uid = value.to_s.split(PAYLOAD_SEPARATOR)
        State.get_task(list_uid, uid)
      end

      def on_drag_prepare
        task_list&.all_tasks&.each { |task| task.root.sensitive = true }
        root.sensitive = false
        Gdk::ContentProvider.new(GLib::Value.new(GLib::Type::STRING, payload))
      end

      def on_drag_end
        root.sensitive = true
        reset_drop_areas
      end

      def reset_drop_areas
        task_list&.all_tasks&.each do |task|
          task.top_drop_area.reveal_child = false
          task.root.sensitive = true
        end
      end

      # A task dropped on the "+" area above this one becomes its sibling,
      # ordered before it.
      def on_top_area_drop(value)
        dragged_task(value).then do |task|
          if task && task.root.next_sibling != root
            insert_before(task)
          end
        end
        true
      end

      def insert_before(task)
        task_data = task.task_data
        task_parent = task.parent
        old_task_list = task.task_list
        task.purge

        reparent(task_data, @task_data.parent, old_task_list)
        UserData.move_task_before(@list_uid, task_data.uid, @uid)
        update_dropped_parents(task_parent)

        task_data.completed = @task_data.completed
        new_task = @parent.add_task(task_data)
        root.parent.reorder_child_after(new_task.root, root)
        root.parent.reorder_child_after(root, new_task.root)

        reset_drop_areas
        update_dropped_parents(@parent)
        task_list&.update_title
      end

      # A task dropped on this one becomes its sub-task.
      def on_task_drop(value)
        dragged_task(value).then do |task|
          if task && task.parent != self
            adopt(task)
          end
        end
        true
      end

      def adopt(task)
        unless @task_data.expanded
          expand(true)
        end

        task_data = task.task_data
        task_parent = task.parent
        old_task_list = task.task_list
        task.purge

        reparent(task_data, @uid, old_task_list)
        UserData.move_task_after(@list_uid, task_data.uid, @uid)
        add_task(task_data)
        update_dropped_parents(task_parent)
        uncomplete_for_sub_task(task_data)

        task_list&.update_title
        update_title
        update_progress_bar
        reset_drop_areas
      end

      # Points a dropped task's record at its new parent, moving it between
      # lists first when the drop crossed lists.
      def reparent(task_data, new_parent, old_task_list)
        if task_data.list_uid == @list_uid
          UserData.update_props(
            @list_uid,
            task_data.uid,
            %i[parent synced],
            [new_parent, false],
          )
        else
          UserData.move_task_to_list(
            task_data.uid,
            task_data.list_uid,
            @list_uid,
            new_parent,
          ).then do |moved|
            task_data.list_uid = moved.list_uid
            task_data.parent = moved.parent
            task_data.uid = moved.uid
          end
          old_task_list&.update_title
        end
      end

      def update_dropped_parents(task_parent)
        if task_parent.is_a?(Task)
          task_parent.update_title
          task_parent.update_progress_bar
        end
      end

      def uncomplete_for_sub_task(task_data)
        if @task_data.completed && !task_data.completed
          complete_button.active = false
          parents_tree.each { |parent| parent.complete_button.active = false }
        end
      end
  end
end
