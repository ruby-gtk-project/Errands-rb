# frozen_string_literal: true

require 'adwaita'

require_relative 'data'
require_relative 'logging'
require_relative 'state'
require_relative 'tag_row'
require_relative 'translations'
require_relative 'utils'

module Errands
  # Tags is the "Tags" page: every tag in use, with an entry to add new
  # ones and, on each row, a count of the tasks that carry it.
  #
  # Ported from the Tags class in upstream's errands/widgets/tags/tags.py.
  #
  class Tags
    def initialize
      @rows = []
    end

    def root = bin

    def build
      bin.tap do |root|
        State.tags_page = self
        root.child = toolbar_view

        toolbar_view.tap do |view|
          view.add_top_bar(header_bar)
          view.content = content_box

          content_box.tap do |box|
            box.append(status_page)
            box.append(entry_clamp)
            box.append(scroller)

            entry_clamp.child = entry_list_box
            entry_list_box.append(entry_row)
            entry_row.signal_connect('entry-activated') { on_tag_added }

            scroller.bind_property(
              'visible',
              status_page,
              'visible',
              GLib::BindingFlags::SYNC_CREATE | GLib::BindingFlags::INVERT_BOOLEAN,
            )

            scroller.child = clamp
            clamp.child = tags_list
          end
        end
      end

      UserData.tags.each { |tag| add_row(tag) }
      update_ui
      root
    end

    # ------ PROPERTIES ------ #

    def rows = @rows

    # ------ PUBLIC METHODS ------ #

    def update_ui(update_tag_rows = true)
      UserData.update_tags
      stored = UserData.tags

      rows.select { |row| !stored.include?(row.title) }.each { |row| remove_row(row) }

      shown = rows.map(&:title)
      stored.each do |tag|
        unless shown.include?(tag)
          add_row(tag)
        end
      end

      if update_tag_rows
        tags_in_tasks = UserData.tasks.map(&:tags).reject(&:empty?)
        rows.each { |row| row.update_ui(tags_in_tasks) }
      end

      tags_list.visible = !rows.empty?
      if State.main_window
        State.tags_sidebar_row.update_ui
      end
    end

    # Memoized widget methods

    def bin = @bin ||= Adwaita::Bin.new

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new

    def header_bar = @header_bar ||= Adwaita::HeaderBar.new.tap { |bar| bar.title_widget = window_title }

    def window_title = @window_title ||= Adwaita::WindowTitle.new(Translations.gettext('Tags'), '')

    def content_box = @content_box ||= Gtk::Box.new(:vertical, 0)

    def status_page
      @status_page ||= Adwaita::StatusPage.new.tap do |page|
        page.title = Translations.gettext('No Tags Found')
        page.description = Translations.gettext('Add new Tags in the entry above')
        page.icon_name = 'errands-info-symbolic'
        page.vexpand = true
        page.add_css_class('compact')
      end
    end

    def entry_clamp
      @entry_clamp ||= Adwaita::Clamp.new.tap do |c|
        c.maximum_size = 1000
        c.tightening_threshold = 300
      end
    end

    def entry_list_box
      @entry_list_box ||= Gtk::ListBox.new.tap do |list|
        list.selection_mode = :none
        list.margin_bottom = 6
        list.margin_start = 12
        list.margin_end = 12
        list.add_css_class('boxed-list')
      end
    end

    def entry_row
      @entry_row ||= Adwaita::EntryRow.new.tap do |row|
        row.title = Translations.gettext('Add new Tag')
        row.activatable = false
        row.height_request = 60
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

    def tags_list
      @tags_list ||= Gtk::ListBox.new.tap do |list|
        list.selection_mode = :none
        list.margin_bottom = 32
        list.margin_end = 12
        list.margin_start = 12
        list.margin_top = 6
        list.add_css_class('boxed-list')
      end
    end

    private

      def add_row(tag)
        TagRow.new(tag, self).tap do |row|
          @rows << row
          tags_list.append(row.build)
        end
      end

      def remove_row(row)
        tags_list.remove(row.row)
        @rows.delete(row)
      end

      def on_tag_added
        text = entry_row.text.strip.gsub(/\A,+|,+\z/, '')
        unless text.strip.empty? || UserData.tags.include?(text)
          add_row(text)
          UserData.add_tag(text)
          entry_row.text = ''
          update_ui
        end
      end
  end
end
