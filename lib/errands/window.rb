# frozen_string_literal: true

require 'adwaita'

require_relative 'about_dialog'
require_relative 'data'
require_relative 'import_dialog'
require_relative 'loading_page'
require_relative 'logging'
require_relative 'settings'
require_relative 'shortcuts_dialog'
require_relative 'sidebar'
require_relative 'state'

module Errands
  # Window is the main window: the sidebar beside the view stack, the toasts
  # over both, and the application's actions.
  #
  # Ported from the Window class in upstream's errands/widgets/window.py.
  #
  # The syncing page, the Today, Tags and Trash pages and the sync action
  # arrive with the components behind them; the window wires what exists.
  #
  class Window
    MIN_WIDTH = 360
    MIN_HEIGHT = 200
    COLLAPSE_WIDTH = 600
    COLOR_SCHEMES = %i[default force_light prefer_light prefer_dark force_dark].freeze

    ACTIONS = {
      'import'    => ['<primary>i'],
      'about'     => [],
      'shortcuts' => ['<primary>question'],
      'add-list'  => ['<primary><Shift>a'],
      'quit'      => ['<primary>q', '<primary>w'],
    }.freeze

    def initialize(application)
      @application = application
    end

    def root = window

    def build
      window.tap do |win|
        Log.debug('Main Window: Load')
        State.main_window = self
        win.content = toast_overlay
        win.add_breakpoint(collapse_breakpoint)

        toast_overlay.child = split_view

        split_view.tap do |view|
          view.sidebar = sidebar_page
          view.content = content_page
        end

        view_stack.tap do |stack|
          stack.add_titled(loading_page.build, 'errands_loading_page', 'Loading Tasks')
          stack.add_titled(status_page_view.build, 'errands_status_page', 'Create new List')
        end

        status_page_button.signal_connect('clicked') { sidebar.add_list }

        remember_window_state
        apply_theme
        create_actions
        finish_load
      end
    end

    def present = window.present

    def add_toast(text) = toast_overlay.add_toast(Adwaita::Toast.new(text))

    # Memoized widget methods

    def window
      @window ||= Adwaita::ApplicationWindow.new(@application).tap do |win|
        win.title = 'Errands'
        win.width_request = MIN_WIDTH
        win.height_request = MIN_HEIGHT
      end
    end

    def toast_overlay = @toast_overlay ||= Adwaita::ToastOverlay.new

    # The breakpoint upstream adds: below 600px the split view collapses to one
    # pane.
    def collapse_breakpoint
      @collapse_breakpoint ||= Adwaita::Breakpoint.new(
        Adwaita::BreakpointCondition.parse("max-width: #{COLLAPSE_WIDTH}px"),
      ).tap do |breakpoint|
        breakpoint.add_setter(split_view, 'collapsed', true)
      end
    end

    def view_stack = @view_stack ||= Adwaita::ViewStack.new

    def split_view
      @split_view ||= Adwaita::NavigationSplitView.new.tap do |view|
        view.show_content = true
        view.max_sidebar_width = 300
        view.min_sidebar_width = 200
      end
    end

    def sidebar = @sidebar ||= Sidebar.new

    def sidebar_page = @sidebar_page ||= Adwaita::NavigationPage.new(sidebar.build, 'Sidebar')

    def content_page
      @content_page ||= Adwaita::NavigationPage.new(view_stack, 'Content').tap do |page|
        page.width_request = MIN_WIDTH
      end
    end

    def loading_page = @loading_page ||= LoadingPage.new

    # The "No Task Lists" page, which is what the window shows until a list is
    # selected.
    def status_page_view = @status_page_view ||= StatusPageView.new(status_page_button)

    def status_page_button
      @status_page_button ||= Gtk::Button.new(label: 'Create List').tap do |button|
        button.halign = :center
        button.add_css_class('pill')
        button.add_css_class('suggested-action')
      end
    end

    def about_dialog = @about_dialog ||= AboutDialog.new.tap(&:build)

    def shortcuts_dialog = @shortcuts_dialog ||= ShortcutsDialog.new.tap(&:build)

    private

      def finish_load
        State.view_stack = view_stack
        State.split_view = split_view
        view_stack.visible_child_name = 'errands_status_page'
        sidebar.load_task_lists
      end

      def remember_window_state
        Settings.bind('width', window, 'default-width')
        Settings.bind('height', window, 'default-height')
        Settings.bind('maximized', window, 'maximized')
        Settings.bind('run-in-background', window, 'hide-on-close')
      end

      def apply_theme
        Adwaita::StyleManager.default.color_scheme = COLOR_SCHEMES.fetch(Settings.get('theme'), :default)
      end

      def create_actions
        ACTIONS.each do |name, accelerators|
          create_action(name, accelerators)
        end
      end

      def create_action(name, accelerators)
        Gio::SimpleAction.new(name).tap do |action|
          action.signal_connect('activate') { run_action(name) }
          @application.add_action(action)
          unless accelerators.empty?
            @application.set_accels_for_action("app.#{name}", accelerators)
          end
        end
      end

      def run_action(name)
        case name
        when 'import' then ImportDialog.show(window)
        when 'about' then about_dialog.present(window)
        when 'shortcuts' then shortcuts_dialog.present(window)
        when 'add-list' then sidebar.add_list
        when 'quit' then @application.quit
        end
      end
  end

  # StatusPageView is the view stack page shown while no list is selected: the
  # "No Task Lists" status page over a button that opens the add-list dialog.
  #
  # Ported from the errands_status_page child of the view stack in upstream's
  # errands/widgets/window.py.
  #
  class StatusPageView
    def initialize(button)
      @button = button
    end

    def build
      toolbar_view.tap do |view|
        view.add_top_bar(header_bar)
        view.content = content_box

        content_box.tap do |box|
          box.append(status_page)
          box.append(@button)
        end
      end
    end

    # Memoized widget methods

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new

    def header_bar
      @header_bar ||= Adwaita::HeaderBar.new.tap do |bar|
        bar.show_title = false
      end
    end

    def content_box
      @content_box ||= Gtk::Box.new(:vertical, 0).tap do |box|
        box.hexpand = true
        box.valign = :center
      end
    end

    def status_page
      @status_page ||= Adwaita::StatusPage.new.tap do |page|
        page.title = 'No Task Lists'
        page.description = 'Create new or import existing one'
        page.icon_name = 'io.github.mrvladus.List-symbolic'
      end
    end
  end
end
