# frozen_string_literal: true

require 'adwaita'

require_relative 'confirm_dialog'
require_relative 'data'
require_relative 'logging'
require_relative 'state'
require_relative 'trash_item'
require_relative 'utils'

module Errands
  # Trash is the "Trash" page: every task marked trashed and not deleted,
  # each restorable on its own, with Clear and Restore-all buttons.
  #
  # Ported from the Trash class in upstream's errands/widgets/trash/trash.py.
  #
  class Trash
    def initialize
      @items = []
    end

    def root = bin

    def build
      bin.tap do |root|
        State.trash_page = self
        root.child = toolbar_view

        toolbar_view.tap do |view|
          view.add_top_bar(header_bar)
          view.content = content_box

          header_bar.tap do |bar|
            bar.title_widget = window_title
            bar.pack_start(clear_button)
            bar.pack_end(restore_button)

            clear_button.signal_connect('clicked') { on_trash_clear }
            restore_button.signal_connect('clicked') { on_trash_restore }
          end

          content_box.tap do |box|
            box.append(status_page)
            box.append(scroller)

            trash_list.bind_property(
              'visible',
              status_page,
              'visible',
              GLib::BindingFlags::SYNC_CREATE | GLib::BindingFlags::INVERT_BOOLEAN,
            )
            status_page.bind_property(
              'visible',
              clear_button,
              'visible',
              GLib::BindingFlags::SYNC_CREATE | GLib::BindingFlags::INVERT_BOOLEAN,
            )
            status_page.bind_property(
              'visible',
              restore_button,
              'visible',
              GLib::BindingFlags::SYNC_CREATE | GLib::BindingFlags::INVERT_BOOLEAN,
            )

            scroller.child = clamp
            clamp.child = trash_list
          end
        end
      end

      update_ui
      root
    end

    # ------ PROPERTIES ------ #

    def trash_items = @items

    # ------ PUBLIC METHODS ------ #

    def add_trash_item(task_data)
      TrashItem.new(task_data).tap do |item|
        @items << item
        trash_list.append(item.build)
        status_page.visible = false
      end
    end

    def update_ui
      tasks_data = UserData.tasks_as_dicts.select { |t| t.trash && !t.deleted }
      tasks_uids = tasks_data.map(&:uid)
      items_uids = @items.map { |item| item.task_data.uid }

      tasks_data.each do |task_data|
        unless items_uids.include?(task_data.uid)
          add_trash_item(task_data)
        end
      end

      @items.dup.each do |item|
        if tasks_uids.include?(item.task_data.uid)
          item.update_ui
        else
          trash_list.remove(item.row)
          @items.delete(item)
        end
      end

      status_page.visible = @items.empty?
    end

    def on_trash_clear
      ConfirmDialog.show(
        'Tasks will be permanently deleted',
        'Delete',
        :destructive,
      ) do |response|
        if response == 'confirm'
          Log.info('Trash: Clear')
          UserData.delete_tasks_from_trash
          State.trash_sidebar_row.update_ui
          State.today_page.update_ui
        else
          Log.debug('Trash: Clear cancelled')
        end
      end
    end

    def on_trash_restore
      Log.info('Trash: Restore')
      @items.dup.each(&:restore)
    end

    # Memoized widget methods

    def bin = @bin ||= Adwaita::Bin.new

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new

    def header_bar = @header_bar ||= Adwaita::HeaderBar.new

    def window_title = @window_title ||= Adwaita::WindowTitle.new('Trash', '')

    def clear_button
      @clear_button ||= Gtk::Button.new.tap do |button|
        button.tooltip_text = 'Clear'
        button.icon_name = 'errands-trash-symbolic'
        button.valign = :center
        button.add_css_class('flat')
      end
    end

    def restore_button
      @restore_button ||= Gtk::Button.new.tap do |button|
        button.tooltip_text = 'Restore'
        button.icon_name = 'errands-restore-symbolic'
        button.valign = :center
        button.add_css_class('flat')
      end
    end

    def content_box = @content_box ||= Gtk::Box.new(:vertical, 0)

    def status_page
      @status_page ||= Adwaita::StatusPage.new.tap do |page|
        page.title = 'Empty Trash'
        page.description = 'No deleted items'
        page.icon_name = 'errands-trash-symbolic'
        page.vexpand = true
        page.add_css_class('compact')
      end
    end

    def scroller
      @scroller ||= Gtk::ScrolledWindow.new.tap do |window|
        window.propagate_natural_height = true
      end
    end

    def clamp
      @clamp ||= Adwaita::Clamp.new.tap do |c|
        c.maximum_size = 1000
        c.tightening_threshold = 300
      end
    end

    def trash_list
      @trash_list ||= Gtk::ListBox.new.tap do |list|
        list.selection_mode = :none
        list.margin_bottom = 32
        list.margin_end = 12
        list.margin_start = 12
        list.add_css_class('transparent')
      end
    end
  end
end
