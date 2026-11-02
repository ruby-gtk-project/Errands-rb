# frozen_string_literal: true

require 'adwaita'

require_relative 'state'

module Errands
  # LoadingPage is the view stack page shown while the tasks are read.
  #
  # Ported from upstream's errands/widgets/loading_page.py.
  #
  class LoadingPage
    def build
      bin.tap do |root|
        root.child = toolbar_view

        toolbar_view.tap do |view|
          view.add_top_bar(header_bar)
          view.content = status_page
        end

        State.loading_page = self
      end
    end

    # Memoized widget methods

    def bin = @bin ||= Adwaita::Bin.new

    def toolbar_view = @toolbar_view ||= Adwaita::ToolbarView.new

    def header_bar
      @header_bar ||= Adwaita::HeaderBar.new.tap do |bar|
        bar.show_title = false
      end
    end

    def status_page
      @status_page ||= Adwaita::StatusPage.new.tap do |page|
        page.title = 'Loading Tasks...'
        page.icon_name = 'errands-progressbar-symbolic'
        page.vexpand = true
        page.add_css_class('compact')
      end
    end
  end
end
