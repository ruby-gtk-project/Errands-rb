# frozen_string_literal: true

require 'adwaita'
require 'date'

require_relative 'data'
require_relative 'logging'
require_relative 'state'
require_relative 'today_task'
require_relative 'translations'
require_relative 'utils'

module Errands
  # Today is the "Today" page: every task due today or earlier, across every
  # list, that is not completed, trashed or deleted.
  #
  # Ported from the Today class in upstream's
  # errands/widgets/today/today.py.
  #
  class Today
    def root = bin

    def build
      bin.tap do |root|
        State.today_page = self
        root.child = toolbar_view

        toolbar_view.tap do |view|
          view.add_top_bar(header_bar)
          view.content = content_box

          content_box.tap do |box|
            box.append(status_page)
            box.append(scroller)

            status_page.bind_property(
              'visible',
              scroller,
              'visible',
              GLib::BindingFlags::SYNC_CREATE | GLib::BindingFlags::INVERT_BOOLEAN,
            )

            scroller.child = clamp
            clamp.child = task_list
          end
        end
      end

      update_ui
      root
    end

    # ------ PROPERTIES ------ #

    def tasks = Utils.children(task_list).filter_map { |widget| @task_widgets&.find { |t| t.root == widget } }

    def tasks_data
      today = Date.today
      UserData.tasks.select do |t|
        !t.deleted && !t.completed && !t.trash && !t.due_date.to_s.empty? && (Date.parse(t.due_date) <= today)
      end
    end

    # ------ PUBLIC METHODS ------ #

    def add_task(task_data)
      @task_widgets ||= []
      TodayTask.new(task_data, self).tap do |today_task|
        @task_widgets << today_task
        task_list.append(today_task.build)
        status_page.visible = false
      end
    end

    def update_status
      total = tasks_data.length
      status_page.visible = total.zero?
      if total.positive?
        State.today_sidebar_row.size_counter.label = total.to_s
      else
        State.today_sidebar_row.size_counter.label = ''
      end
    end

    def update_ui
      Log.debug('Today Page: Update UI')
      @task_widgets ||= []
      data = tasks_data
      data_uids = data.map(&:uid)
      widget_uids = tasks.map(&:uid)

      data.each do |task_data|
        unless widget_uids.include?(task_data.uid)
          add_task(task_data)
        end
      end

      tasks.each do |today_task|
        unless data_uids.include?(today_task.uid)
          today_task.purge
        end
      end

      tasks.each(&:update_ui)
      update_status
    end

    # Memoized widget methods

    def bin = @bin ||= Adwaita::Bin.new

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new

    def header_bar = @header_bar ||= Adwaita::HeaderBar.new.tap { |bar| bar.title_widget = window_title }

    def window_title = @window_title ||= Adwaita::WindowTitle.new(Translations.gettext('Today'), '')

    def content_box = @content_box ||= Gtk::Box.new(:vertical, 0)

    def status_page
      @status_page ||= Adwaita::StatusPage.new.tap do |page|
        page.title = Translations.gettext('No Tasks for Today')
        page.icon_name = 'errands-info-symbolic'
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

    def task_list = @task_list ||= Gtk::Box.new(:vertical, 0).tap { |box| box.margin_bottom = 32 }
  end
end
