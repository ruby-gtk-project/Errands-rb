# frozen_string_literal: true

require 'adwaita'

require_relative 'rb/version'

module Errands
  # State is the application's global state: the core widgets other widgets
  # reach for, and the shortcuts to the deeper nested ones.
  #
  # Ported from upstream's errands/state.py, whose class attributes are
  # assigned by each widget's constructor and read from everywhere. The
  # constants upstream's meson build substitutes into errands.py are fixed
  # here, since this port is run from its checkout.
  #
  module State
    APP_ID = 'io.github.mrvladus.List'
    PROFILE = 'development'

    class << self
      attr_accessor :application,
        :main_window,
        :split_view,
        :view_stack,
        :loading_page,
        :sidebar,
        :notes_dialog,
        :datetime_dialog,
        :attachments_dialog,
        :today_page,
        :today_sidebar_row,
        :tags_page,
        :tags_sidebar_row,
        :trash_page,
        :trash_sidebar_row,
        :notifications

      def app_id = APP_ID

      def profile = PROFILE

      def version = Errands::Rb::VERSION

      # Builds the three dialogs upstream builds once and reuses for every
      # task, exactly as State.init does.
      def init
        self.notes_dialog = NotesDialog.new.tap(&:build)
        self.datetime_dialog = DatetimeDialog.new.tap(&:build)
        self.attachments_dialog = AttachmentsDialog.new.tap(&:build)
      end

      # All task lists.
      def task_lists = sidebar.task_lists

      def get_task_list(uid) = task_lists.find { |list| list.list_uid == uid }

      # All tasks in all task lists.
      def tasks = task_lists.flat_map(&:all_tasks)

      def get_task(list_uid, uid)
        tasks.find { |task| task.list_uid == list_uid && task.uid == uid }
      end

      def add_toast(text) = main_window.add_toast(text)
    end
  end
end
