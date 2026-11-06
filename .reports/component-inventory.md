# Errands-rb component inventory

Upstream is `io.github.mrvladus.List` ("Errands"), a GNOME To-Do app written in
Python/PyGObject, read from `origin/main`. The port lives on `ruby` in `lib/`.
This inventory is per upstream-file-to-port-file mapping, in the order a user
meets each component (main window → sidebar → pages → dialogs → task
components → preferences/shortcuts → support/data files).

Kind legend: `app` = Gio::Application subclass, `window` = top-level window,
`page` = view-stack page, `row` = list row, `dialog` = modal/floating dialog,
`widget` = reusable component/control, `helper` = non-widget factory module,
`data` = resource/schema file, `backend` = non-UI support module ported 1:1
(listed for completeness, not a UI component).

## Already ported (exists in `lib/`)

| Upstream file | `lib/*.rb` | Kind | Exists |
|---|---|---|---|
| `errands/application.py` + `errands/errands.py` | `lib/errands/application.rb` | app | ✅ |
| `errands/widgets/window.py` | `lib/errands/window.rb` | window | ✅ (partial — see gaps below) |
| `errands/widgets/sidebar.py` | `lib/errands/sidebar.rb` | page | ✅ (partial — Today/Tags/Trash rows not wired) |
| `errands/widgets/task_list/task_list.py` | `lib/errands/task_list.rb` | page | ✅ |
| `errands/widgets/task_list/task_list_sidebar_row.py` | `lib/errands/task_list_sidebar_row.rb` | row | ✅ |
| `errands/widgets/task.py` (Task + Tag classes) | `lib/errands/task.rb`, `lib/errands/tag.rb` | widget | ✅ |
| `errands/widgets/shared/task_toolbar/toolbar.py` | `lib/errands/task_toolbar.rb` | widget | ✅ |
| `errands/widgets/shared/task_toolbar/datetime_window.py` | `lib/errands/datetime_dialog.rb` | dialog | ✅ |
| `errands/widgets/shared/task_toolbar/notes_window.py` | `lib/errands/notes_dialog.rb` | dialog | ✅ |
| `errands/widgets/shared/task_toolbar/attachments_window.py` | `lib/errands/attachments_dialog.rb` (+ `attachment_row.rb` for its rows) | dialog | ✅ |
| `errands/widgets/shared/datetime_picker.py` | `lib/errands/datetime_picker.rb` | widget | ✅ |
| `errands/widgets/shared/color_selector.py` | `lib/errands/color_selector.rb` | widget | ✅ |
| `errands/widgets/shared/titled_separator.py` | `lib/errands/titled_separator.rb` | widget | ✅ |
| `errands/widgets/loading_page.py` | `lib/errands/loading_page.rb` | page | ✅ |
| upstream's "Import"/"Add list"/"Rename list" flows (inline in `sidebar.py`/`task_list.py`) | `lib/errands/import_dialog.rb`, `lib/errands/add_list_dialog.rb`, `lib/errands/rename_list_dialog.rb` | dialog | ✅ |
| upstream's inline confirm dialogs (`dialogs.py` `ConfirmDialog`, used ad hoc) | `lib/errands/confirm_dialog.rb` | dialog | ✅ |
| `data/resources/gtk/help-overlay.ui` | `lib/errands/shortcuts_dialog.rb` | dialog | ✅ |
| upstream's About dialog (built inline in `window.py`) | `lib/errands/about_dialog.rb` | dialog | ✅ |
| upstream's tag chip row in toolbar (inline in `toolbar.py`) | `lib/errands/toolbar_tag_row.rb` | row | ✅ |
| `errands/lib/data.py` | `lib/errands/data.rb` | backend | ✅ |
| `errands/lib/gsettings.py` | `lib/errands/settings.rb` | backend | ✅ |
| `errands/lib/logging.py` | `lib/errands/logging.rb` | backend | ✅ |
| `errands/lib/markup.py` | `lib/errands/markup.rb` | backend | ✅ |
| `errands/lib/animation.py` | `lib/errands/animation.rb` | backend | ✅ |
| `errands/lib/utils.py` | `lib/errands/utils.rb` | backend | ✅ |
| `errands/state.py` | `lib/errands/state.rb` | backend | ✅ |
| `data/resources/style.css` + `style-dark.css` | `lib/errands/style.rb` | data | ✅ |
| `data/icons/**/*-symbolic.svg` | `lib/errands/icons.rb` | data | ✅ |

## Missing — full pages (no `lib/*.rb` yet)

| Upstream file | Target `lib/*.rb` | Kind | Exists | Notes |
|---|---|---|---|---|
| `errands/widgets/today/today.py` (`Today < Adw.Bin`) | `lib/errands/today.rb` | page | ❌ | `Adw.StatusPage` empty state ("No Tasks for Today"), `Adw.HeaderBar`+`Adw.WindowTitle`, scrolled `Adw.Clamp` list of `TodayTask` rows. `window.rb`/`sidebar.rb` comments explicitly flag this as deferred. |
| `errands/widgets/today/today_sidebar_row.py` (`TodaySidebarRow < Gtk.ListBoxRow`) | `lib/errands/today_sidebar_row.rb` | row | ❌ | icon (`errands-calendar-symbolic`) + label + count `Gtk.Button` badge; `activate` signal switches `view_stack` and persists `last-open-list` GSetting. |
| `errands/widgets/today/today_task.py` (`TodayTask < Gtk.Revealer`) | `lib/errands/today_task.rb` | row | ❌ | Revealer-wrapped task row reusing `ErrandsCheckButton`/menu/toolbar pattern from `Task`; installs a `task` `Gio::SimpleActionGroup` (`edit`, `export`, …). |
| `errands/widgets/tags/tags.py` (`Tags < Adw.Bin`) | `lib/errands/tags.rb` | page | ❌ | `Adw.StatusPage` empty state ("No Tags Found"), boxed-list `Gtk.ListBox` of `Tag` rows, built from `UserData.tags`. |
| `errands/widgets/tags/tags_sidebar_row.py` (`TagsSidebarRow < Gtk.ListBoxRow`) | `lib/errands/tags_sidebar_row.rb` | row | ❌ | icon (`errands-tag-symbolic`) + label + count badge, same `activate`/GSettings pattern as Today's row. |
| `errands/widgets/trash/trash.py` (`Trash < Adw.Bin`) | `lib/errands/trash.rb` | page | ❌ | `Adw.StatusPage` empty state ("Empty Trash"), header-bar Clear/Restore buttons (visibility bound inverse to status-page visibility), `ConfirmDialog` on clear. |
| `errands/widgets/trash/trash_sidebar_row.py` (`TrashSidebarRow < Gtk.ListBoxRow`) | `lib/errands/trash_sidebar_row.rb` | row | ❌ | icon/label/count badge plus a `Gtk.DropTarget` (drag a `Task` here to delete) and a right-click `Gtk.GestureClick`/`Gtk.GestureLongPress` context menu (`ErrandsSimpleMenu`). |
| `errands/widgets/preferences.py` (`PreferencesWindow < Adw.PreferencesDialog`) | `lib/errands/preferences_dialog.rb` | dialog | ❌ | Theme radio group (System/Light/Dark `Gtk.CheckButton`s), task-list group (new-task-position `Adw.ComboRow`, notification/background/launch-on-startup `Adw.SwitchRow`s bound to GSettings), Sync group (provider `Adw.ComboRow`, URL/username `Adw.EntryRow`, password `Adw.PasswordEntryRow`, Test-connection `Adw.ActionRow`+button). Also reads GNOME Online Accounts credentials (`errands/lib/goa.py`) — this is exactly what the mandatory `goa-rb` gem should back; do not hand-roll GOA lookups here. |

## Missing — shared helper modules (used by the above, no port equivalent)

These are factory/wrapper modules, not components in their own right (no CSS
classes or signals of their own beyond what callers pass in), but every
missing page above constructs its widgets through them upstream. The house
style builds widgets directly via memoized `.tap` accessors, so these likely
do **not** need 1:1 files — but flagging them so whoever builds Today/Tags/Trash
knows there is no gap in behavior to carry over, only a style translation:

| Upstream file | Provides | Port equivalent |
|---|---|---|
| `errands/widgets/shared/components/boxes.py` | `ErrandsBox`, `ErrandsFlowBox`, `ErrandsListBox` (children=[...] convenience ctor) | none needed — already inlined via `.tap` in existing ports (e.g. `window.rb`) |
| `errands/widgets/shared/components/buttons.py` | `ErrandsButton`, `ErrandsCheckButton`, `ErrandsToggleButton`, `ErrandsSpinButton`, `ErrandsInfoButton` | none needed — same pattern |
| `errands/widgets/shared/components/entries.py` | `ErrandsEntryRow`, `ErrandsEntry` (on_activate convenience) | none needed |
| `errands/widgets/shared/components/header_bar.py` | `ErrandsHeaderBar()` factory | none needed |
| `errands/widgets/shared/components/menus.py` | `ErrandsMenuItem`, `ErrandsSimpleMenu`, `ErrandsSectionedMenu` | none needed — menus already built with `Gio::Menu` directly elsewhere in `lib/` |
| `errands/widgets/shared/components/toolbar_view.py` | `ErrandsToolbarView()` factory | none needed |
| `errands/widgets/shared/components/dialogs.py` | `ConfirmDialog` | already ported as `lib/errands/confirm_dialog.rb` |
| `errands/widgets/shared/components/controllers.py` | (empty in upstream — no classes) | n/a |
| `errands/widgets/shared/sidebar_item.py` | `ErrandsSidebarItem < Gtk.Box` — generic icon+label+counter row body used (in slightly different, hand-duplicated form) by Today/Tags/Trash sidebar rows and by `TaskListSidebarRow` | partially present already — `lib/errands/task_list_sidebar_row.rb` builds the same icon/label/counter shape inline; the three new sidebar rows (today/tags/trash) should follow that existing file's pattern rather than introduce a new shared class, to match house style |

## Missing — window/sidebar wiring (file exists, functionality incomplete)

| Upstream file | `lib/*.rb` | Gap |
|---|---|---|
| `errands/widgets/window.py` | `lib/errands/window.rb` | Does not add Today/Tags/Trash pages to the view stack, no "sync" action/indicator, no autostart-on-login wiring (upstream goes through the XDG portal — the mandatory `ashpd` gem should back this, not a hand-rolled implementation). Comment in file explicitly names these as deferred. |
| `errands/widgets/sidebar.py` | `lib/errands/sidebar.rb` | Does not instantiate `TodaySidebarRow`/`TagsSidebarRow`/`TrashSidebarRow`. Comment in file explicitly names these as deferred. |
| `errands/application.py`/`errands/errands.py` | `lib/errands/application.rb` | No preferences-dialog action/menu entry (upstream's `PreferencesWindow` is never opened from here because it doesn't exist yet); `Style`/`Icons`/`Settings` init is wired, but no GOA/portal setup. |

## Missing — backend/data-layer files (non-UI, listed for completeness only)

Not components under `component-identification`, but they gate the pages
above (Today/Trash/Tags all read live data the sync layer would otherwise
populate), and the mandatory-gem section of this fork's task calls them out
by name:

| Upstream file | Status in `lib/` | Notes |
|---|---|---|
| `errands/lib/goa.py` | ❌ missing | GNOME Online Accounts credential lookup — must be backed by the mandatory `goa-rb` gem (`Goa`), not hand-rolled. |
| `errands/lib/notifications.py` | ❌ missing | Desktop notifications for due tasks. |
| `errands/lib/plugins.py` | ❌ missing | Plugin loader (upstream feature flag; low priority). |
| `errands/lib/sync/sync.py`, `sync/providers/caldav.py`, `sync/providers/nextcloud.py` | ❌ missing | CalDAV/Nextcloud sync backend referenced throughout Today/Trash/Tags/Preferences. |

## Data files / resources (non-`lib/` artifacts)

| Upstream file | Port equivalent | Exists | Notes |
|---|---|---|---|
| `data/io.github.mrvladus.List.gschema.xml.in` | — | ❌ | No GSettings schema file anywhere in this repo. `lib/errands/settings.rb` must currently either hand-roll keys or (if it calls `Gio::Settings` directly) will fail at runtime with no compiled schema installed — worth checking when that file is next touched. |
| `data/io.github.mrvladus.List.desktop.in.in` | — | ❌ | No `.desktop` file. |
| `data/io.github.mrvladus.List.metainfo.xml.in.in` | — | ❌ | No AppStream metainfo. |
| `data/io.github.mrvladus.List.service.in` | — | ❌ | No D-Bus service file. |
| `data/resources/errands.gresource.xml` | — | n/a by design | Ruby house style has no `.ui`/GResource; widgets are built in code. Not a gap. |
| `data/resources/gtk/help-overlay.ui` | `lib/errands/shortcuts_dialog.rb` | ✅ | Ported. |
| `data/resources/style.css`, `style-dark.css` | `lib/errands/style.rb` | ✅ | Ported. |
| `po/*.po`, `po/errands.pot`, `po/LINGUAS`, `po/POTFILES` | — | ❌ | No `po/` directory or i18n catalogue in this fork at all; every upstream `_("...")` string is currently hardcoded English in `lib/`. This is a translation-parity concern (see the `translation-parity` skill) but is noted here since it's a top-level upstream directory with no port counterpart. |

## Summary

- Upstream widget files: 25 (`errands/widgets/**/*.py`, excluding the generic
  `shared/components/*` factory modules).
- Already ported to `lib/`: 16 of those 25 map cleanly to an existing file
  (several upstream files are merged: `task.py`'s `Task`+`Tag` classes become
  two port files; several ad hoc dialogs upstream builds inline become their
  own `lib/*.rb` files).
- Missing entirely: **Today** (3 files: page, sidebar row, task row),
  **Tags** (2 files: page, sidebar row), **Trash** (2 files: page, sidebar
  row), and **Preferences** (1 file) — 8 upstream widget files with no port
  counterpart, all explicitly flagged as deferred in the existing
  `window.rb`/`sidebar.rb` comments.
- Backing data/config: GSettings schema, `.desktop`, AppStream metainfo,
  D-Bus service file, and the entire `po/` translation catalogue are absent
  from the repository, not just from `lib/`.
- Backend gaps that block full parity even once the above pages exist: GOA
  lookup (`goa.py` → `goa-rb`/`Goa` gem), notifications, and the CalDAV/
  Nextcloud sync layer.
