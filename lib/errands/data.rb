# frozen_string_literal: true

require 'adwaita'
require 'json'
require 'fileutils'
require 'securerandom'

require_relative 'logging'
require_relative 'settings'
require_relative 'utils'

module Errands
  # TaskListData is one task list's stored record.
  #
  # Ported from the TaskListData dataclass in upstream's errands/lib/data.py,
  # including its iCal serialisation.
  #
  class TaskListData
    ATTRIBUTES = %i[color deleted name show_completed synced uid].freeze

    attr_accessor(*ATTRIBUTES)

    def initialize(color: '', deleted: false, name: '', show_completed: true, synced: false, uid: '')
      @color = color
      @deleted = deleted
      @name = name
      @show_completed = show_completed
      @synced = synced
      @uid = uid
      normalize
    end

    def to_h = ATTRIBUTES.to_h { |attribute| [attribute.to_s, public_send(attribute)] }

    def self.from_h(hash)
      new(**hash.transform_keys(&:to_sym).slice(*ATTRIBUTES))
    end

    # Builds a VCALENDAR holding either one VTODO component or every task of
    # this list.
    def to_ical(single_task = nil)
      String.new.tap do |ical|
        ical << "BEGIN:VCALENDAR\n"
        ical << "VERSION:2.0\n"
        ical << "PROID:-//Errands\n"
        ical << "X-WR-CALNAME:#{name}\n"
        ical << "X-APPLE-CALENDAR-COLOR:#{color}\n"
        ical << "X-ERRANDS-LIST-UID:#{uid}\n"
        if single_task
          ical << single_task
        else
          UserData.tasks_as_dicts(uid).each { |task| ical << task.to_ical }
        end
        ical << 'END:VCALENDAR'
      end
    end

    # Reads a VCALENDAR back into a list record and its tasks.
    def self.from_ical(ical)
      task_list = new
      ical.to_s.split('BEGIN:')[1].to_s.each_line do |line|
        prop = line.split(':').first.to_s
        value = line.split(':').last.to_s.strip
        if prop.include?('X-WR-CALNAME')
          task_list.name = value
        end
        if prop.include?('X-APPLE-CALENDAR-COLOR')
          task_list.color = value
        end
        if prop.include?('X-ERRANDS-LIST-UID')
          task_list.uid = value
        end
      end
      if task_list.name.to_s.empty?
        task_list.name = 'New Task List'
      end

      tasks = ical.to_s.split('BEGIN:VTODO')[1..].to_a.map do |todo|
        TaskData.from_ical("BEGIN:VTODO\n#{todo}", task_list.uid)
      end

      [task_list, tasks]
    end

    private

      def normalize
        if @uid.to_s.empty?
          @uid = SecureRandom.uuid
        end
        if @color.to_s.empty?
          @color = Utils.random_hex_color
        end
      end
  end

  # TaskData is one task's stored record.
  #
  # Ported from the TaskData dataclass in upstream's errands/lib/data.py,
  # including its iCal serialisation.
  #
  class TaskData
    ATTRIBUTES = %i[
      attachments color completed changed_at created_at deleted due_date expanded list_uid
      notes notified parent percent_complete priority rrule start_date synced tags text
      toolbar_shown trash uid
    ].freeze

    attr_accessor(*ATTRIBUTES)

    def initialize(**options)
      ATTRIBUTES.each { |attribute| instance_variable_set(:"@#{attribute}", defaults[attribute]) }
      options.slice(*ATTRIBUTES).each { |key, value| instance_variable_set(:"@#{key}", value) }
      normalize
    end

    def to_h = ATTRIBUTES.to_h { |attribute| [attribute.to_s, public_send(attribute)] }

    def self.from_h(hash)
      new(**hash.transform_keys(&:to_sym).slice(*ATTRIBUTES))
    end

    def to_ical(as_calendar: false)
      ical = vtodo
      if as_calendar
        UserData.get_list(list_uid).to_ical(ical)
      else
        ical
      end
    end

    def self.from_ical(ical, list_uid)
      new(list_uid: list_uid).tap do |task|
        body = ical.to_s
        body = body[(body.index('BEGIN:VTODO') || 0)...(body.index('END:VTODO') || body.length)]
        body.each_line { |line| task.apply_ical_line(line) }
      end
    end

    # Applies one "PROPERTY:value" line of a VTODO component.
    def apply_ical_line(line)
      prop = line.split(':').first.to_s
      value = line.split(':').last.to_s.strip
      ical_setters.each do |matcher, setter|
        if matcher.call(prop)
          setter.call(value)
        end
      end
    end

    private

      def defaults
        {
          attachments:      [],
          color:            '',
          completed:        false,
          changed_at:       '',
          created_at:       '',
          deleted:          false,
          due_date:         '',
          expanded:         false,
          list_uid:         '',
          notes:            '',
          notified:         false,
          parent:           '',
          percent_complete: 0,
          priority:         0,
          rrule:            '',
          start_date:       '',
          synced:           false,
          tags:             [],
          text:             '',
          toolbar_shown:    false,
          trash:            false,
          uid:              '',
        }
      end

      def normalize
        now = Time.now.strftime('%Y%m%dT%H%M%S')
        if @created_at.to_s.empty?
          @created_at = now
        end
        if @changed_at.to_s.empty?
          @changed_at = now
        end
      end

      def vtodo
        String.new.tap do |ical|
          ical << "BEGIN:VTODO\n"
          ical << "X-ERRANDS-COLOR:#{color}\n"
          ical << "STATUS:#{completed ? 'COMPLETED' : 'NEEDS-ACTION'}\n"
          ical << "LAST-MODIFIED:#{changed_at}\n"
          ical << "DTSTAMP:#{created_at}\n"
          unless due_date.to_s.empty?
            ical << "DUE#{due_date.include?('T') ? '' : ';VALUE=DATE'}:#{due_date}\n"
          end
          ical << "X-ERRANDS-EXPANDED:#{expanded ? 1 : 0}\n"
          ical << "DESCRIPTION:#{notes}\n"
          ical << "RELATED-TO:#{parent}\n"
          ical << "PERCENT-COMPLETE:#{percent_complete}\n"
          ical << "PRIORITY:#{priority}\n"
          unless start_date.to_s.empty?
            ical << "DTSTART#{due_date.include?('T') ? '' : ';VALUE=DATE'}:#{start_date}\n"
          end
          ical << "CATEGORIES:#{tags.join(',')}\n"
          ical << "SUMMARY:#{text}\n"
          ical << "X-ERRANDS-TOOLBAR-SHOWN:#{toolbar_shown ? 1 : 0}\n"
          ical << "UID:#{uid}\n"
          ical << "END:VTODO\n"
        end
      end

      # The property-to-setter table upstream writes as an if/elif chain.
      def ical_setters
        [
          [->(prop) { prop.include?('DTSTAMP') }, ->(value) { self.created_at = value.delete_suffix('Z') }],
          [->(prop) { prop.include?('LAST-MODIFIED') }, ->(value) { self.changed_at = value.delete_suffix('Z') }],
          [->(prop) { prop.include?('PERCENT-COMPLETE') }, ->(value) { self.percent_complete = value.to_f.to_i }],
          [->(prop) { prop.include?('PRIORITY') }, ->(value) { self.priority = value.to_i }],
          [->(prop) { prop.include?('RELATED-TO') }, ->(value) { self.parent = value }],
          [->(prop) { prop.include?('STATUS') }, ->(value) { self.completed = value == 'COMPLETED' }],
          [->(prop) { prop.include?('SUMMARY') }, ->(value) { self.text = value }],
          [->(prop) { prop == 'UID' }, ->(value) { self.uid = value }],
          [->(prop) { prop.include?('DUE') }, ->(value) { self.due_date = value.delete_suffix('Z') }],
          [->(prop) { prop.include?('DTSTART') }, ->(value) { self.start_date = value.delete_suffix('Z') }],
          [->(prop) { prop.include?('DESCRIPTION') }, ->(value) { self.notes = value }],
          [->(prop) { prop.include?('CATEGORIES') }, ->(value) { self.tags = value.split(',') }],
          [->(prop) { prop.include?('X-ERRANDS-COLOR') }, ->(value) { self.color = value }],
          [->(prop) { prop.include?('X-ERRANDS-EXPANDED') }, ->(value) { self.expanded = value.to_i == 1 }],
          [->(prop) { prop.include?('X-ERRANDS-TOOLBAR-SHOWN') }, ->(value) { self.toolbar_shown = value.to_i == 1 }],
        ]
      end
  end

  # UserData is the on-disk database: the task lists, the tasks and the tags.
  #
  # Ported from UserDataJSON in upstream's errands/lib/data.py. The same
  # data.json under the user's data directory holds the same three arrays, and
  # every mutator writes the whole file the way upstream does.
  #
  # Upstream wraps each tag in a TagsData dataclass with a single `text`
  # field; here a tag is the string itself, and data.json keeps upstream's
  # {"text": ...} shape so the two implementations read each other's files.
  #
  # Upstream's __convert_data step, which imports the sqlite data.db written by
  # Errands before 45.0, is not ported: that database is a Python-era artefact
  # and this port has never written one.
  #
  module UserData
    class << self
      attr_reader :tags, :task_lists, :tasks

      def init
        Log.debug('Data: Initialize')
        FileUtils.mkdir_p(data_dir)
        @tags = []
        @task_lists = []
        @tasks = []
        if File.exist?(data_file_path)
          read
        else
          Log.debug('Data: Create data.json file')
          write
        end
      end

      def data_dir = @data_dir ||= File.join(GLib.user_data_dir, 'errands')

      def data_file_path = @data_file_path ||= File.join(data_dir, 'data.json')

      # ------ LISTS ------ #

      def add_list(name, uuid: '', synced: false, color: '')
        TaskListData.new(
          deleted: false,
          name:    name,
          uid:     uuid.to_s,
          synced:  synced,
          color:   color,
        ).tap do |new_list|
          Log.debug("Data: Create list '#{new_list.uid}'")
          task_lists << new_list
          write
        end
      end

      def get_list(list_uid) = task_lists.find { |list| list.uid == list_uid }

      def lists_as_dicts = task_lists

      def delete_list(list_uid)
        get_list(list_uid)&.deleted = true
        tasks.reject! { |task| task.list_uid == list_uid }
        write
      end

      # Upstream returns None for any falsy value, and its call sites rely on
      # that; nil stands in for None here.
      def get_list_prop(list_uid, prop)
        value = get_list(list_uid)&.public_send(prop)
        if value == false || value.nil? || value == '' || value == 0
          nil
        else
          value
        end
      end

      def update_list_prop(list_uid, prop, value)
        get_list(list_uid)&.public_send(:"#{prop}=", value)
        write
      end

      def update_list_props(list_uid, props, values)
        get_list(list_uid).then do |list|
          if list
            props.each_with_index { |prop, index| list.public_send(:"#{prop}=", values[index]) }
          end
        end
        write
      end

      # ------ TASKS ------ #

      def add_task(**options)
        TaskData.new(**options).tap do |new_task|
          if new_task.uid.to_s.empty?
            new_task.uid = SecureRandom.uuid
          end
          Log.debug("Data: Add task '#{new_task.uid}'")
          if Settings.get('task-list-new-task-position-top')
            tasks.unshift(new_task)
          else
            tasks << new_task
          end
          write
        end
      end

      def get_task(list_uid, uid)
        tasks.find { |task| task.list_uid == list_uid && task.uid == uid } || TaskData.new
      end

      def get_prop(list_uid, uid, prop) = get_task(list_uid, uid).public_send(prop)

      def delete_task(list_uid, uid)
        tasks.reject! { |task| task.list_uid == list_uid && task.uid == uid }
        write
      end

      def delete_tasks_from_trash
        tasks.each do |task|
          if task.trash && !task.deleted
            task.deleted = true
            task.synced = false
          end
        end
        write
      end

      def clean_deleted
        Log.debug('Data: Clean deleted')
        task_lists.reject!(&:deleted)
        tasks.reject!(&:deleted)
        write
      end

      def tasks_as_dicts(list_uid = nil, parent = nil)
        if list_uid.nil?
          tasks
        elsif parent.nil?
          tasks.select { |task| task.list_uid == list_uid }
        else
          tasks.select { |task| task.list_uid == list_uid && task.parent == parent }
        end
      end

      # The (total, completed) pair the titles and progress bars show.
      def get_status(list_uid, parent_uid = nil)
        selected = tasks.select { |task| task.list_uid == list_uid && !task.deleted && !task.trash }
        if parent_uid
          selected = selected.select { |task| task.parent == parent_uid }
        end
        [selected.length, selected.count(&:completed)]
      end

      def update_props(list_uid, uid, props, values)
        tasks.find { |task| task.list_uid == list_uid && task.uid == uid }.then do |task|
          if task
            props.each_with_index { |prop, index| task.public_send(:"#{prop}=", values[index]) }
            if props.map(&:to_s).include?('due_date')
              task.notified = false
            end
          end
        end
        write
      end

      def parents_uids_tree(list_uid, task_uid)
        [].tap do |parents|
          parent = get_prop(list_uid, task_uid, :parent)
          while parent != ''
            parents << parent
            parent = get_prop(list_uid, parent, :parent)
          end
        end
      end

      def clean_orphans
        uids = tasks.map(&:uid)
        [].tap do |orphans|
          tasks.each do |task|
            unless task.parent.to_s.empty? || uids.include?(task.parent)
              task.parent = ''
              orphans << task
            end
          end
          write
        end
      end

      # ------ MOVING TASKS ------ #

      def move_task_after(list_uid, task_uid, task_after_uid)
        move_one_after(list_uid, task_uid, task_after_uid)
        after_uid = task_uid
        sub_tasks_tree(list_uid, task_uid).each do |task|
          move_one_after(list_uid, task.uid, after_uid)
          after_uid = task.uid
        end
        write
      end

      def move_task_before(list_uid, task_uid, task_before_uid)
        move_one_before(list_uid, task_uid, task_before_uid)
        sub_tasks_tree(list_uid, task_uid).each { |task| move_one_before(list_uid, task.uid, task_before_uid) }
        write
      end

      # Copies a task and its sub-tasks into another list and marks the
      # originals deleted, returning the new top-level task.
      def move_task_to_list(task_uid, from_list_uid, to_list_uid, new_parent = '')
        originals = [get_task(from_list_uid, task_uid)]
        base_task = copy_task(originals.first, to_list_uid, new_parent)
        tasks << base_task

        sub_tasks_tree(from_list_uid, task_uid).each do |task|
          tasks << copy_task(task, to_list_uid, task.parent)
          originals << task
        end

        originals.each do |task|
          task.deleted = true
          task.synced = false
        end
        write

        base_task
      end

      # ------ TAGS ------ #

      def add_tag(tag)
        unless tags.any? { |stored| stored == tag }
          tags << tag
          write
        end
      end

      def update_tags
        from_tasks = tasks.flat_map(&:tags).uniq
        added = from_tasks.reject { |tag| tags.include?(tag) }
        unless added.empty?
          tags.concat(added)
          write
        end
      end

      def remove_tag(tag)
        tags.reject! { |stored| stored == tag }
        tasks.each do |task|
          if task.tags.include?(tag)
            task.tags = task.tags.reject { |stored| stored == tag }
            task.synced = false
          end
        end
        write
      end

      private

        def copy_task(task, to_list_uid, parent)
          TaskData.from_h(task.to_h).tap do |copy|
            copy.list_uid = to_list_uid
            copy.parent = parent
            copy.synced = false
          end
        end

        def sub_tasks(list_uid, task_uid)
          tasks.select { |task| task.list_uid == list_uid && task.parent == task_uid }
        end

        def sub_tasks_tree(list_uid, task_uid)
          [].tap do |tree|
            sub_tasks(list_uid, task_uid).each do |sub_task|
              tree << sub_task
              tree.concat(sub_tasks_tree(list_uid, sub_task.uid))
            end
          end
        end

        def move_one_after(list_uid, uid, after_uid)
          task = get_task(list_uid, uid)
          tasks.delete(task)
          index = tasks.index(get_task(list_uid, after_uid))
          tasks.insert((index || tasks.length - 1) + 1, task)
        end

        def move_one_before(list_uid, uid, before_uid)
          task = get_task(list_uid, uid)
          tasks.delete(task)
          index = tasks.index(get_task(list_uid, before_uid))
          tasks.insert(index || tasks.length, task)
        end

        def read
          Log.debug('Data: Read data')
          JSON.parse(File.read(data_file_path)).then do |data|
            @task_lists = data.fetch('lists', []).map { |list| TaskListData.from_h(list) }
            @tasks = data.fetch('tasks', []).map { |task| TaskData.from_h(task) }
            @tags = data.fetch('tags', []).map { |tag| tag.is_a?(Hash) ? tag['text'] : tag }
          end
        rescue StandardError => e
          Log.error("Data: Can't read data file from disk. #{e.message}. Creating new data file")
          backup
          write
        end

        def backup
          Log.info('Data: Backup')
          FileUtils.cp(data_file_path, "#{data_file_path}.old")
        rescue StandardError => e
          Log.error("Data: Can't back up data. #{e.message}")
        end

        def write
          Log.debug('Data: Write data')
          File.write(
            data_file_path,
            JSON.generate(
              {
                'lists' => task_lists.map(&:to_h),
                'tags'  => tags.map { |tag| { 'text' => tag } },
                'tasks' => tasks.map(&:to_h),
              },
            ),
          )
        rescue StandardError => e
          Log.error("Data: Can't write to disk. #{e.message}.")
        end
    end
  end
end
