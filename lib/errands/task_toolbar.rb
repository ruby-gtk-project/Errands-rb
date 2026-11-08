# frozen_string_literal: true

require 'adwaita'

require_relative 'color_selector'
require_relative 'data'
require_relative 'logging'
require_relative 'state'
require_relative 'titled_separator'
require_relative 'toolbar_tag_row'
require_relative 'translations'
require_relative 'utils'

module Errands
  # TaskToolbar is the row of buttons a task reveals: the date button, notes,
  # priority, tags, attachments and the overflow menu with the accent colours
  # and the created / changed timestamps.
  #
  # Ported from the ErrandsTaskToolbar class in upstream's
  # errands/widgets/shared/task_toolbar/toolbar.py.
  #
  class TaskToolbar
    PRIORITY_PRESETS = [
      ['High', 'error', 1],
      ['Medium', 'warning', 5],
      ['Low', 'accent', 9],
      ['None', nil, 0],
    ].freeze

    def initialize(task)
      @task = task
    end

    def build
      wrap_box.tap do |container|
        container.append(date_time_button)
        container.append(buttons_box)

        date_time_button.signal_connect('clicked') { State.datetime_dialog.show(@task) }

        buttons_box.tap do |box|
          box.append(notes_button)
          box.append(priority_button)
          box.append(tags_button)
          box.append(attachments_button)
          box.append(menu_button)

          notes_button.signal_connect('clicked') { State.notes_dialog.show(@task) }
          attachments_button.signal_connect('clicked') { State.attachments_dialog.show(@task) }
          priority_button.signal_connect('notify::active') { on_priority_button_toggled }
          tags_button.signal_connect('notify::active') { on_tags_button_toggled }
          menu_button.signal_connect('notify::active') { on_menu_toggled }
        end

        priority_popover.child = priority_box

        priority_box.tap do |box|
          box.append(priority_list)
          box.append(priority_separator.build)
          box.append(custom_priority_button)

          priority_list.tap do |list|
            PRIORITY_PRESETS.each { |label, css_class, _| list.append(priority_row(Translations.gettext(label), css_class)) }
            list.signal_connect('row-activated') { |_, row| on_priority_selected(row) }
          end
        end

        tags_popover.child = tags_scroller

        tags_scroller.tap do |scroller|
          scroller.child = tags_container

          tags_container.tap do |box|
            box.append(tags_list)
            box.append(tags_status_page)
          end
        end

        popover_menu.tap do |menu|
          menu.add_child(color_selector.build, 'color')
          menu.add_child(created_label, 'created')
          menu.add_child(changed_label, 'changed')
        end
      end
    end

    # Brings every button in step with the task's data.
    def update_ui
      date_time_content.label = Utils.human_datetime(@task.task_data.due_date)
      update_date_time_css
      update_notes_css
      update_priority_css
      update_attachments_css
    end

    # Memoized widget methods

    def wrap_box
      @wrap_box ||= Adwaita::WrapBox.new.tap do |container|
        container.margin_bottom = 6
        container.margin_start = 9
        container.margin_end = 9
        container.line_spacing = 6
      end
    end

    def buttons_box
      @buttons_box ||= Gtk::Box.new(:horizontal, 2).tap do |box|
        box.halign = :end
      end
    end

    def date_time_content
      @date_time_content ||= Adwaita::ButtonContent.new.tap do |content|
        content.icon_name = 'errands-calendar-symbolic'
        content.can_shrink = true
        content.label = Translations.gettext('Date')
      end
    end

    def date_time_button
      @date_time_button ||= Gtk::Button.new.tap do |button|
        button.valign = :center
        button.halign = :start
        button.hexpand = true
        button.tooltip_text = Translations.gettext('Start / Due Date')
        button.add_css_class('flat')
        button.add_css_class('caption')
        button.child = date_time_content
      end
    end

    def notes_button
      @notes_button ||= flat_icon_button('errands-notes-symbolic', Translations.gettext('Notes'))
    end

    def attachments_button
      @attachments_button ||= flat_icon_button('errands-attachment-symbolic', Translations.gettext('Attachments'))
    end

    def custom_priority_button
      @custom_priority_button ||= Gtk::SpinButton.new(
        Gtk::Adjustment.new(
          0,
          0,
          9,
          1,
          1,
          0,
        ),
        1,
        0,
      ).tap do |spin|
        spin.valign = :center
      end
    end

    def priority_separator = @priority_separator ||= TitledSeparator.new(Translations.gettext('Custom'))

    def priority_list
      @priority_list ||= Gtk::ListBox.new.tap do |list|
        list.selection_mode = :none
      end
    end

    def priority_box
      @priority_box ||= Gtk::Box.new(:vertical, 3).tap do |box|
        box.margin_top = 6
        box.margin_bottom = 6
        box.margin_start = 6
        box.margin_end = 6
      end
    end

    def priority_popover
      @priority_popover ||= Gtk::Popover.new.tap do |popover|
        popover.add_css_class('menu')
      end
    end

    def priority_button
      @priority_button ||= Gtk::MenuButton.new.tap do |button|
        button.valign = :center
        button.icon_name = 'errands-priority-symbolic'
        button.tooltip_text = Translations.gettext('Priority')
        button.add_css_class('flat')
        button.popover = priority_popover
      end
    end

    def tags_status_page
      @tags_status_page ||= Adwaita::StatusPage.new.tap do |page|
        page.title = Translations.gettext('No Tags')
        page.icon_name = 'errands-info-symbolic'
        page.add_css_class('compact')
      end
    end

    def tags_list
      @tags_list ||= Gtk::Box.new(:vertical, 6).tap do |box|
        box.margin_top = 6
        box.margin_bottom = 6
        box.margin_start = 6
        box.margin_end = 6
      end
    end

    def tags_container
      @tags_container ||= Gtk::Box.new(:vertical, 0).tap do |box|
        box.vexpand = true
        box.valign = :center
      end
    end

    def tags_scroller
      @tags_scroller ||= Gtk::ScrolledWindow.new.tap do |scroller|
        scroller.max_content_width = 200
        scroller.max_content_height = 200
        scroller.width_request = 200
        scroller.propagate_natural_height = true
        scroller.propagate_natural_width = true
        scroller.vexpand = true
      end
    end

    def tags_popover
      @tags_popover ||= Gtk::Popover.new.tap do |popover|
        popover.add_css_class('tags-menu')
      end
    end

    def tags_button
      @tags_button ||= Gtk::MenuButton.new.tap do |button|
        button.valign = :center
        button.icon_name = 'errands-tag-add-symbolic'
        button.tooltip_text = Translations.gettext('Tags')
        button.add_css_class('flat')
        button.popover = tags_popover
      end
    end

    def color_selector
      @color_selector ||= ColorSelector.new { |button, color| on_accent_color_selected(button, color) }
    end

    def created_label
      @created_label ||= Gtk::Label.new(Translations.gettext('Created:')).tap do |label|
        label.halign = :start
        label.margin_bottom = 6
        label.margin_start = 6
        label.margin_end = 6
        label.add_css_class('caption-heading')
      end
    end

    def changed_label
      @changed_label ||= Gtk::Label.new(Translations.gettext('Changed:')).tap do |label|
        label.halign = :start
        label.margin_start = 6
        label.margin_end = 6
        label.add_css_class('caption-heading')
      end
    end

    # The menu is two sections of custom widgets: the colour selector, then
    # the two timestamps.
    def menu_model
      @menu_model ||= Gio::Menu.new.tap do |menu|
        menu.append_section(nil, custom_section(%w[color]))
        menu.append_section(nil, custom_section(%w[created changed]))
      end
    end

    def popover_menu = @popover_menu ||= Gtk::PopoverMenu.new(menu_model)

    # The tag rows currently in the popover.
    def tag_rows = @tag_rows ||= []

    def menu_button
      @menu_button ||= Gtk::MenuButton.new.tap do |button|
        button.valign = :center
        button.icon_name = 'errands-more-symbolic'
        button.tooltip_text = Translations.gettext('More')
        button.add_css_class('flat')
        button.popover = popover_menu
      end
    end

    private

      def flat_icon_button(icon_name, tooltip)
        Gtk::Button.new.tap do |button|
          button.valign = :center
          button.icon_name = icon_name
          button.tooltip_text = tooltip
          button.add_css_class('flat')
        end
      end

      def custom_section(names)
        Gio::Menu.new.tap do |section|
          names.each do |name|
            section.append_item(
              Gio::MenuItem.new(nil, nil).tap do |item|
                item.set_attribute_value('custom', GLib::Variant.new(name))
              end,
            )
          end
        end
      end

      def priority_row(label, css_class)
        Gtk::ListBoxRow.new.tap do |row|
          row.child = Gtk::Label.new(label)
          if css_class
            row.add_css_class(css_class)
          end
        end
      end

      def update_date_time_css
        date_time_button.remove_css_class('error')
        due = @task.task_data.due_date
        unless due.to_s.empty?
          today = Time.now
          overdue = Utils.parse_datetime(due) < Time.new(today.year, today.month, today.day)
          if overdue
            date_time_button.add_css_class('error')
          end
        end
      end

      def update_notes_css
        if @task.task_data.notes.to_s.empty?
          notes_button.remove_css_class('accent')
        else
          notes_button.add_css_class('accent')
        end
      end

      def update_priority_css
        priority = @task.task_data.priority
        priority_button.css_classes = ['flat']
        if priority_css_class(priority)
          priority_button.add_css_class(priority_css_class(priority))
        end
        priority_button.icon_name = "errands-priority#{priority.positive? ? '-set' : ''}-symbolic"
      end

      def priority_css_class(priority)
        if priority.between?(1, 4)
          'error'
        elsif priority.between?(5, 8)
          'warning'
        elsif priority == 9
          'accent'
        end
      end

      def update_attachments_css
        attachments_button.remove_css_class('accent')
        if @task.task_data.attachments.length.positive?
          attachments_button.add_css_class('accent')
        end
      end

      def on_accent_color_selected(button, color)
        if button.active? && !@task.block_signals?
          Log.debug("Task: change color to '#{color}'")
          if color != @task.task_data.color
            @task.update_props(%i[color synced], [color == 'none' ? '' : color, false])
            @task.update_color
          end
        end
      end

      def on_menu_toggled
        if menu_button.active?
          created_label.label = "#{Translations.gettext('Created:')} #{timestamp(@task.task_data.created_at)}"
          changed_label.label = "#{Translations.gettext('Changed:')} #{timestamp(@task.task_data.changed_at)}"
          @task.block_signals = true
          color_selector.select_color(@task.task_data.color)
          @task.block_signals = false
        end
      end

      def timestamp(value) = Utils.parse_datetime(value).strftime('%Y.%m.%d %H:%M:%S')

      def on_priority_button_toggled
        if priority_button.active?
          custom_priority_button.value = @task.task_data.priority
        else
          store_priority(custom_priority_button.value_as_int)
        end
      end

      def store_priority(new_priority)
        if @task.task_data.priority != new_priority
          Log.debug("Task Toolbar: Set priority to '#{new_priority}'")
          @task.update_props(%i[priority synced], [new_priority, false])
          @task.update_toolbar
        end
      end

      def on_priority_selected(row)
        index = Utils.children(priority_list).index(row)
        custom_priority_button.value = PRIORITY_PRESETS[index][2]
        priority_button.popdown
      end

      def on_tags_button_toggled
        if tags_button.active?
          sync_tag_rows
          mark_task_tags
          any_tags = Utils.children(tags_list).length.positive?
          tags_list.visible = any_tags
          tags_status_page.visible = !any_tags
        end
      end

      def sync_tag_rows
        tags = UserData.tags
        tag_rows.each do |row|
          unless tags.include?(row.title)
            tags_list.remove(row.box)
          end
        end
        @tag_rows = tag_rows.select { |row| tags.include?(row.title) }
        tags.each do |tag|
          unless @tag_rows.map(&:title).include?(tag)
            ToolbarTagRow.new(tag, @task).tap do |row|
              tags_list.append(row.build)
              @tag_rows << row
            end
          end
        end
      end

      def mark_task_tags
        task_tags = @task.task_data.tags
        tag_rows.each { |row| row.active = task_tags.include?(row.title) }
      end

  end
end
