# frozen_string_literal: true

require 'adwaita'
require 'securerandom'

require_relative 'data'
require_relative 'logging'
require_relative 'state'
require_relative 'translations'

module Errands
  # ImportDialog imports a task list from an iCal file.
  #
  # Ported from the _import action in upstream's errands/widgets/window.py: a
  # Gtk.FileDialog filtered to *.ics whose chosen file is parsed into a list
  # and its tasks, with the uid and the name made unique against the lists
  # already stored.
  #
  class ImportDialog
    def build
      file_dialog.tap do |dialog|
        dialog.default_filter = filter
      end
    end

    # Opens the file chooser and imports the file the user picks.
    def present(parent)
      build.open(parent, nil) do |_source, result|
        import(file_dialog.open_finish(result))
      rescue StandardError => e
        Log.debug("Lists: Import cancelled. #{e.message}")
      end
    end

    def self.show(parent) = new.present(parent)

    # Memoized widget methods

    def file_dialog = @file_dialog ||= Gtk::FileDialog.new

    def filter
      @filter ||= Gtk::FileFilter.new.tap do |pattern|
        pattern.add_pattern('*.ics')
        pattern.name = 'iCal'
      end
    end

    private

      def import(file)
        task_list, tasks = TaskListData.from_ical(File.read(file.path))
        deduplicate(task_list, tasks)
        new_list = UserData.add_list(task_list.name, uuid: task_list.uid, color: task_list.color)
        tasks.each { |task| UserData.add_task(**task.to_h.transform_keys(&:to_sym)) }
        State.sidebar.add_task_list(new_list)
        State.main_window.add_toast(Translations.gettext('Imported'))
      end

      # Upstream gives an imported list a fresh uid when one of its own lists
      # already has it, and suffixes a clashing name with the uid.
      def deduplicate(task_list, tasks)
        stored = UserData.lists_as_dicts
        if stored.map(&:uid).include?(task_list.uid)
          task_list.uid = SecureRandom.uuid
          tasks.each { |task| task.list_uid = task_list.uid }
        end
        if stored.map(&:name).include?(task_list.name)
          task_list.name = "#{task_list.name}_#{task_list.uid}"
        end
      end
  end
end
