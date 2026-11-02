# frozen_string_literal: true

require 'adwaita'

module Errands
  # Style is the application's stylesheet.
  #
  # Ported from upstream's data/resources/style.css and
  # data/resources/style-dark.css, which meson packs into errands.gresource and
  # the application loads from there. This port has no gresource step, so the
  # same rules are embedded and handed to Gtk::CssProvider; the dark provider is
  # added and removed as the style manager's dark state changes, which is what
  # upstream's two separate resources amount to.
  #
  # Two substitutions were needed for GTK 4: the GTK 3 `darker()` CSS function
  # (gone in GTK 4) became `shade(color, 0.7)`, and the undefined `@background`
  # named colour became Adwaita's `@window_bg_color`.
  #
  module Style
    PRIORITY = Gtk::StyleProvider::PRIORITY_APPLICATION

    CSS = <<~CSS
      /* Sidebar */
      .sidebar-item {
        transition: background-color 0.2s;
      }

      .sidebar-item:drop(active) {
        background-color: @blue_1;
      }

      .sidebar-item-trash:drop(active) {
        background-color: @orange_1;
      }

      /* Task */

      .task-title:drop(active) {
        border-radius: 10px;
      }

      .task {
        padding: 0px;
        border-radius: 12px;
      }

      .task-expand-icon {
        transition: transform 0.25s;
      }

      .task-drop-area {
        padding: 8px;
        margin: 0px 0px 8px 0px;
        border-radius: 10px;
        border-width: 3px;
        border-style: dotted;
        border-color: @light_4;
      }

      .task-completed box.title {
        opacity: 0.5;
      }

      .task-completed label.title {
        text-decoration: line-through;
      }

      /* Task accent colors */

      .task-blue {
        background: #dde9f7;
      }

      .progressbar-blue progress,
      .checkbtn-blue check:checked {
        background-color: @blue_2;
      }


      .task-green {
        background: #daf7e0;
      }

      .progressbar-green progress,
      .checkbtn-green check:checked {
        background-color: @green_3;
      }

      .task-yellow {
        background: #faf7cf;
      }

      .progressbar-yellow progress,
      .checkbtn-yellow check:checked {
        background-color: @yellow_4;
      }

      .task-orange {
        background: #fce8d0;
      }

      .progressbar-orange progress,
      .checkbtn-orange check:checked {
        background-color: @orange_2;
      }

      .task-red {
        background: #f9ccc7;
      }

      .progressbar-red progress,
      .checkbtn-red check:checked {
        background-color: @red_1;
      }


      .task-purple {
        background: #f1d8f1;
      }

      .progressbar-purple progress,
      .checkbtn-purple check:checked {
        background-color: @purple_2;
      }

      .task-brown {
        background: #ece2da;
      }

      .progressbar-brown progress,
      .checkbtn-brown check:checked {
        background-color: @brown_2;
      }

      /* Accent color buttons */

      .accent-color-btn radio {
        all: unset;
        border: 2px solid transparent;
        border-radius: 9999px;
        min-width: 14px;
        min-height: 14px;
        color: @light_1;
      }

      .accent-color-btn radio:hover {
        filter: brightness(1.2);
      }

      .accent-color-btn radio:checked {
        -gtk-icon-transform: scale(0.7);
        -gtk-icon-source: -gtk-icontheme("errands-select-symbolic");
      }

      .accent-color-btn-none radio {
        border-color: alpha(@view_fg_color, 0.3);
      }

      .accent-color-btn-none radio:checked {
        color: @window_fg_color;
      }

      .accent-color-btn-blue radio {
        background-color: @blue_2;
      }

      .accent-color-btn-green radio {
        background-color: @green_2;
        color: @window_fg_color;
      }

      .accent-color-btn-yellow radio {
        background-color: @yellow_2;
        color: @window_fg_color;
      }

      .accent-color-btn-orange radio {
        background-color: @orange_2;
        color: @window_fg_color;
      }

      .accent-color-btn-red radio {
        background-color: @red_2;
      }

      .accent-color-btn-purple radio {
        background-color: @purple_2;
      }

      .accent-color-btn-brown radio {
        background-color: @brown_2;
      }

      /* Tag */

      .tag {
        border-radius: 5px;
        padding-top: 3px;
        padding-bottom: 3px;
        padding-left: 5px;
        padding-right: 5px;
        background-color: alpha(black, 0.07);
      }

      .tag>button {
        all: unset;
        margin-left: 6px;
      }

      .tags-menu contents {
        padding: 0px;
      }

      /* Sub-task */

      .sub-tasks:last-child {
        margin-bottom: 6px;
      }

      /* Utils */

      .rounded-corners {
        border-radius: 12px;
      }

      .transparent {
        background-color: transparent;
      }

      .fade {
        transition: 0.2s;
      }

      /* Expand indicator */

      .expand-indicator {
        transition: 0.2s;
      }

      .expand-indicator-expanded {
        transform: rotate(180deg);
      }

      /* Overrides */

      checkbutton check {
        transition: background-color 0.2s;
      }

      progressbar.osd {
        background-color: @shade_color;
      }

      textview text {
        background-color: @card_bg_color;
      }

      calendar {
        background: @window_bg_color;
      }

      calendar,
      calendar header {
        border: none;
      }

      colorbutton {
        transform: scale(0.6);
      }

      colorbutton button {
        border-radius: 9999px;
        margin: 0px;
        padding: 4px;
      }

      colorbutton button colorswatch {
        border-radius: 9999px;
      }
    CSS

    DARK_CSS = <<~CSS
      /* Task lists item */
      .task-lists-item:drop(active) {
          background-color: @blue_2;
      }

      .task-blue {
          background: shade(#3584e4, 0.7);
      }

      .progressbar-blue progress,
      .checkbtn-blue check:checked {
          background-color: @blue_2;
      }

      .task-green {
          background: shade(#33d17a, 0.7);
      }

      .progressbar-green progress,
      .checkbtn-green check:checked {
          background-color: @green_3;
      }

      .task-yellow {
          background: shade(#f5c211, 0.7);
      }

      .progressbar-yellow progress,
      .checkbtn-yellow check:checked {
          background-color: @yellow_4;
      }

      .task-orange {
          background: shade(#ff7800, 0.7);
      }

      .progressbar-orange progress,
      .checkbtn-orange check:checked {
          background-color: @orange_2;
      }

      .task-red {
          background: shade(#e01b24, 0.7);
      }

      .progressbar-red progress,
      .checkbtn-red check:checked {
          background-color: @red_1;
      }

      .task-purple {
          background: shade(#9141ac, 0.7);
      }

      .progressbar-purple progress,
      .checkbtn-purple check:checked {
          background-color: @purple_2;
      }

      .task-brown {
          background: #986a44;
      }

      .progressbar-brown progress,
      .checkbtn-brown check:checked {
          background-color: @brown_1;
      }

      .tag {
          background-color: alpha(white, 0.25);
      }

      link {
          color: white;
      }
    CSS

    class << self
      # Loads the stylesheet and keeps the dark additions in step with the
      # style manager.
      def install
        Gtk::StyleContext.add_provider_for_display(display, provider, PRIORITY)
        apply_dark(style_manager.dark?)
        style_manager.signal_connect('notify::dark') { apply_dark(style_manager.dark?) }
      end

      def provider
        @provider ||= Gtk::CssProvider.new.tap { |css| css.load(data: CSS) }
      end

      def dark_provider
        @dark_provider ||= Gtk::CssProvider.new.tap { |css| css.load(data: DARK_CSS) }
      end

      private

        def display = Gdk::Display.default

        def style_manager = Adwaita::StyleManager.default

        def apply_dark(dark)
          Gtk::StyleContext.remove_provider_for_display(display, dark_provider)
          if dark
            Gtk::StyleContext.add_provider_for_display(display, dark_provider, PRIORITY + 1)
          end
        end
    end
  end
end
