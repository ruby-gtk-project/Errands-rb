# Errands — upstream component inventory

Survey of upstream Errands (`origin/main`, Python + PyGObject, GTK4 / Libadwaita)
against the Ruby port on `ruby`, for a full-parity port.

- Upstream ref: `origin/main` — read with `git show origin/main:<path>`
- Port tree surveyed: `lib/` on `ruby`
- Method: `.claude/skills/component-identification` (symbol-table scan + reading
  every widget file), house style per `.claude/skills/ruby-gtk`

## Totals

Scan of upstream's source (`scripts/component-scan.sh`, classified against
`scripts/symbols.tsv`):

| stream | count |
|---|---:|
| widget occurrences | 329 |
| non-widget GTK types | 145 |
| event controllers / gestures | 29 |
| CSS class applications | 149 |
| signal connections | 59 |
| action names (literal) | 19 |

Port side (re-surveyed 2026-11-02, after the data layer, window, sidebar, task
lists, tasks and the task toolbar landed): `lib/` holds `lib/errands.rb` plus 32
files under `lib/errands/`. 23 of the 32 upstream component units below now have
a port file; the Today, Tags and Trash sections and the preferences dialog do
not, and neither does any of the sync stack. Per-unit status is on each section
below, and the roll-up is in **Port status** at the end.

Upstream has **no `.ui` or `.blp` for its widgets** — everything is built in
Python, so the scan is the whole picture on that side. The one declarative file
is `data/resources/gtk/help-overlay.ui`, a `GtkShortcutsWindow` with no backing
source file; it is its own unit.

## Note on upstream's `shared/components/*`

`boxes.py`, `buttons.py`, `entries.py`, `header_bar.py`, `toolbar_view.py` and
`menus.py` are not components. They are thin PyGObject shims that let the rest
of the app pass `children=[...]` and `on_click=` as constructor kwargs
(`ErrandsBox`, `ErrandsButton`, `ErrandsListBox`, `ErrandsHeaderBar`,
`ErrandsToolbarView`, `ErrandsSimpleMenu`, …). The Ruby house style already
does this job with memoized methods and `.tap` blocks, so **these files have no
port target** — their widgets are counted inside whichever component uses them.
`shared/sidebar_item.py` is a dead stub upstream (`__build_ui` is `pass`) and is
likewise not ported. `components/controllers.py` is empty.

---

## errands/application.py — the application object

| Widget / thing | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.Application` | 1 | — | `startup`, `activate` | app id `io.github.mrvladus.List`, `DEFAULT_FLAGS`; resource base path `/io/github/mrvladus/Errands/` |
| background portal | 1 | — | — | `Xdp.Portal.request_background` driven by the `launch-on-startup` setting |

Port target: `lib/errands/application.rb` — **exists.** It builds the window,
installs the app actions and accelerators, applies the stylesheet and the icon
theme and sets the colour scheme from the `theme` setting. Still missing: the
background portal (blocked, see Blockers) and the notifications daemon.
Per the Adwaita quirks, `Gtk::Application` stays (it already does).

## errands/state.py — global widget registry

Not a widget: class-level slots holding the application, the main window, the
split view, the view stack, the four fixed pages, the three fixed sidebar rows
and the three singleton dialogs, plus `get_task_lists` / `get_tasks` /
`get_task` / `get_today_task` lookups. Everything in the app reaches everything
else through it.

Port target: `lib/errands/state.rb` — **exists.** Kept as one object
rather than class-level globals, so the memoized widget methods can be reached
without a global.

## errands/widgets/window.py — the main window

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` | 1 | — | — | title "Errands", `width_request` 360, `height_request` 200; `width`/`height`/`maximized` bound to GSettings; `hide-on-close` bound to `run-in-background` |
| `Adw.ToastOverlay` | 1 | — | — | window content; `add_toast(text)` is the app-wide toast entry point |
| `Adw.NavigationSplitView` | 1 | — | — | `show_content=True`, sidebar 200–300px |
| `Adw.NavigationPage` | 2 | — | — | "Sidebar" wraps `Sidebar`; "Content" wraps the view stack, `width_request` 360 |
| `Adw.ViewStack` | 1 | — | — | 6 fixed pages + one page per task list |
| `Adw.Breakpoint` | 1 | — | — | `max-width: 600px` → `split_view.collapsed = true` |
| `Adw.StatusPage` | 2 | — | — | "No Task Lists" / "Create new or import existing one" (icon `io.github.mrvladus.List`); "Syncing" / "First synchronization is running" (icon `errands-sync-symbolic`) |
| `Gtk.Button` | 1 | `pill`, `suggested-action` | `clicked` → activates the sidebar's add-list button | "Create List" on the empty state |
| `Adw.HeaderBar` | 2 | — | — | `show_title=False`, one per status page |
| `Gtk.FileFilter` + `Gtk.FileDialog` | 1 | — | — | `*.ics` open dialog for list import |
| `Adw.AboutDialog` | 1 | — | — | version, icon, "Errands", © 2023-2024 Vlad Krupinskii, website, issue url, MIT-X11, `translator-credits` |

Repeaters: the view stack grows one page per task list (`TaskList`), added by
`TaskListSidebarRow`.
Conditional: the stack starts on `errands_status_page`, then the sidebar's load
switches it.

App actions installed here, with accelerators:

| action | accel | does |
|---|---|---|
| `app.preferences` | `<primary>comma` | presents `PreferencesWindow` |
| `app.about` | — | presents the About dialog |
| `app.import` | `<primary>i` | `.ics` file dialog → `TaskListData.from_ical`, de-dupes uid and name, adds list and tasks, toast "Imported", sync |
| `app.sync` | `F5`, `<primary>f` | syncs, or toasts "Sync is disabled" when provider is 0 |
| `app.quit` | `<primary>q`, `<primary>w` | quits (registered twice upstream — a bug; the second registration wins) |
| `win.show-help-overlay` | `<primary>question` | the shortcuts window (GTK-provided, needs the `.ui` loaded) |

Also: `Adw.StyleManager.set_color_scheme(GSettings.get("theme"))` at startup.

Port target: `lib/errands/window.rb` — **exists**, with the About dialog and
the import dialog extracted as planned into `lib/errands/about_dialog.rb` and
`lib/errands/import_dialog.rb` (both **exist**). `lib/errands/window.rb` also
holds `StatusPageView`, the empty-state page. The view stack carries only the
pages whose components exist, so the Today, Tags and Trash pages are not wired
in yet.

## data/resources/gtk/help-overlay.ui — keyboard shortcuts window

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.ShortcutsWindow` | 1 | — | — | id `help_overlay`, reached by `win.show-help-overlay` |
| `Gtk.ShortcutsSection` | 1 | — | — | |
| `Gtk.ShortcutsGroup` | 4 | — | — | General, Sync, Lists, Details |
| `Gtk.ShortcutsShortcut` | 7 | — | — | see below |

Shortcuts listed: Show keyboard shortcuts `<Control>question`; Preferences
`<Control>comma`; Quit `<Control>q <Control>w`; Sync / Fetch Tasks
`<Control>F`; Add List `<Control><Shift>A`; Import List `<Control>I`; Toggle
Details `F9`.

Note the drift to reproduce or fix deliberately: the window advertises `F9`
"Toggle Details", but no `F9` accelerator exists in the source — the toolbar is
toggled by a per-task button. `<Control>F` is listed for sync while the source
binds `F5` and `<primary>f`.

Port target: `lib/errands/shortcuts_dialog.rb` — **exists, partial.**
`Gtk::ShortcutsWindow` turned out to be unusable from the bindings
(constructing one raises "GtkWindow is not subtype of GtkShortcutsWindow"), so
the port builds `Adwaita::ShortcutsDialog` instead. The Sync, Preferences and
Toggle Details entries are still left out, pending those components.

## errands/widgets/loading_page.py — "Loading Tasks…" page

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Bin` | 1 | — | — | stack page `errands_loading_page` |
| `Adw.ToolbarView` + `Adw.HeaderBar` | 1 each | — | — | `show_title=False` |
| `Adw.StatusPage` | 1 | `compact` | — | "Loading Tasks…", icon `errands-progressbar-symbolic`, `vexpand` |

Port target: `lib/errands/loading_page.rb` — **exists.**

## errands/widgets/sidebar.py — the sidebar

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.Bin` | 1 | — | — | root |
| `Adw.ToolbarView` | 1 | — | — | |
| `Adw.HeaderBar` | 1 | — | — | title widget is a `Gtk.Label` "Errands" with `heading` |
| `Gtk.Label` | 1 | `heading` | — | the header title |
| `Gtk.Button` | 1 | — | `clicked` → `_on_add_list_btn_clicked` | add-list "+", icon `errands-add-symbolic`, tooltip "Add List (Ctrl+Shift+A)" |
| `Gtk.ShortcutController` | 1 | — | `<Control><Shift>a` → `activate` | MANAGED scope, on the add-list button |
| `Gtk.MenuButton` | 1 | — | — | primary, "Main Menu", `open-menu-symbolic` |
| `Gio.Menu` (sectioned) | 1 | — | 3 sections, 6 items | Sync / Fetch Tasks `app.sync` ‖ Import Task List `app.import` ‖ Preferences `app.preferences`, Keyboard Shortcuts `win.show-help-overlay`, About Errands `app.about`, Quit `app.quit` |
| `Gtk.Revealer` + `Gtk.Spinner` | 1 each | — | — | sync indicator, CROSSFADE 200ms, tooltip "Syncing…", toggled by `toggle_sync_indicator` |
| `Adw.StatusPage` | 1 | `compact` | — | "Add new List" / 'Click "+" button', icon `errands-lists-symbolic`; visibility inverse-bound to the list box |
| `Gtk.ListBox` | 1 | `navigation-sidebar` | `row-selected` → activates the row | SINGLE selection, `activate_on_single_click=False`, header func inserts a `TitledSeparator("Task Lists")` before the first task-list row |
| `Gtk.ScrolledWindow` | 1 | — | — | `propagate_natural_height` |
| `Gtk.Entry` | 1 | — | `activate`, `notify::text` | inside the Add List dialog; placeholder "New List Name" |
| `Adw.MessageDialog` | 1 | — | `response` | "Add List", responses cancel / add, add is SUGGESTED and disabled until the name is non-empty and unique |

Repeaters: one `TaskListSidebarRow` per non-deleted list, appended after the
three fixed rows (`TodaySidebarRow`, `TagsSidebarRow`, `TrashSidebarRow`).
Conditional: the status page shows only when there are zero task-list rows, and
showing it also switches the stack to `errands_status_page`.

Port targets: `lib/errands/sidebar.rb` and `lib/errands/add_list_dialog.rb` —
both **exist.** The dialog is built on `Adwaita::AlertDialog` rather than the
deprecated `Adwaita::MessageDialog`. The sidebar list box holds only the task
list rows so far — the three fixed rows (Today, Tags, Trash) are not built.

## errands/widgets/shared/titled_separator.py — "— Completed —" separator

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Box` | 1 | `dim-label` | — | spacing 12, `title` GObject property, per-instance margins |
| `Gtk.Separator` | 2 | — | — | `hexpand`, centred |
| `Gtk.Label` | 1 | `caption` | — | label bound bidirectionally to the `title` property |

Used by: sidebar ("Task Lists"), `TaskList` ("Completed"), `Task` ("Completed"),
task toolbar ("Custom").

Port target: `lib/errands/titled_separator.rb` — **exists.**

## errands/widgets/task_list/task_list_sidebar_row.py — one task-list row

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Gtk.ListBoxRow` | 1 | `sidebar-item` | `activate` → switches the stack, sets `last-open-list` | `height_request` 45 |
| `Gtk.ColorDialogButton` + `Gtk.ColorDialog` | 1 each | — | `notify::rgba` → writes `color` (falls back to `#3584e4`) | `with_alpha=False`, tooltip "Color" |
| `Gtk.Label` | 1 | — | — | list name, `hexpand`, START, ellipsize END |
| `Gtk.Button` | 1 | `dim-label`, `caption`, `flat`, `circular` | — | uncompleted counter, `can_target=False` |
| `Gtk.PopoverMenu` | 1 | — | — | `has_arrow=False`, START, pointed at the click position |
| `Gio.Menu` | 1 | — | 3 items | Rename `list_row.rename`, Delete `list_row.delete`, Export `list_row.export` |
| `Gtk.GestureClick` | 1 | — | `released` → popup | button 3 |
| `Gtk.GestureLongPress` | 1 | — | `pressed` → popup | touch only |
| `Gtk.DropTarget` | 1 | — | `drop` → moves a task (and sub-tasks) into this list | type `Task`, MOVE |
| `Gtk.DropControllerMotion` | 1 | — | `enter` → switches to this list after 0.7s hover | |
| `Gtk.Entry` + `Adw.MessageDialog` | 1 each | — | `activate`, `notify::text`, `response` | Rename dialog: "Rename List", save SUGGESTED, disabled until non-empty and unique |
| `Gtk.FileDialog` + `Gtk.FileFilter` | 1 each | — | — | Export: `*.ics`, initial name `<uid>.ics`, toast "Exported" / "Export failed" |
| `ConfirmDialog` | 1 | — | — | Delete: "List will be permanently deleted", DESTRUCTIVE |

Also constructs the row's `TaskList` and adds it to the view stack as a
`Adw.ViewStackPage` named after the list.

Port targets: `lib/errands/task_list_sidebar_row.rb` plus
`lib/errands/rename_list_dialog.rb` — both **exist.** The drop target carries
a task uid string rather than a `Task` GType (see Blockers).

## errands/widgets/task_list/task_list.py — one task list page

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.Bin` | 1 | — | — | root, a view-stack page |
| `Adw.ToolbarView` | 1 | — | — | |
| `Adw.HeaderBar` | 1 | — | — | |
| `Adw.WindowTitle` | 1 | — | — | title = list name, subtitle = "Completed: n / m" (blank when empty) |
| `Gtk.ToggleButton` | 1 | — | `toggled` → shows/hides completed tasks, persists `show_completed` | `errands-check-toggle-symbolic`, tooltip "Toggle Completed Tasks" |
| `Gtk.Button` | 2 | — | `clicked` | delete-completed (`errands-delete-all-symbolic`, visibility bound to the toggle's `active`, sensitive only when something is completed); scroll-up (`errands-up-symbolic`, tooltip "Scroll Up", visible only when scrolled) |
| `Adw.Clamp` | 2 | — | — | max 1000, tighten 300 — one for the entry row, one for the task column |
| `Adw.EntryRow` | 1 | `card` | `entry-activated` → adds a task | "Add new Task", `height_request` 60, `activatable=False`, margins 3/3/12/12 |
| `Gtk.ScrolledWindow` + `Gtk.Adjustment` | 1 each | — | `value-changed` → toggles scroll-up | |
| `Gtk.Box` | 2 | — | — | uncompleted column; completed column (starts hidden) |
| `Adw.Bin` + `TitledSeparator` | 1 each | — | — | "Completed" separator, visibility bound to the completed column and to `0 < n_completed < n_total` |
| `Gtk.DropControllerMotion` | 1 | — | `motion` → auto-scrolls within 100px of an edge during a drag | |

Repeaters: one `Task` per top-level task, into the completed or uncompleted
column.
Conditional: new tasks go to the top or the bottom per
`task-list-new-task-position-top`.

Port target: `lib/errands/task_list.rb` — **exists.**

## errands/widgets/task.py — one task card (the biggest component)

43 widget occurrences. Holds two classes.

### `Task(Gtk.Revealer)`

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Gtk.Revealer` | 1 | — | — | the root; reveal = `expanded`, hidden while trashed |
| `Gtk.Box` | 1 | — | — | outer, margins 6 top/bottom |
| `Gtk.Revealer` + `Gtk.Image` | 1 each | `task-drop-area` | `drop` → reorder above this task | top drop area, `errands-add-symbolic`, revealed while a drag hovers (bound to a `DropControllerMotion`) |
| `ErrandsBox` main box | 1 | `card`, `fade`, + `task-{blue,green,yellow,orange,red,purple,brown}` (dynamic, from `task_data.color`), `task-completed` | — | margins 12/12 |
| `Gtk.ListBox` title box | 1 | `transparent`, `rounded-corners` | — | hosts the title row and the edit row |
| `Adw.ActionRow` | 1 | `transparent`, `rounded-corners` | `released` → toggles sub-tasks | `height_request` 60, `use_markup`, tooltip "Toggle Sub-Tasks", pointer cursor; title carries Pango markup and a strike-through when completed |
| `Gtk.CheckButton` | 1 | `selection-mode`, + `checkbtn-{blue,…,brown}` (dynamic) | `toggled` → completes the task and its sub-tasks | tooltip "Toggle Completion" |
| `Gtk.Revealer` + `Gtk.Image` | 1 each | `expand-indicator`, `expand-indicator-expanded` | — | revealed on hover (bound to an `EventControllerMotion`), `can_target=False` |
| `Gtk.ToggleButton` | 1 | `circular`, `flat` | `toggled` → reveals the toolbar, persists `toolbar_shown` | `errands-toolbar-symbolic`, tooltip "Toggle Toolbar" |
| `Gtk.PopoverMenu` + `Gio.Menu` | 1 each | — | 4 items | Edit `task.edit`, Move to Trash `task.move_to_trash`, Copy to Clipboard `task.copy_to_clipboard`, Export `task.export` |
| `Gtk.GestureClick` (×2) / `Gtk.GestureLongPress` | 3 | — | `released` / `pressed` | one click gesture on the title box for expand, one button-3 + one long-press for the menu |
| `Gtk.DropTarget`, `Gtk.DragSource`, `Gtk.DropControllerMotion`, `Gtk.EventControllerMotion` | 1 each | — | `drop`, `prepare`/`drag-begin`/`drag-cancel`/`drag-end`, `contains-pointer` | full task drag-and-drop: reorder, re-parent, move between lists |
| `Adw.EntryRow` | 1 | `transparent`, `rounded-corners` | `apply` → saves the text | "Edit", hidden by default, `show_apply_button`, `height_request` 60 |
| `Gtk.Button` | 1 | `circular` | `clicked` → cancels the edit | `window-close-symbolic`, tooltip "Cancel" |
| `Gtk.FlowBox` + `Gtk.Revealer` | 1 each | — | — | tags bar, `max_children_per_line=1000`, NONE selection, revealed only when the task has tags |
| `Gtk.ProgressBar` + `Gtk.Revealer` | 1 each | `osd`, `dim-label`, + `progressbar-{blue,…,brown}` (dynamic) | — | sub-task completion fraction |
| `Gtk.Revealer` | 1 | — | — | the toolbar revealer; the toolbar itself is built lazily only when `toolbar_shown` |
| `Gtk.Revealer` + box | 1 each | `sub-tasks` | — | the sub-task section |
| `Gtk.Entry` | 1 | — | `activate` → adds a sub-task | placeholder "Add new Sub-Task" |
| `Gtk.Box` | 2 | — | — | uncompleted and completed sub-task columns |
| `Adw.Bin` + `TitledSeparator` | 1 each | — | — | "Completed" separator for sub-tasks |
| `Gtk.FileDialog` | 1 | — | — | Export, initial name `<uid>.ics` |

Repeaters: one nested `Task` per sub-task (recursive), one `Tag` per tag.
Dynamic CSS: seven colour classes each on the card, the check button and the
progress bar, plus `task-completed`; drop the colour and the app is grey.

### `Tag(Gtk.Box)` — one tag chip in a task's tags bar

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Box` | 1 | `tag` | — | `hexpand=False`, centred |
| `Gtk.Label` | 1 | `caption-heading` | — | max 15 chars, ellipsize END |
| `Gtk.Button` | 1 | — | `clicked` → removes the tag from the task | `errands-close-symbolic`, pointer cursor, tooltip "Delete Tag" |

Port targets: `lib/errands/task.rb` and `lib/errands/tag.rb` — both **exist.**
`task.rb` is 951 lines and still carries the title row, the sub-task section
and the tags bar in one class; splitting them out stays a refactor candidate.

## errands/widgets/shared/task_toolbar/toolbar.py — the per-task toolbar

38 widget occurrences. Two classes.

### `ErrandsTaskToolbar(Adw.WrapBox)`

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.WrapBox` | 1 | — | — | line spacing 6, margins 9/9/6 |
| `Gtk.Button` + `Adw.ButtonContent` | 1 each | `flat`, `caption`, + `error` when overdue | `clicked` → the date/time dialog | label is the human due date, icon `errands-calendar-symbolic`, tooltip "Start / Due Date" |
| `Gtk.Button` | 2 | `flat`, + `accent` when set | `clicked` | notes (`errands-notes-symbolic`); attachments (`errands-attachment-symbolic`) |
| `Gtk.MenuButton` | 3 | `flat`, priority also `error`/`warning`/`accent` by value | `notify::active` | priority (`errands-priority-symbolic` / `errands-priority-set-symbolic`), tags (`errands-tag-add-symbolic`), more (`errands-more-symbolic`) |
| `Gtk.Popover` | 2 | `menu`; `tags-menu` | — | priority popover; tags popover |
| `Gtk.ListBox` + `Gtk.ListBoxRow` | 1 + 4 | rows: `error`, `warning`, `accent`, — | `row-activated` → sets 1 / 5 / 9 / 0 | High, Medium, Low, None |
| `Gtk.SpinButton` + `Gtk.Adjustment` | 1 each | — | — | custom priority 0–9, under a `TitledSeparator("Custom")` |
| `Adw.StatusPage` | 1 | `compact` | — | "No Tags", icon `errands-info-symbolic`; inverse-bound to the tags list |
| `Gtk.ScrolledWindow` | 1 | — | — | tags popover, 200×200 |
| `Gtk.PopoverMenu` + `Gio.Menu` | 1 each | — | 2 sections, 3 `custom:` slots | `color` hosts the colour selector; `created` and `changed` host labels |
| `Gtk.Label` | 2 | `caption-heading` | — | "Created: <date>", "Changed: <date>", filled when the menu opens |

Repeaters: one `ErrandsToolbarTagsListItem` per known tag in the tags popover.

### `ErrandsToolbarTagsListItem(Gtk.Box)`

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Box` | 1 | — | — | spacing 6 |
| `Gtk.CheckButton` | 1 | — | `toggled` → adds/removes the tag on the task | |
| `Gtk.Label` | 1 | — | — | tag text, max 20 chars |
| `Gtk.Image` | 1 | `dim-label` | — | `errands-tag-symbolic` |

Port targets: `lib/errands/task_toolbar.rb` and
`lib/errands/toolbar_tag_row.rb` — both **exist**, on `Adwaita::WrapBox`.

## errands/widgets/shared/color_selector.py — the eight accent swatches

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Box` | 1 | — | custom `color-selected` signal | |
| `Gtk.CheckButton` | 8 | `accent-color-btn` + `accent-color-btn-{none,blue,green,yellow,orange,red,purple,brown}` | `toggled` → emits `color-selected` | radio group on the "none" button; names and tooltips None/Blue/Green/Yellow/Orange/Red/Purple/Brown |

Port target: `lib/errands/color_selector.rb` — **exists**, with a callback
passed to the constructor in place of upstream's custom GObject signal.

## errands/widgets/shared/task_toolbar/notes_window.py — notes editor

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Dialog` | 1 | — | `closed` → saves the notes and syncs | 600×600, title "Notes"; one app-wide instance held by `State` |
| `Adw.ToolbarView` + `Adw.HeaderBar` | 1 each | — | — | `RAISED` top bar style |
| `Gtk.ScrolledWindow` | 1 | — | — | |
| `GtkSource.View` + `GtkSource.Buffer` | 1 each | — | — | markdown language, line numbers, wrap, 6px margins; style scheme bound to `Adw.StyleManager.dark` (Adwaita / Adwaita-dark) |

Port target: `lib/errands/notes_dialog.rb` — **exists, with a known gap:** the
`GtkSource` typelib is not in the dev shell (see Blockers), so a plain
`Gtk::TextView` carries the buffer — no markdown highlighting, no line numbers,
no style scheme bound to the dark state.

## errands/widgets/shared/task_toolbar/datetime_window.py — date/time dialog

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Dialog` | 1 | — | `closed` → writes `due_date` / `start_date`, refreshes Today, syncs | `follows_content_size`, title "Date and Time"; one app-wide instance |
| `Adw.ViewStack` | 1 | — | — | two pages, both `errands-calendar-symbolic`: Due, Start |
| `Adw.ViewSwitcher` | 1 | — | — | WIDE policy, in the header bar |
| `Gtk.ScrolledWindow` | 2 | — | — | one per page |
| `DateTimePicker` | 2 | — | — | 12px margins |

Port target: `lib/errands/datetime_dialog.rb` — **exists.**

## errands/widgets/shared/datetime_picker.py — the date/time picker

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.Box` | 1 | — | — | vertical, spacing 12 |
| `Gtk.Label` | 1 | `title-2` | — | the human-readable date/time |
| `Gtk.Separator` | 3 | `dim-label` | — | below the label, between the time and day presets, above the calendar |
| `Gtk.SpinButton` + `Gtk.Adjustment` | 2 each | — | `value-changed` | hours 0–23, minutes 0–59, vertical, numeric |
| `Gtk.Label` | 1 | `heading` | — | ":" between the spinners |
| `Gtk.Button` + `Adw.ButtonContent` | 4 | `flat` | `clicked` → time preset | 09:00 `errands-daytime-morning-symbolic`, 13:00 `errands-theme-light-symbolic`, 17:00 `errands-daytime-sunset-symbolic`, 20:00 `errands-theme-dark-symbolic` |
| `Gtk.Button` | 3 | `flat` | `clicked` | day presets: Today, Tomorrow, Now |
| `Gtk.Button` + `Adw.ButtonContent` | 1 | `flat` | `clicked` → clears the date | "Clear", `errands-delete-all-symbolic` |
| `Gtk.Calendar` | 1 | — | `day-selected` → recomputes the datetime | at the bottom, below a third `dim-label` separator |

The picker's `datetime` is a string property (`YYYYMMDD` or `YYYYMMDDTHHMMSS`);
setting it drives the label, the two spinners and the calendar, and the label
falls back to "Set Date" when it is empty.

Port target: `lib/errands/datetime_picker.rb` — **exists.**

## errands/widgets/shared/task_toolbar/attachments_window.py — attachments

Two classes.

### `ErrandsAttachmentsWindow(Adw.Dialog)`

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Dialog` | 1 | — | `closed` → refreshes the task toolbar | `follows_content_size`, title "Attachments"; one app-wide instance |
| `Adw.ToolbarView` + `Adw.HeaderBar` | 1 each | — | — | `width_request` 360 |
| `Gtk.Button` | 1 | — | `clicked` → `Gtk.FileDialog` | `errands-add-symbolic`, tooltip "Add Attachment" |
| `Adw.StatusPage` | 1 | `compact` | — | "No Files Attached", icon `errands-attachment-symbolic` |
| `Gtk.ListBox` | 1 | `boxed-list` | — | NONE selection, shown only when there is at least one attachment |
| `Gtk.ScrolledWindow` | 1 | — | — | |

### `ErrandsAttachment(Adw.ActionRow)` — one attached file

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ActionRow` | 1 | — | `activated` → `Gtk.FileLauncher.launch` | activatable, tooltip "Open File", title is the basename |
| `Gtk.Button` | 2 | `flat`, delete also `error` | `clicked` | open containing folder (`errands-folder-symbolic`); delete (`errands-trash-symbolic`) |

Port targets: `lib/errands/attachments_dialog.rb` and
`lib/errands/attachment_row.rb` — both **exist.**

## errands/widgets/today/today.py — the Today page

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Bin` | 1 | — | — | stack page `errands_today_page` |
| `Adw.ToolbarView` + `Adw.HeaderBar` + `Adw.WindowTitle` | 1 each | — | — | title "Today" |
| `Adw.StatusPage` | 1 | `compact` | — | "No Tasks for Today", icon `errands-info-symbolic`; inverse-bound to the content |
| `Gtk.ScrolledWindow` + `Adw.Clamp` | 1 each | — | — | max 1000, tighten 300 |
| `Gtk.Box` | 1 | — | — | the task column, 32px bottom margin |

Repeaters: one `TodayTask` per uncompleted, untrashed task whose due date is
today or earlier.

Port target: `lib/errands/today.rb` — **absent.**

## errands/widgets/today/today_task.py — one task card on Today

A flattened `Task`: the same `Adw.ActionRow` title row (`transparent`,
`rounded-corners`, 60px), the same `Gtk.CheckButton` (`selection-mode`), the
same four-item `task.*` popover menu, the same `Adw.EntryRow` edit row with its
cancel button, the same tags bar and progress bar, and the same lazily-built
`ErrandsTaskToolbar` — but **no sub-tasks, no drag-and-drop, no top drop area
and no expand indicator.** 13 widget occurrences.

Port target: `lib/errands/today_task.rb` — **absent.**

## errands/widgets/today/today_sidebar_row.py — the Today sidebar row

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Gtk.ListBoxRow` | 1 | `sidebar-item` | `activate` → shows the Today page, sets `last-open-list` | `height_request` 45 |
| `Gtk.Image` | 1 | — | — | `errands-calendar-symbolic` |
| `Gtk.Label` | 1 | — | — | "Today", `hexpand`, START |
| `Gtk.Button` | 1 | `dim-label`, `caption`, `flat`, `circular` | — | counter, `can_target=False`, blank at zero |

Port target: `lib/errands/today_sidebar_row.rb` — **absent.**

## errands/widgets/tags/tags.py — the Tags page

Two classes.

### `Tags(Adw.Bin)`

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.Bin` | 1 | — | — | stack page `errands_tags_page` |
| `Adw.ToolbarView` + `Adw.HeaderBar` + `Adw.WindowTitle` | 1 each | — | — | title "Tags" |
| `Adw.StatusPage` | 1 | `compact` | — | "No Tags Found" / "Add new Tags in the entry above", icon `errands-info-symbolic` |
| `Gtk.ListBox` | 2 | `boxed-list` | — | one holding the add-tag entry row, one holding the tag rows |
| `Adw.EntryRow` | 1 | — | `entry-activated` → adds a tag | "Add new Tag", `height_request` 60, `activatable=False` |
| `Adw.Clamp` | 2 | — | — | max 1000, tighten 300 |
| `Gtk.ScrolledWindow` | 1 | — | — | |

### `Tag(Adw.ActionRow)` — one tag row

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ActionRow` | 1 | — | — | title is the tag text |
| `Gtk.Button` | 2 | delete: `flat`, `error`; counter: `flat`, `dim-label`, `circular` | `clicked` → deletes the tag everywhere | delete `errands-trash-symbolic` as prefix; task counter as suffix, `can_target=False` |
| `Gtk.Image` | 1 | — | — | `errands-right-symbolic`, visibility bound bidirectionally to `activatable` |

Port targets: `lib/errands/tags.rb` and `lib/errands/tag_row.rb` — **absent.**
Note the name clash to resolve: upstream has two different `Tag` classes, one
in `task.py` (the chip) and one in `tags/tags.py` (the row).

## errands/widgets/tags/tags_sidebar_row.py — the Tags sidebar row

Same shape as the Today row: `Gtk.ListBoxRow` (`sidebar-item`, 45px, `activate`
→ shows the Tags page and refreshes it), `Gtk.Image` `errands-tag-symbolic`,
`Gtk.Label` "Tags", counter `Gtk.Button` (`dim-label`, `caption`, `flat`,
`circular`) showing the number of tags.

Port target: `lib/errands/tags_sidebar_row.rb` — **absent.**

## errands/widgets/trash/trash.py — the Trash page

Two classes.

### `Trash(Adw.Bin)`

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.Bin` | 1 | — | — | stack page `errands_trash_page` |
| `Adw.ToolbarView` + `Adw.HeaderBar` + `Adw.WindowTitle` | 1 each | — | — | title "Trash" |
| `Gtk.Button` | 2 | `flat` | `clicked` | clear (`errands-trash-symbolic`, start); restore (`errands-restore-symbolic`, end) — both inverse-bound to the status page, so they vanish when the trash is empty |
| `Adw.StatusPage` | 1 | `compact` | — | "Empty Trash" / "No deleted items", icon `errands-trash-symbolic` |
| `Gtk.ListBox` | 1 | `transparent` | — | NONE selection |
| `Gtk.ScrolledWindow` + `Adw.Clamp` | 1 each | — | — | max 1000, tighten 300 |
| `ConfirmDialog` | 1 | — | — | "Tasks will be permanently deleted", DESTRUCTIVE |

Repeaters: one `TrashItem` per trashed, non-deleted task.

### `TrashItem(Adw.ActionRow)` — one trashed task

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.ActionRow` | 1 | `card` | — | 60px, `title_selectable`, margins 6/6; title is the task text, subtitle is its list name |
| `Gtk.Button` | 1 | `circular`, `flat` | `clicked` → restores the task and its parents | `errands-check-toggle-symbolic`, tooltip "Restore" |

Port targets: `lib/errands/trash.rb` and `lib/errands/trash_item.rb` —
**absent.**

## errands/widgets/trash/trash_sidebar_row.py — the Trash sidebar row

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Gtk.ListBoxRow` | 1 | `sidebar-item`, `sidebar-item-trash` | `activate` → shows the Trash page | 45px |
| `Gtk.Image` | 1 | — | — | `errands-trash-symbolic` / `errands-trash-full-symbolic` by size |
| `Gtk.Label` | 1 | — | — | "Trash" |
| `Gtk.Button` | 1 | `dim-label`, `caption`, `flat`, `circular` | — | counter |
| `Gtk.DropTarget` | 1 | — | `drop` → trashes the dropped task | type `Task`, MOVE |
| `Gtk.GestureClick` / `Gtk.GestureLongPress` | 1 each | — | `released` / `pressed` → popup | button 3; touch |
| `Gtk.PopoverMenu` + `Gio.Menu` | 1 each | — | 2 items | Clear `trash_row.clear`, Restore `trash_row.restore`; both disabled when the trash is empty |

Port target: `lib/errands/trash_sidebar_row.rb` — **absent.**

## errands/widgets/shared/components/dialogs.py — the confirm dialog

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.MessageDialog` | 1 | — | `response` | heading "Are you sure?", body and confirm label supplied by the caller, responses cancel / confirm, confirm appearance supplied (DESTRUCTIVE for both callers), `hide_on_close`, presents itself on construction |

Used by: delete a list, clear the trash.

Port target: `lib/errands/confirm_dialog.rb` — **exists**, on
`Adwaita::AlertDialog`.

## errands/widgets/preferences.py — the preferences dialog

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.PreferencesDialog` | 1 | — | — | reached by `app.preferences` / `<primary>comma` |
| `Adw.PreferencesPage` | 2 | — | — | "General" `errands-settings-symbolic`; "Sync" `errands-sync-symbolic` |
| `Adw.PreferencesGroup` | 4 | — | — | Application Theme, Task Lists, Notifications and Background, Sync |
| `Adw.ActionRow` | 4 | — | — | System / Light / Dark theme (icons `errands-theme-{system,light,dark}-symbolic`), Test Connection |
| `Gtk.CheckButton` | 3 | — | `toggled` → sets the colour scheme and `theme` (0 / 1 / 4) | one radio group, each the row's activatable widget |
| `Adw.ComboRow` | 2 | — | `notify::selected` | "Add new Tasks" (At the Bottom / At the Top, `errands-add-symbolic`); "Sync Provider" (Disabled / Nextcloud / CalDAV, `errands-sync-symbolic`) |
| `Adw.SwitchRow` | 3 | — | `notify::active` | Show Notifications (`errands-notification-symbolic`); Run in Background (+ subtitle, `errands-progressbar-symbolic`); Launch on Startup (+ subtitle, re-requests the background portal) |
| `Adw.EntryRow` | 2 | — | — | Server URL (with an info button), Username — both bound to GSettings |
| `Adw.PasswordEntryRow` | 1 | — | `changed` → stores the secret per account | Password |
| `Gtk.MenuButton` + `Gtk.Popover` + `Gtk.Label` | 1 each | `flat` | — | the URL info button, `errands-info-symbolic`, tooltip "Info", wrapped markup text about http:// vs https:// |
| `Gtk.Button` | 1 | — | `clicked` → tests the connection | "Test", centred |
| `Adw.Toast` | 1 | — | — | 2s: "Connected" / "Authorization failed" / "Could not locate server. Check network and url." / "Can't connect" / "Can't connect. Check credentials" |

Conditional: URL, username and password are visible only for providers 1–2;
Test Connection only for providers > 0; the forms pre-fill from GNOME Online
Accounts when the matching setting is empty.

Port target: `lib/errands/preferences_dialog.rb` — **absent.**

---

## Support modules the components depend on

Not user-facing components, but no component works without them. `data.rb`,
`settings.rb`, `markup.rb`, `animation.rb`, `utils.rb`, `logging.rb`,
`style.rb` and a new `icons.rb` (which registers the 42 `errands-*-symbolic`
icons the tables above name) now **exist**. The sync stack —
`sync.rb`, `caldav_provider.rb`, `nextcloud_provider.rb`, `goa.rb` — plus
`notifications.rb` and `translations.rb` are still **absent**.

| Upstream | Port target | What it is |
|---|---|---|
| `errands/lib/data.py` | `lib/errands/data.rb` | `UserData`, `TaskData`, `TaskListData` — the store, plus `to_ical` / `from_ical` |
| `errands/lib/gsettings.py` + `data/io.github.mrvladus.List.gschema.xml.in` | `lib/errands/settings.rb` | the 12 settings keys (`width`, `height`, `maximized`, `theme`, `last-open-list`, `sync-provider`, `sync-url`, `sync-username`, `task-list-new-task-position-top`, `launch-on-startup`, `run-in-background`, `notifications-enabled`), `bind`, and the libsecret-backed `get_secret` / `set_secret` |
| `errands/lib/markup.py` | `lib/errands/markup.rb` | the Pango markup and strike-through applied to task titles |
| `errands/lib/animation.py` | `lib/errands/animation.rb` | `scroll(scrolled_window, down)` — `Adw.TimedAnimation` used by the task list |
| `errands/lib/utils.py` | `lib/errands/utils.rb` | `get_children`, `get_human_datetime`, `rgb_to_hex`, `threaded` |
| `errands/lib/notifications.py` | `lib/errands/notifications.rb` | the daemon that polls due dates and sends `Gio.Notification`s |
| `errands/lib/sync/sync.py` | `lib/errands/sync.rb` | `Sync.sync`, `Sync.test_connection`, the sidebar's sync indicator |
| `errands/lib/sync/providers/caldav.py` | `lib/errands/caldav_provider.rb` | CalDAV provider |
| `errands/lib/sync/providers/nextcloud.py` | `lib/errands/nextcloud_provider.rb` | Nextcloud provider (a CalDAV subclass) |
| `errands/lib/goa.py` | `lib/errands/goa.rb` | reads GNOME Online Accounts credentials to pre-fill the sync forms |
| `errands/lib/logging.py` | `lib/errands/logging.rb` | `Log.init/debug/info/error` |
| `data/resources/style.css`, `style-dark.css` | `lib/errands/style.rb` | the 46 app CSS classes, loaded through a `Gtk::CssProvider` |
| `po/` (30 languages + `errands.pot`) | `lib/errands/translations.rb` | gettext domain `errands`; every user-facing string above is `_()`-wrapped |

`errands/lib/plugins.py` is commented out at its only call site upstream and is
not ported. `errands/errands.py` is the meson-templated launcher; the port's
equivalent is `exe/errands`.

### Icons

`data/icons/hicolor/symbolic/apps/` ships 42 `errands-*-symbolic.svg` icons
plus the two app icons. Every `icon_name` in the tables above that starts
`errands-` comes from there, so the port needs the icon theme registered (a
`Gtk::IconTheme` search path or a GResource) before any of those buttons render.

---

## Blockers

1. **`GtkSource` typelib is not in the dev shell.** `GObjectIntrospection::Repository.default.require('GtkSource')` raises `TypelibNotFound`, and `require 'gtk_source'` fails. The notes dialog is upstream's only use of it (markdown syntax highlighting, line numbers, Adwaita/Adwaita-dark style schemes). Either add gtksourceview to `flake.nix` or port `notes_dialog.rb` onto a plain `Gtk::TextView` and record the parity gap.
2. **`Secret` typelib is not in the dev shell.** `GSettings.get_secret` / `set_secret` store the sync password in libsecret. Without it the password field cannot persist, which blocks the Sync preferences page end to end.
3. **`Xdp` (libportal) typelib is not in the dev shell.** `ErrandsApplication.run_in_background` requests the background/autostart portal. This blocks the "Launch on Startup" switch row and the autostart behaviour behind it.
4. **No iCalendar or CalDAV gem in the bundle.** `Gemfile` carries only `gtk4` and `adwaita` for the app. Upstream's list import (`app.import`), list export, task export and the whole Sync page rest on `to_ical` / `from_ical` and the `caldav` Python library. The port needs gems chosen and vendored through `gemset.nix` before those components can exist.
5. **`Gtk::DropTarget.new(type: Task, ...)` has no direct Ruby equivalent.** Upstream types four drop targets on the Python `Task` class itself. Ruby GTK cannot register an arbitrary Ruby class as a GType for this, so task drag-and-drop — reorder, re-parent, move between lists, drop on a list row, drop on Trash — needs a different carrier (a `GLib::Value` of a string uid, or a small `GObject` subclass). This touches `task.rb`, `task_list.rb`, `task_list_sidebar_row.rb` and `trash_sidebar_row.rb`.
6. **`Adwaita::MessageDialog` is deprecated** in the libadwaita the dev shell carries (1.9). It is still bound and still works, but `Adwaita::AlertDialog` is present and is the right target for the three dialogs that use it (Add List, Rename List, ConfirmDialog).
Status as of 2026-11-02: blockers 1-4 still stand. Blocker 5 is resolved — the
port's drop targets carry the task uid as a `String` and look the task up
through `State`. Blocker 6 is resolved — `Adwaita::AlertDialog` is used for Add
List, Rename List and ConfirmDialog. A new one found while porting: `Gtk::ShortcutsWindow`
cannot be constructed from the bindings at all, so the shortcuts window is built
with `Adwaita::ShortcutsDialog`.

7. **Two upstream drifts to decide on, not inherit silently.** The shortcuts window advertises `F9` "Toggle Details" with no such accelerator in the source, and `<Control>F` for sync while the source binds `F5` and `<primary>f`. `app.quit` is also registered twice in `window.py` with different accelerator sets.

---

## Port status roll-up (2026-11-02)

| Upstream file | Port file | Kind | Present |
|---|---|---|:-:|
| `errands/application.py` | `lib/errands/application.rb` | application | yes |
| `errands/state.py` | `lib/errands/state.rb` | support | yes |
| `errands/widgets/window.py` | `lib/errands/window.rb` | window | yes |
| `errands/widgets/window.py` (`_about`) | `lib/errands/about_dialog.rb` | dialog | yes |
| `errands/widgets/window.py` (`_import`) | `lib/errands/import_dialog.rb` | dialog | yes |
| `errands/widgets/window.py` (empty state) | `lib/errands/window.rb` (`StatusPageView`) | empty state | yes |
| `data/resources/gtk/help-overlay.ui` | `lib/errands/shortcuts_dialog.rb` | shortcuts window | partial |
| `errands/widgets/loading_page.py` | `lib/errands/loading_page.rb` | page | yes |
| `errands/widgets/sidebar.py` | `lib/errands/sidebar.rb` | sidebar | yes |
| `errands/widgets/sidebar.py` (Add List) | `lib/errands/add_list_dialog.rb` | dialog | yes |
| `errands/widgets/shared/titled_separator.py` | `lib/errands/titled_separator.rb` | widget | yes |
| `errands/widgets/task_list/task_list_sidebar_row.py` | `lib/errands/task_list_sidebar_row.rb` | row | yes |
| `errands/widgets/task_list/task_list_sidebar_row.py` (Rename) | `lib/errands/rename_list_dialog.rb` | dialog | yes |
| `errands/widgets/task_list/task_list.py` | `lib/errands/task_list.rb` | page | yes |
| `errands/widgets/task.py` (`Task`) | `lib/errands/task.rb` | widget | yes |
| `errands/widgets/task.py` (`Tag`) | `lib/errands/tag.rb` | widget | yes |
| `errands/widgets/shared/task_toolbar/toolbar.py` (`ErrandsTaskToolbar`) | `lib/errands/task_toolbar.rb` | toolbar | yes |
| `errands/widgets/shared/task_toolbar/toolbar.py` (`ErrandsToolbarTagsListItem`) | `lib/errands/toolbar_tag_row.rb` | row | yes |
| `errands/widgets/shared/color_selector.py` | `lib/errands/color_selector.rb` | widget | yes |
| `errands/widgets/shared/task_toolbar/notes_window.py` | `lib/errands/notes_dialog.rb` | dialog | yes (no GtkSource) |
| `errands/widgets/shared/task_toolbar/datetime_window.py` | `lib/errands/datetime_dialog.rb` | dialog | yes |
| `errands/widgets/shared/datetime_picker.py` | `lib/errands/datetime_picker.rb` | widget | yes |
| `errands/widgets/shared/task_toolbar/attachments_window.py` (`ErrandsAttachmentsWindow`) | `lib/errands/attachments_dialog.rb` | dialog | yes |
| `errands/widgets/shared/task_toolbar/attachments_window.py` (`ErrandsAttachment`) | `lib/errands/attachment_row.rb` | row | yes |
| `errands/widgets/shared/components/dialogs.py` | `lib/errands/confirm_dialog.rb` | dialog | yes |
| `errands/widgets/today/today.py` | `lib/errands/today.rb` | page | yes (2026-11-07) |
| `errands/widgets/today/today_task.py` | `lib/errands/today_task.rb` | widget | yes (2026-11-07) |
| `errands/widgets/today/today_sidebar_row.py` | `lib/errands/today_sidebar_row.rb` | row | yes (2026-11-07) |
| `errands/widgets/tags/tags.py` (`Tags`) | `lib/errands/tags.rb` | page | yes (2026-11-07) |
| `errands/widgets/tags/tags.py` (`Tag`) | `lib/errands/tag_row.rb` | row | yes (2026-11-07) |
| `errands/widgets/tags/tags_sidebar_row.py` | `lib/errands/tags_sidebar_row.rb` | row | yes (2026-11-07) |
| `errands/widgets/trash/trash.py` (`Trash`) | `lib/errands/trash.rb` | page | yes (2026-11-07) |
| `errands/widgets/trash/trash.py` (`TrashItem`) | `lib/errands/trash_item.rb` | row | yes (2026-11-07) |
| `errands/widgets/trash/trash_sidebar_row.py` | `lib/errands/trash_sidebar_row.rb` | row | yes (2026-11-07) |
| `errands/widgets/preferences.py` | `lib/errands/preferences_dialog.rb` | dialog | yes (2026-11-07) |
| `errands/lib/data.py` | `lib/errands/data.rb` | support | yes |
| `errands/lib/gsettings.py` + gschema | `lib/errands/settings.rb` | support | yes |
| `errands/lib/markup.py` | `lib/errands/markup.rb` | support | yes |
| `errands/lib/animation.py` | `lib/errands/animation.rb` | support | yes |
| `errands/lib/utils.py` | `lib/errands/utils.rb` | support | yes |
| `errands/lib/logging.py` | `lib/errands/logging.rb` | support | yes |
| `data/resources/style.css`, `style-dark.css` | `lib/errands/style.rb` | stylesheet | yes |
| `data/icons/hicolor/symbolic/apps/*.svg` | `lib/errands/icons.rb` | icon theme | yes |
| `errands/lib/notifications.py` | `lib/errands/notifications.rb` | support | yes (2026-11-07) |
| `errands/lib/sync/sync.py` | `lib/errands/sync.rb` | support | yes (2026-11-07) |
| `errands/lib/sync/providers/caldav.py` | `lib/errands/caldav_provider.rb` | support | yes (2026-11-07) |
| `errands/lib/sync/providers/nextcloud.py` | `lib/errands/nextcloud_provider.rb` | support | yes (2026-11-07) |
| `errands/lib/goa.py` | `lib/errands/goa.rb` | support | yes (2026-11-07) |
| `po/` (30 languages) | `lib/errands/translations.rb` | translations | yes (2026-11-07) |

---

## 2026-11-07 re-survey (updated same day, after plugins + ashpd drive)

Re-checked `lib/errands/` against this inventory's "Port status roll-up." Every
row the 2026-11-02 pass marked `**no**` now has a file: `today.rb`,
`today_task.rb`, `today_sidebar_row.rb`, `tags.rb`, `tag_row.rb`,
`tags_sidebar_row.rb`, `trash.rb`, `trash_item.rb`, `trash_sidebar_row.rb`,
`preferences_dialog.rb`, `notifications.rb`, `sync.rb`, `caldav_provider.rb`,
`nextcloud_provider.rb`, `goa.rb` and `translations.rb` all exist (flipped to
`yes (2026-11-07)` in the table above). `lib/` now holds 44 files under
`lib/errands/` plus `lib/errands.rb`. **File presence is not the same claim as
component parity** — none of these 16 newly-present files were re-scanned
widget-by-widget against the per-file tables above in this pass; that is
`component-parity`'s job, not this survey's.

### Gem wiring (checked, since it was flagged as a blocker above)

Blocker 4 ("No iCalendar or CalDAV gem in the bundle") and the general
GOA/ashpd wiring have moved since 2026-11-02:

- `errands-rb.gemspec` now depends on `gtk4`, `adwaita`, `glib2`, `ashpd` and
  `goa-rb`.
- `nix/Gemfile` and `nix/gemset.nix` list `ashpd` and `goa-rb`; `flake.nix`'s
  `gemdir` points at `./nix` (not the root Gemfile), and its `gtkStack` /
  `typelibPath` are wired for both gems' native dependencies.
- `lib/errands/goa.rb` now calls the `goa-rb` gem's `Goa` binding directly
  (`require 'goa-rb'`) instead of hand-rolling GObject Introspection calls —
  the thing this skill's instructions warn to check for was not found here.

Not re-verified in this pass: actually loading the gems
(`nix develop --command ruby -e 'require "ashpd"; ...'` /
`require "goa-rb"; puts Goa.constants.size'`). The wiring looks correct by
inspection only.

### Gap closed: `errands/lib/plugins.py` → `lib/errands/plugins.rb`

Ported after this re-survey flagged it: `PluginBase` and `PluginsLoader` now
exist in `lib/errands/plugins.rb` and are wired into
`lib/errands/application.rb#startup`. Ruby-side shape: a `plugin.rb` entry
file instead of `plugin.py`, a plugin-local `Gemfile` instead of
`requirements.txt`, `require` instead of `importlib.import_module`. The
earlier claim in this document that upstream's call site is commented out
was wrong — confirmed again here — and is left struck through above rather
than silently deleted.

### Background portal (blocker 3) — checked, not resolved by the gem

`lib/errands/application.rb#run_in_background` now `require`s `ashpd` and
calls it for real (`Ashpd.const_defined?(:Background)` /
`Ashpd.constants`), from both startup and the preferences dialog's "Launch
on Startup" switch — confirmed live, not a rescued `NameError` and not a
drive-script stub, by `test/drive_main_window.rb`'s added step (flips the
switch, asserts the logged call count increases; 145/145 checks, three
consecutive `DRIVE OK` runs). The result of that real call: **ashpd 0.1.1
binds `Account`, `Camera`, `OpenUri`, `Screenshot`, `Settings` and `Trash`,
but not the `Background` portal** upstream's autostart request needs, so the
request is logged and skipped. Blocker 3 therefore still stands as a gem
limitation, not a missing-wiring defect — the wiring is correct and does the
right thing with what the gem currently exposes.

### Gem wiring — re-verified end to end

`ashpd` and `goa-rb` are both declared in `errands-rb.gemspec`, both listed
in `nix/Gemfile`/`nix/gemset.nix`, and both actually `require`d and called
from live code paths: `ashpd` from `application.rb` (above) and `goa-rb`'s
`Goa` from `lib/errands/goa.rb` and `preferences_dialog.rb`'s provider
picker. No gemspec runtime dependency was found with zero callers in this
pass.

### Shortcuts dialog substitution — flag, not a fix

`lib/errands/shortcuts_dialog.rb`'s own comment says `Gtk::ShortcutsWindow`
"is unusable from the Ruby bindings (constructing one raises...)" and builds
an `Adwaita::ShortcutsDialog` substitute instead of the real widget named in
the roll-up table above as "partial." This claim should be re-verified
against the `ruby-gtk` skill before being accepted at face value — a
claimed-unusable binding has turned out to be wrong before in this fleet, and
"the bindings have no X" is exactly the kind of phrase worth treating with
suspicion rather than inheriting silently.
