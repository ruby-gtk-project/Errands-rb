# frozen_string_literal: true

require 'adwaita'

require_relative 'add_list_dialog'
require_relative 'data'
require_relative 'logging'
require_relative 'settings'
require_relative 'state'
require_relative 'tags_sidebar_row'
require_relative 'task_list_sidebar_row'
require_relative 'titled_separator'
require_relative 'today_sidebar_row'
require_relative 'translations'
require_relative 'trash_sidebar_row'
require_relative 'utils'

module Errands
  # Sidebar lists the Today, Tags and Trash rows, the task lists and holds
  # the main menu.
  #
  # Ported from the Sidebar class in upstream's errands/widgets/sidebar.py.
  #
  # Upstream also gives its add-list button a managed Gtk.ShortcutController so
  # Ctrl+Shift+A activates it; Gtk::ShortcutTrigger.parse_string has no Ruby
  # binding, so the window binds that accelerator to an application action
  # which calls the same handler.
  #
  class Sidebar
    def initialize
      @rows = []
    end

    def root = bin

    def build
      bin.tap do |root|
        root.child = toolbar_view
        State.sidebar = self

        toolbar_view.tap do |view|
          view.add_top_bar(header_bar)
          view.content = content_box

          header_bar.tap do |bar|
            bar.title_widget = title_label
            bar.pack_start(add_list_button)
            bar.pack_end(menu_button)
            bar.pack_end(sync_indicator_revealer)

            add_list_button.signal_connect('clicked') { add_list }
          end

          content_box.tap do |box|
            box.append(scroller)
            box.append(status_page)

            scroller.child = list_box

            list_box.tap do |list|
              list.append(today_sidebar_row.build)
              list.append(tags_sidebar_row.build)
              list.append(trash_sidebar_row.build)

              list.signal_connect('row-selected') { |_, selected_row| selected_row&.activate }
              list.set_header_func { |row, before| add_header(row, before) }
            end
          end
        end
      end
    end

    # ------ PROPERTIES ------ #

    # All rows, in the order the list box holds them.
    def rows
      Utils.children(list_box).filter_map { |widget| @rows.find { |row| row.row == widget } }
    end

    def task_lists_rows = rows

    def task_lists = task_lists_rows.map(&:task_list)

    # ------ PUBLIC METHODS ------ #

    def add_task_list(list_data)
      Log.debug("Sidebar: Add Task List '#{list_data.uid}'")
      TaskListSidebarRow.new(list_data).tap do |row|
        @rows << row
        list_box.append(row.build)
        status_page.visible = false
      end
    end

    def load_task_lists
      Log.debug('Sidebar: Load Task Lists')
      added = UserData.lists_as_dicts.reject(&:deleted).map { |list_data| add_task_list(list_data) }
      select_last_opened_item
      unless added.empty?
        status_page.visible = false
      end
    end

    def remove_task_list(row)
      Log.debug("Sidebar: Delete list #{row.uid}")
      list_box.select_row(row.row.prev_sibling)
      State.view_stack.remove(row.task_list.root)
      list_box.remove(row.row)
      @rows.delete(row)
      update_status
    end

    # Adds the lists that appeared in the data and drops the ones that went.
    def update_task_lists(update_lists_ui = true)
      lists = UserData.lists_as_dicts.reject(&:deleted)
      uids = lists.map(&:uid)

      rows.each do |row|
        unless uids.include?(row.uid)
          remove_task_list(row)
        end
      end

      shown = rows.map(&:uid)
      lists.each do |list_data|
        unless shown.include?(list_data.uid)
          add_task_list(list_data)
        end
      end

      if update_lists_ui
        rows.each(&:update_ui)
      end
    end

    def update_status
      status_page.visible = rows.empty?
      if rows.empty?
        State.view_stack.visible_child_name = 'errands_status_page'
      end
    end

    def update_ui
      Log.debug('Sidebar: Update UI')
      update_task_lists
      rows.each(&:update_ui)
      update_status
    end

    # Opens the "Add List" dialog. The window's Ctrl+Shift+A action and the
    # "No Task Lists" page's button both come here.
    def add_list
      AddListDialog.show do |name|
        add_task_list(UserData.add_list(name)).row.activate
      end
    end

    # Shows or hides the header's syncing spinner. Sync.sync calls this
    # through Utils.idle_add, so it always runs on the UI thread.
    def toggle_sync_indicator(on) = sync_indicator_revealer.reveal_child = on

    # Memoized widget methods

    def bin = @bin ||= Adwaita::Bin.new

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new

    def header_bar = @header_bar ||= Adwaita::HeaderBar.new

    def title_label
      @title_label ||= Gtk::Label.new(Translations.gettext('Errands')).tap do |label|
        label.add_css_class('heading')
      end
    end

    def add_list_button
      @add_list_button ||= Gtk::Button.new.tap do |button|
        button.icon_name = 'errands-add-symbolic'
        button.tooltip_text = Translations.gettext('Add List (Ctrl+Shift+A)')
      end
    end

    def menu_model
      @menu_model ||= Gio::Menu.new.tap do |menu|
        menu.append_section(nil, sync_section)
        menu.append_section(nil, import_section)
        menu.append_section(nil, application_section)
      end
    end

    def menu_button
      @menu_button ||= Gtk::MenuButton.new.tap do |button|
        button.primary = true
        button.tooltip_text = Translations.gettext('Main Menu')
        button.icon_name = 'open-menu-symbolic'
        button.menu_model = menu_model
      end
    end

    def sync_indicator_revealer
      @sync_indicator_revealer ||= Gtk::Revealer.new.tap do |revealer|
        revealer.transition_type = :crossfade
        revealer.transition_duration = 200
        revealer.reveal_child = false
        revealer.child = sync_spinner
      end
    end

    def sync_spinner
      @sync_spinner ||= Gtk::Spinner.new.tap do |spinner|
        spinner.spinning = true
        spinner.tooltip_text = Translations.gettext('Syncing...')
      end
    end

    def content_box = @content_box ||= Gtk::Box.new(:vertical, 0)

    def scroller
      @scroller ||= Gtk::ScrolledWindow.new.tap do |window|
        window.propagate_natural_height = true
      end
    end

    def list_box
      @list_box ||= Gtk::ListBox.new.tap do |list|
        list.activate_on_single_click = false
        list.selection_mode = :single
        list.add_css_class('navigation-sidebar')
      end
    end

    def status_page
      @status_page ||= Adwaita::StatusPage.new.tap do |page|
        page.title = Translations.gettext('Add new List')
        page.description = Translations.gettext('Click "+" button')
        page.icon_name = 'errands-lists-symbolic'
        page.vexpand = true
        page.add_css_class('compact')
      end
    end

    def today_sidebar_row = @today_sidebar_row ||= TodaySidebarRow.new

    def tags_sidebar_row = @tags_sidebar_row ||= TagsSidebarRow.new

    def trash_sidebar_row = @trash_sidebar_row ||= TrashSidebarRow.new

    private

      def sync_section
        Gio::Menu.new.tap do |section|
          section.append(Translations.gettext('Sync / Fetch Tasks'), 'app.sync')
        end
      end

      def import_section
        Gio::Menu.new.tap do |section|
          section.append(Translations.gettext('Import Task List'), 'app.import')
        end
      end

      def application_section
        Gio::Menu.new.tap do |section|
          section.append(Translations.gettext('Preferences'), 'app.preferences')
          section.append(Translations.gettext('Keyboard Shortcuts'), 'app.shortcuts')
          section.append(Translations.gettext('About Errands'), 'app.about')
          section.append(Translations.gettext('Quit'), 'app.quit')
        end
      end

      # The first task list row carries the "Task Lists" rule above it: any
      # row whose predecessor is nil (only possible if there are no fixed
      # rows) or is not itself a task list row.
      def add_header(row, before)
        if task_list_row?(row) && !task_list_row?(before)
          TitledSeparator.new(Translations.gettext('Task Lists'), [12, 12, 0, 2]).then { |header| row.header = header.build }
        end
      end

      def task_list_row?(widget)
        !widget.nil? && @rows.any? { |tracked| tracked.row == widget }
      end

      def select_last_opened_item
        rows.find { |row| row.name == Settings.get('last-open-list') }.then do |row|
          if row
            Log.debug('Sidebar: Select last opened page')
            select_when_realized(row)
          end
        end
      end

      def select_when_realized(row)
        if row.row.realized?
          list_box.select_row(row.row)
        else
          row.row.signal_connect('realize') { list_box.select_row(row.row) }
        end
      end
  end
end
