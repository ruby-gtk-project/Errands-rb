# frozen_string_literal: true

require 'tmpdir'

scratch = Dir.mktmpdir('errands-drive')
ENV['XDG_CONFIG_HOME'] = File.join(scratch, 'config')
ENV['XDG_DATA_HOME'] = File.join(scratch, 'data')
ENV['XDG_CACHE_HOME'] = File.join(scratch, 'cache')

require_relative '../lib/errands'
# Goa is written but not yet wired into any require chain — no sync provider
# calls it yet — so it has to be pulled in by hand to exercise it at all.
require_relative '../lib/errands/goa'
require_relative 'gtk_driver'

app = Errands::Application.new

GtkDriver.drive(app, shots: 'tmp/shots') do |d, application|
  d.window { application.window.root }

  d.step('the window builds and shows the empty state') do
    # The sidebar's fixed Today/Tags/Trash rows mean the list box is never
    # empty, so GTK's single-selection ListBox auto-selects the first one
    # (Today) once the window is shown, rather than leaving the status page
    # on screen as it would with no rows at all.
    d.check('today page is showing') { application.window.view_stack.visible_child_name == 'errands_today_page' }
    d.check('sidebar has no lists') { application.window.sidebar.rows.empty? }
    d.shot('01-empty')
  end

  d.step('every icon the app writes out is in the theme') do
    icon_theme = Gtk::IconTheme.get_for_display(Gdk::Display.default)
    d.check('the search path carries the app icon directory') do
      icon_theme.search_path.include?(Errands::Icons.search_path)
    end
    Errands::Icons::SVG.each_key do |name|
      d.check("the icon theme resolves #{name}") { icon_theme.has_icon?(name) }
    end
  end

  d.step('every app action is registered with its accelerator') do
    Errands::Window::ACTIONS.each do |name, accelerators|
      d.check("app.#{name} is registered") { !application.app.lookup_action(name).nil? }
      unless accelerators.empty?
        d.check("app.#{name} has its accelerator") do
          # GTK re-renders the accelerator string once registered (<primary>
          # resolves to the concrete modifier, and multi-modifier combos can
          # come back in a different order), so this compares parsed keyvals
          # and modifiers rather than the raw strings.
          registered = application.app.get_accels_for_action("app.#{name}")
          registered.length == accelerators.length &&
            registered.zip(accelerators).all? do |actual, expected|
              Gtk.accelerator_parse(actual) == Gtk.accelerator_parse(expected)
            end
        end
      end
    end
  end

  d.step('add a list through the sidebar dialog') do
    application.window.sidebar.add_list
  end

  d.step('fill the add-list dialog in') do
    dialog = application.window.root.visible_dialog
    d.check('dialog is open') { !dialog.nil? }
    dialog.entry.text = 'Groceries'
    d.check('add response enabled') { dialog.get_response_enabled('add') }
    dialog.entry.signal_emit('activate')
  end

  d.step('the list arrives in the sidebar and the stack') do
    d.check('one sidebar row') { application.window.sidebar.rows.length == 1 }
    d.check('row is named') { application.window.sidebar.rows.first.name == 'Groceries' }
    d.check('list page is visible') { application.window.view_stack.visible_child_name == 'Groceries' }
    d.check('data holds the list') { Errands::UserData.task_lists.map(&:name) == ['Groceries'] }
    d.shot('03-list-page')
  end

  d.step('add two tasks through the entry row') do
    task_list = application.window.sidebar.rows.first.task_list
    task_list.entry_row.text = 'Milk'
    task_list.entry_row.signal_emit('entry-activated')
    task_list.entry_row.text = 'Bread'
    task_list.entry_row.signal_emit('entry-activated')
  end

  d.step('the tasks show up') do
    task_list = application.window.sidebar.rows.first.task_list
    d.check('two task widgets') { task_list.tasks.length == 2 }
    d.check('two task records') { Errands::UserData.tasks.length == 2 }
    d.check('title counts them') { task_list.title.subtitle == 'Completed: 0 / 2' }
    d.check('counter shows 2') { application.window.sidebar.rows.first.size_counter.label == '2' }
    d.shot('04-tasks')
  end

  d.step('complete one task') do
    task_list = application.window.sidebar.rows.first.task_list
    task_list.tasks.find { |task| task.task_data.text == 'Milk' }.complete_button.active = true
  end

  d.step('completion is stored and the task moves section') do
    task_list = application.window.sidebar.rows.first.task_list
    d.check('record is completed') { Errands::UserData.tasks.find { |t| t.text == 'Milk' }.completed }
    d.check('one completed widget') { task_list.completed_tasks.length == 1 }
    d.check('title counts it') { task_list.title.subtitle == 'Completed: 1 / 2' }
    d.shot('05-completed')
  end

  d.step('open a task toolbar') do
    task_list = application.window.sidebar.rows.first.task_list
    task_list.tasks.first.toolbar_toggle_button.active = true
  end

  d.step('the toolbar is built and revealed') do
    task_list = application.window.sidebar.rows.first.task_list
    task = task_list.tasks.first
    d.check('toolbar revealed') { task.toolbar_revealer.reveal_child? }
    d.check('toolbar has a child') { !task.toolbar_revealer.child.nil? }
    d.check('record remembers it') { task.task_data.toolbar_shown }
    d.shot('06-toolbar')
  end

  d.step('add a sub-task') do
    task = application.window.sidebar.rows.first.task_list.tasks.first
    task.sub_task_entry.text = 'Rye'
    task.sub_task_entry.signal_emit('activate')
  end

  d.step('the sub-task is stored under its parent') do
    task = application.window.sidebar.rows.first.task_list.tasks.first
    d.check('one sub-task widget') { task.tasks.length == 1 }
    d.check('record has the parent') do
      Errands::UserData.tasks.find { |t| t.text == 'Rye' }.parent == task.uid
    end
    d.shot('07-sub-task')
  end

  d.step('open the notes dialog') do
    Errands::State.notes_dialog.show(application.window.sidebar.rows.first.task_list.tasks.first)
  end

  d.step('notes are saved on close') do
    d.check('dialog is open') { !application.window.root.visible_dialog.nil? }
    Errands::State.notes_dialog.buffer.text = 'Wholemeal'
    d.shot('08-notes')
    Errands::State.notes_dialog.close
  end

  d.step('the note reached the record') do
    task = application.window.sidebar.rows.first.task_list.tasks.first
    d.check('notes stored') { task.task_data.notes == 'Wholemeal' }
  end

  d.step('open the date and time dialog') do
    Errands::State.datetime_dialog.show(application.window.sidebar.rows.first.task_list.tasks.first)
  end

  d.step('a due date is saved on close') do
    d.check('dialog is open') { !application.window.root.visible_dialog.nil? }
    Errands::State.datetime_dialog.due_picker.datetime = '20260115T090000'
    Errands::State.datetime_dialog.close
  end

  d.step('the due date reached the record') do
    task = application.window.sidebar.rows.first.task_list.tasks.first
    d.check('due date stored') { task.task_data.due_date == '20260115T090000' }
    d.check('button shows it') { task.toolbar.date_time_content.label == '15 January 09:00' }
  end

  d.step('selecting the Today row switches pages') do
    application.window.sidebar.list_box.select_row(application.window.sidebar.today_sidebar_row.row)
  end

  d.step('the Today page lists the overdue task across lists') do
    d.check('today page is visible') { application.window.view_stack.visible_child_name == 'errands_today_page' }
    d.check('one task is overdue') { application.window.today.tasks_data.length == 1 }
    d.check('it is the task with the due date') do
      application.window.today.tasks_data.first.text == 'Bread'
    end
    d.check('the sidebar counter shows it') { application.window.sidebar.today_sidebar_row.size_counter.label == '1' }
    d.shot('09-today')
  end

  d.step('selecting the Tags row switches pages') do
    application.window.sidebar.list_box.select_row(application.window.sidebar.tags_sidebar_row.row)
  end

  d.step('the Tags page is empty and a new tag can be added there') do
    d.check('tags page is visible') { application.window.view_stack.visible_child_name == 'errands_tags_page' }
    d.check('no tags yet') { application.window.tags.rows.empty? }
    application.window.tags.entry_row.text = 'home'
    application.window.tags.entry_row.signal_emit('entry-activated')
  end

  d.step('the new tag is listed and counted') do
    d.check('one tag row') { application.window.tags.rows.map(&:title) == ['home'] }
    d.check('the sidebar counter shows it') { application.window.sidebar.tags_sidebar_row.size_counter.label == '1' }
    d.shot('09a-tags-page')
  end

  d.step('selecting the Trash row switches pages') do
    application.window.sidebar.list_box.select_row(application.window.sidebar.trash_sidebar_row.row)
  end

  d.step('the Trash page is empty before anything is trashed') do
    d.check('trash page is visible') { application.window.view_stack.visible_child_name == 'errands_trash_page' }
    d.check('nothing is trashed yet') { application.window.trash.trash_items.empty? }
    d.shot('09b-trash-page-empty')
  end

  d.step('switching back to the list restores it') do
    application.window.sidebar.list_box.select_row(application.window.sidebar.rows.first.row)
  end

  d.step('the list page is visible again') do
    d.check('list page is visible') { application.window.view_stack.visible_child_name == 'Groceries' }
  end

  d.step('rename the list') do
    application.window.sidebar.rows.first.row.activate_action('list_row.rename')
  end

  d.step('the rename dialog saves') do
    dialog = application.window.root.visible_dialog
    d.check('dialog is open') { !dialog.nil? }
    d.check('name is pre-filled') { dialog.entry.text == 'Groceries' }
    dialog.entry.text = 'Shopping'
    dialog.entry.signal_emit('activate')
  end

  d.step('the new name is everywhere') do
    row = application.window.sidebar.rows.first
    d.check('row label') { row.label.label == 'Shopping' }
    d.check('record') { Errands::UserData.get_list_prop(row.uid, :name) == 'Shopping' }
    d.shot('10-renamed')
  end

  d.step('open the shortcuts dialog') do
    application.window.shortcuts_dialog.present(application.window.root)
  end

  d.step('the shortcuts dialog renders') do
    d.check('dialog is open') { !application.window.root.visible_dialog.nil? }
    d.shot('11-shortcuts')
    application.window.root.visible_dialog.close
  end

  d.step('export and re-import the list through iCal') do
    row = application.window.sidebar.rows.first
    File.write(File.join(Dir.tmpdir, 'errands-export.ics'), row.list_data.to_ical)
    list, tasks = Errands::TaskListData.from_ical(File.read(File.join(Dir.tmpdir, 'errands-export.ics')))
    d.check('round trip keeps the name') { list.name == 'Shopping' }
    d.check('round trip keeps the tasks') { tasks.map(&:text).sort == %w[Bread Milk Rye] }
  end
  d.step('a known tag shows up in the toolbar popover') do
    Errands::UserData.add_tag('home')
    task = application.window.sidebar.rows.first.task_list.tasks.first
    task.toolbar.tags_button.active = true
  end

  d.step('ticking the tag writes it to the task') do
    task = application.window.sidebar.rows.first.task_list.tasks.first
    d.check('one tag row') { task.toolbar.tag_rows.length == 1 }
    task.toolbar.tag_rows.first.toggle_button.active = true
    d.check('task carries the tag') { task.task_data.tags == ['home'] }
    d.check('a chip is shown') { task.tags.map(&:title) == ['home'] }
  end

  d.step('the chip is realised on screen') do
    d.shot('12-tags')
  end

  d.step('deleting the chip takes the tag away') do
    task = application.window.sidebar.rows.first.task_list.tasks.first
    task.tags.first.delete_button.signal_emit('clicked')
    d.check('task has no tags') { task.task_data.tags.empty? }
    d.check('no chips left') { task.tags.empty? }
  end

  d.step('opening the priority popover seeds the custom spin button') do
    task = application.window.sidebar.rows.first.task_list.tasks.first
    task.toolbar.priority_button.active = true
    d.check('spin button starts at the current priority') { task.toolbar.custom_priority_button.value_as_int == 0 }
  end

  d.step('picking the High preset stores it once the popover closes') do
    task = application.window.sidebar.rows.first.task_list.tasks.first
    high_row = Errands::Utils.children(task.toolbar.priority_list).first
    task.toolbar.priority_list.signal_emit('row-activated', high_row)
    d.check('spin button took the preset') { task.toolbar.custom_priority_button.value_as_int == 1 }
    d.check('popover closed itself') { !task.toolbar.priority_button.active? }
    d.check('the record stored it') { task.task_data.priority == 1 }
    d.check('the button picked up the error class') { task.toolbar.priority_button.css_classes.include?('error') }
  end

  d.step('the priority button is realised on screen') do
    d.shot('12a-priority')
  end

  d.step('opening the overflow menu seeds the colour selector') do
    task = application.window.sidebar.rows.first.task_list.tasks.first
    task.toolbar.menu_button.active = true
    d.check('none is selected to start') { task.toolbar.color_selector.buttons['none'].active? }
  end

  d.step('the overflow menu is realised on screen') do
    d.shot('12b-overflow-menu')
  end

  d.step('picking a colour writes it to the task') do
    task = application.window.sidebar.rows.first.task_list.tasks.first
    task.toolbar.color_selector.buttons['blue'].active = true
    d.check('the record stored the colour') { task.task_data.color == 'blue' }
  end

  d.step('the attachments dialog opens from the toolbar button, empty') do
    task = application.window.sidebar.rows.first.task_list.tasks.first
    task.toolbar.attachments_button.signal_emit('clicked')
    d.check('the dialog is showing') { application.window.root.visible_dialog.equal?(Errands::State.attachments_dialog) }
    d.check('no attachments yet') { task.task_data.attachments.empty? }
    d.check('the empty-state page is shown') { Errands::State.attachments_dialog.status_page.visible? }
  end

  d.step('the attachments dialog is realised on screen') do
    d.shot('12c-attachments-empty')
    Errands::State.attachments_dialog.close
  end

  d.step('a drag hands over the task identity') do
    task = application.window.sidebar.rows.first.task_list.tasks.first
    provider = task.drag_source.signal_emit('prepare', 0.0, 0.0)
    d.check('a content provider is offered') { provider.is_a?(Gdk::ContentProvider) }
  end

  d.step('move a task to the trash') do
    task_list = application.window.sidebar.rows.first.task_list
    task_list.tasks.find { |task| task.task_data.text == 'Bread' }.delete
  end

  d.step('the trashed task is hidden and marked') do
    d.check('record is trashed') { Errands::UserData.tasks.find { |t| t.text == 'Bread' }.trash }
    task = application.window.sidebar.rows.first.task_list.tasks.find { |t| t.task_data.text == 'Bread' }
    d.check('widget is hidden') { !task.root.reveal_child? }
    d.shot('13-trashed')
  end

  d.step('settings remember the last open list') do
    d.check('last open list stored') { Errands::Settings.get('last-open-list') == 'Groceries' }
    d.check('settings file written') { File.exist?(Errands::Settings.location) }
  end

  d.step('the Trash row and page show the trashed task') do
    d.check('trash row counter shows it') { application.window.sidebar.trash_sidebar_row.size_counter.label == '1' }
    d.check('trash icon switched to full') do
      application.window.sidebar.trash_sidebar_row.send(:icon).icon_name == 'errands-trash-full-symbolic'
    end
    application.window.sidebar.list_box.select_row(application.window.sidebar.trash_sidebar_row.row)
    d.check('trash page is visible') { application.window.view_stack.visible_child_name == 'errands_trash_page' }
    d.check('one trash item') { application.window.trash.trash_items.length == 1 }
    d.check('it is Bread') { application.window.trash.trash_items.first.task_data.text == 'Bread' }
  end

  d.step('the trash page is realised on screen') do
    d.shot('13a-trash-page')
  end

  d.step('restoring it empties the trash again') do
    application.window.trash.on_trash_restore
    d.check('record is no longer trashed') { Errands::UserData.tasks.find { |t| t.text == 'Bread' }.trash == false }
    d.check('trash page is empty') { application.window.trash.trash_items.empty? }
    d.check('the status page is back') { application.window.trash.status_page.visible? }
  end

  d.step('the empty trash page is realised on screen') do
    d.shot('13b-trash-page-restored')
  end

  d.step('re-trashing it for the deletion that follows') do
    application.window.sidebar.rows.first.task_list.tasks.find { |task| task.task_data.text == 'Bread' }.delete
    d.check('record is trashed again') { Errands::UserData.tasks.find { |t| t.text == 'Bread' }.trash }
  end

  d.step('delete the list') do
    application.window.sidebar.rows.first.row.activate_action('list_row.delete')
  end

  d.step('confirming the deletion empties the sidebar') do
    dialog = application.window.root.visible_dialog
    d.check('confirmation is asked') { !dialog.nil? }
    dialog.signal_emit('response', 'confirm')
    dialog.close
  end

  d.step('the app is back to its empty state') do
    d.check('no sidebar rows') { application.window.sidebar.rows.empty? }
    d.check('status page is showing') { application.window.view_stack.visible_child_name == 'errands_status_page' }
    d.check('list is marked deleted') { Errands::UserData.task_lists.all?(&:deleted) }
    d.shot('14-empty-again')
  end

  d.step('the about dialog opens from the app action') do
    application.app.activate_action('about', nil)
  end

  d.step('the about dialog renders the app\'s own fields') do
    dialog = application.window.root.visible_dialog
    d.check('dialog is open') { !dialog.nil? }
    d.check('it is the memoized about dialog') { dialog.equal?(application.window.about_dialog) }
    d.check('application name is set') { dialog.application_name == 'Errands' }
    d.check('version is set') { !dialog.version.to_s.empty? }
    d.shot('15-about')
    dialog.close
  end

  d.step('GOA credentials come back nil with no matching account configured') do
    d.check('no GOA session is available in this headless run, and the lookup fails safely') do
      Errands::Goa.get_goa_credentials('Nextcloud').nil?
    end
  end

  d.step('the notifications daemon is registered and finds overdue tasks by its own rules') do
    d.check('State holds the running daemon') { Errands::State.notifications.is_a?(Errands::Notifications) }
    task_list = Errands::UserData.add_list('Notif-check')
    Errands::UserData.add_task(
      list_uid: task_list.uid,
      uid: 'notif-check-task',
      text: 'Overdue',
      due_date: '20200101T000000',
    )
    d.check('an overdue, un-notified task is picked up') do
      Errands::State.notifications.due_tasks.map(&:uid).include?('notif-check-task')
    end
    Errands::UserData.update_props(task_list.uid, 'notif-check-task', [:notified], [true])
    d.check('a notified task is not picked up again') do
      !Errands::State.notifications.due_tasks.map(&:uid).include?('notif-check-task')
    end
  end
end
