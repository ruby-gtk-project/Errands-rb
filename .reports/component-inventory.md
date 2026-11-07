# Errands component inventory

Upstream: `io.github.mrvladus.List` ("Errands"), Python/PyGObject, read from
`origin/main` in this fork. Port target: `ruby` branch, `lib/errands/*.rb`.

This is a survey, not a verdict on quality — it says which upstream file maps
to which port file and whether that port file exists. It does not check
whether the port file's widgets, CSS classes, signals and actions actually
match upstream (that is `component-parity`'s job, file by file, next).

## Status summary

Every upstream widget/dialog/page file that contributes user-facing UI has a
corresponding file in `lib/errands/` already. The `ruby` branch is not a
skeleton: 44 files in `lib/errands/`, all present. Two things still need
checking in a follow-up pass, not this one:

- **Parity, not just presence.** A file existing is not proof its widget
  tree, CSS classes, signals and actions match. That is `component-parity`'s
  job, run file-by-file.
- **GOA/ashpd gem wiring was already done** by whoever wrote this port:
  `errands-rb.gemspec` depends on `gtk4`, `adwaita`, `glib2`, `ashpd` and
  `goa-rb`; `nix/Gemfile` and `nix/gemset.nix` list `ashpd` and `goa-rb`;
  `flake.nix`'s `gtkStack`/`typelibPath` are wired for both. `lib/errands/goa.rb`
  calls the `goa-rb` gem's `Goa` binding rather than hand-rolling GObject
  Introspection calls. Not re-verified at the typelib-load level in this pass
  (`ruby -e 'require "ashpd"...'` / `require "goa-rb"...'` was not run here);
  do that before trusting it.

## Per-file inventory

| Upstream file | Kind | → `lib/` path | Exists |
|---|---|---|---|
| `errands/application.py` | app class (actions, accelerators, entry point) | `lib/errands/application.rb` | yes |
| `errands/errands.py` | entry point script | `exe/errands` | yes |
| `errands/widgets/window.py` | main window, view stack, split view, status/syncing pages, app actions (about, sync, import, quit, preferences) | `lib/errands/window.rb` | yes |
| `errands/widgets/window.py` (`_about` inline dialog) | About dialog | `lib/errands/about_dialog.rb` | yes |
| `errands/widgets/window.py` (`_import` inline dialog) | Import-list file dialog | `lib/errands/import_dialog.rb` | yes |
| `errands/widgets/loading_page.py` | loading status page | `lib/errands/loading_page.rb` | yes |
| `errands/widgets/preferences.py` (`PreferencesWindow`) | preferences dialog (sync providers, run-in-background, notifications) | `lib/errands/preferences_dialog.rb` | yes |
| `errands/widgets/sidebar.py` (`Sidebar`) | sidebar: header bar, main menu, add-list button, list box of rows, sync spinner, empty-state status page | `lib/errands/sidebar.rb` | yes |
| `errands/widgets/sidebar.py` (`_on_add_list_btn_clicked` inline dialog) | Add-list dialog | `lib/errands/add_list_dialog.rb` | yes |
| `errands/widgets/shared/color_selector.py` | color picker row (list/tag color) | `lib/errands/color_selector.rb` | yes |
| `errands/widgets/shared/datetime_picker.py` | date/time picker widget | `lib/errands/datetime_picker.rb` | yes |
| `errands/widgets/shared/titled_separator.py` | section header row for list boxes | `lib/errands/titled_separator.rb` | yes |
| `errands/widgets/shared/sidebar_item.py` (`ErrandsSidebarItem`) | upstream stub base class, `__build_ui` is `pass` — no widgets to port | — | n/a (dead stub upstream) |
| `errands/widgets/shared/task_toolbar/toolbar.py` (`ErrandsTaskToolbar`) | per-task toolbar (priority, due date, notes, attachments, tags button, pin, delete) | `lib/errands/task_toolbar.rb` | yes |
| `errands/widgets/shared/task_toolbar/toolbar.py` (`ErrandsToolbarTagsListItem`) | one tag chip inside the toolbar's tags popover | `lib/errands/toolbar_tag_row.rb` | yes |
| `errands/widgets/shared/task_toolbar/attachments_window.py` (`ErrandsAttachmentsWindow`) | attachments dialog | `lib/errands/attachments_dialog.rb` | yes |
| `errands/widgets/shared/task_toolbar/attachments_window.py` (`ErrandsAttachment`) | one attachment row inside that dialog | `lib/errands/attachment_row.rb` | yes |
| `errands/widgets/shared/task_toolbar/datetime_window.py` | due/start date-time dialog | `lib/errands/datetime_dialog.rb` | yes |
| `errands/widgets/shared/task_toolbar/notes_window.py` | notes editor dialog | `lib/errands/notes_dialog.rb` | yes |
| `errands/widgets/shared/components/dialogs.py` (`ConfirmDialog`) | generic yes/no confirmation dialog | `lib/errands/confirm_dialog.rb` | yes |
| `errands/widgets/shared/components/boxes.py` | generic `Box`/`FlowBox`/`ListBox` wrappers — infrastructure, not a distinct on-screen component | — (house style builds these inline with `.tap`) | n/a (infrastructure) |
| `errands/widgets/shared/components/buttons.py` | generic `Button`/`CheckButton`/`ToggleButton`/`SpinButton`/`InfoButton` wrappers | — | n/a (infrastructure) |
| `errands/widgets/shared/components/entries.py` | generic `EntryRow`/`Entry` wrappers | — | n/a (infrastructure) |
| `errands/widgets/shared/components/header_bar.py` | `Adw.HeaderBar` factory helper | — | n/a (infrastructure) |
| `errands/widgets/shared/components/menus.py` | `Gio.Menu` builder helpers | — | n/a (infrastructure) |
| `errands/widgets/shared/components/toolbar_view.py` | `Adw.ToolbarView` factory helper | — | n/a (infrastructure) |
| `errands/widgets/shared/components/controllers.py` | empty file upstream (0 lines of content) | — | n/a (nothing to port) |
| `errands/widgets/tags/tags.py` (`Tags`) | tags page: list box of all tags, empty state | `lib/errands/tags.rb` | yes |
| `errands/widgets/tags/tags.py` (`Tag`) | one tag row in that list | `lib/errands/tag.rb` + `lib/errands/tag_row.rb` | yes (split across two files) |
| `errands/widgets/tags/tags_sidebar_row.py` | "Tags" sidebar entry | `lib/errands/tags_sidebar_row.rb` | yes |
| `errands/widgets/task_list/task_list.py` (`TaskList`) | one task list's page: toolbar, entry, task list box, filters | `lib/errands/task_list.rb` | yes |
| `errands/widgets/task_list/task_list_sidebar_row.py` | one task-list row in the sidebar, with its menu (rename/delete/export/color) | `lib/errands/task_list_sidebar_row.rb` | yes |
| `errands/widgets/task_list/task_list_sidebar_row.py` (`_rename` inline dialog) | rename-list dialog | `lib/errands/rename_list_dialog.rb` | yes |
| `errands/widgets/task.py` | one task row (checkbox, title, sub-tasks, toolbar, expander) | `lib/errands/task.rb` | yes |
| `errands/widgets/today/today.py` | Today page: grouped task list, empty state | `lib/errands/today.rb` | yes |
| `errands/widgets/today/today_sidebar_row.py` | "Today" sidebar entry | `lib/errands/today_sidebar_row.rb` | yes |
| `errands/widgets/today/today_task.py` | one task row as shown on the Today page | `lib/errands/today_task.rb` | yes |
| `errands/widgets/trash/trash.py` (`Trash`) | Trash page: list box, empty state, "empty trash" action | `lib/errands/trash.rb` | yes |
| `errands/widgets/trash/trash.py` (`TrashItem`) | one deleted-task row with restore/delete-forever | `lib/errands/trash_item.rb` | yes |
| `errands/widgets/trash/trash_sidebar_row.py` | "Trash" sidebar entry, badge count | `lib/errands/trash_sidebar_row.rb` | yes |
| `errands/lib/animation.py` | shake/highlight animation helpers | `lib/errands/animation.rb` | yes |
| `errands/lib/data.py` | on-disk task/list/tag data model (`ErrandsData`, `TagsData`, `TaskListData`, `TaskData`, `UserDataJSON`, `ThreadSafeWriter`) | `lib/errands/data.rb`, `lib/errands/tag.rb`, `lib/errands/tags.rb` (tag data lives partly alongside the tag widgets — verify split in parity pass) | yes |
| `errands/lib/goa.py` | GNOME Online Accounts credential lookup | `lib/errands/goa.rb` (now via `goa-rb` gem) | yes |
| `errands/lib/gsettings.py` | GSettings wrapper (12 keys) | `lib/errands/settings.rb` (12 keys) | yes |
| `errands/lib/logging.py` | app logger | `lib/errands/logging.rb` | yes |
| `errands/lib/markup.py` | Pango markup escaping helpers | `lib/errands/markup.rb` | yes |
| `errands/lib/notifications.py` | desktop notifications | `lib/errands/notifications.rb` | yes |
| `errands/lib/plugins.py` | third-party plugin loader (scans a user plugins dir, pip-installs deps, imports `plugin.py`) | — | **missing** — no `lib/errands/plugins.rb`, no plugin loading in `lib/errands/application.rb` |
| `errands/lib/sync/sync.py` | sync orchestration | `lib/errands/sync.rb` | yes |
| `errands/lib/sync/providers/caldav.py` | CalDAV sync provider | `lib/errands/caldav_provider.rb` | yes |
| `errands/lib/sync/providers/nextcloud.py` | Nextcloud sync provider | `lib/errands/nextcloud_provider.rb` | yes |
| `errands/lib/utils.py` | misc widget/collection helpers | `lib/errands/utils.rb` | yes |
| `errands/state.py` | app-wide singleton state registry | `lib/errands/state.rb` | yes |
| `data/resources/gtk/help-overlay.ui` | keyboard shortcuts window | `lib/errands/shortcuts_dialog.rb` | yes — **but port comment claims `Gtk::ShortcutsWindow` "is unusable from the Ruby bindings (constructing one raises...)" and builds a substitute dialog instead of the real widget.** This needs re-checking against the `ruby-gtk` skill before being accepted; a claimed-unusable binding is exactly the kind of claim that has turned out to be wrong before. |
| `data/io.github.mrvladus.List.gschema.xml.in` | GSettings schema (12 keys) | consumed by `lib/errands/settings.rb` | yes (key count matches) |
| `data/resources/errands.gresource.xml` | GResource manifest (icons, help-overlay.ui, style.css) | no GResource step in the port; icons/CSS are inlined instead | yes, substituted — see `lib/errands/icons.rb` and `lib/errands/style.rb` below |
| `data/icons/hicolor/**/*.svg` (46 icons) | app + symbolic icon set | `lib/errands/icons.rb` (embeds SVG markup, installs into an icon-theme search path) | yes |
| `data/resources/style.css`, `data/resources/style-dark.css` | app stylesheet (light/dark) | `lib/errands/style.rb` | yes |
| `data/io.github.mrvladus.List.metainfo.xml.in.in` | app metadata (used for About dialog version/description) | consumed by `lib/errands/about_dialog.rb` | yes |
| `data/io.github.mrvladus.List.desktop.in.in` | desktop launcher entry | not a `lib/` component; packaging concern, out of scope for this inventory | n/a |
| `po/*.po` (30 locales) + `po/errands.pot` | message catalogue | `lib/errands/translations.rb` reads `.po` directly (no gettext binding) | yes — translation-parity (msgid-by-msgid, locale-by-locale) is a separate check, not run in this pass |

## Gap found

- **`errands/lib/plugins.py` has no port.** There is no `lib/errands/plugins.rb`
  and nothing in `lib/errands/application.rb` scans a user plugins directory,
  installs a plugin's `requirements.txt`, or loads a `plugin.py`. This is a
  real missing feature, not a stub: upstream's `PluginsLoader` is wired into
  the application at startup. Whoever ports it next should decide how a
  Python-style `importlib`-loaded plugin maps to Ruby (it does not map
  mechanically), but the absence should be tracked, not waved away as
  "out of scope."

## Not yet checked (next steps, not this pass)

- `component-parity` per file — the table above says a `lib/errands/*.rb` file
  *exists* for a given upstream file, not that its widget tree, CSS classes,
  signals and actions match it.
- `test-parity` and `translation-parity` are untouched by this survey.
- The `shortcuts_dialog.rb` claim that `Gtk::ShortcutsWindow` cannot be
  constructed from the Ruby bindings should be re-verified against the
  `ruby-gtk` skill rather than taken on the comment's word.
- `ashpd` / `goa-rb` typelib load was not re-run in this session
  (`nix develop --command ruby -e 'require "ashpd"; ...'` /
  `require "goa-rb"; puts Goa.constants.size'`) — the gemspec/Gemfile/flake
  wiring looks correct by inspection but has not been executed here.
