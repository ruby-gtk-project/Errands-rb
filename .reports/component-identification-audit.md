# Errands-rb — component-identification audit (2026-11-07)

This is an adversarial re-check of the existing `.reports/component-inventory.md`,
not a replacement for it. That document is detailed and largely holds up; this
note records what a fresh scan adds or disputes.

## Method

- Upstream: `origin/main` exported with `git archive` (Python + PyGObject,
  GTK4/Libadwaita, **no `.blp`/`.ui`** except `data/resources/gtk/help-overlay.ui`
  — everything else is built in code).
- Symbol table built from this machine's installed GIR (`gir-symbols.sh`,
  1205 rows) inside the project's own `nix develop` shell closure (gtk4,
  libadwaita, gtksourceview typelibs excluded — see translation/parity notes
  below on what that excludes).
- `component-scan.sh` run over both an exported copy of `origin/main` and the
  `ruby` worktree.

## Totals (raw scan, before reading away false positives)

| stream | upstream | port |
|---|---:|---:|
| widget occurrences | 329 | 254 |
| files | ~70 (62 `.py` + help-overlay.ui) | 32 `lib/errands/*.rb` + `lib/errands.rb` |

A naive per-type widget diff shows large deltas (`Gtk.Label` 22 vs 13,
`Gtk.MenuButton` 11 vs 4, `Gtk.Entry` 9 vs 3, `Adw.EntryRow` 11 vs 6, etc.).
**Every one checked by hand collapsed to a false positive of the regex-based
scanner**, not a real gap:

- Upstream's Python repeats each widget's GTK type as a variable-type
  annotation (`self.priority_btn: Gtk.MenuButton = Gtk.MenuButton(...)`) and
  again in callback signatures (`def _on_priority_btn_toggled(btn:
  Gtk.MenuButton, ...)`), so one widget on screen produces 2–3 scan rows.
  `task_toolbar/toolbar.py` scans as 9 `Gtk.MenuButton` rows; reading it finds
  exactly 3 real `Gtk.MenuButton()` constructions, which is exactly what
  `lib/errands/task_toolbar.rb` has.
- `Adw.MessageDialog` (upstream, 6) vs `Adw.MessageDialog`+`Adw.AlertDialog`
  (port, 2+5=7) is a libadwaita API-version difference (`MessageDialog` is
  deprecated in favor of `AlertDialog` in the libadwaita version this port's
  flake pins), not a missing dialog.
- `Adw.AboutWindow` (upstream, deprecated) vs `Adw.AboutDialog` (port) is the
  same kind of version migration.

None of this is a finding on its own — it is a correction to how the raw scan
numbers should be read, and is recorded here so the next pass does not re-walk
the same false trail.

## One real, confirmed gap this pass adds to the identification record

`errands/widgets/shared/task_toolbar/notes_window.py` builds its text editor
on `GtkSource.Buffer` / `GtkSource.View`, bound to a `GtkSource.StyleSchemeManager`
scheme that tracks `Adw.StyleManager`'s dark/light state, a `GtkSource.LanguageManager`
markdown language (syntax highlighting), and line numbers. `lib/errands/notes_dialog.rb`
builds a plain `Gtk::TextView`/`Gtk::TextBuffer` — no highlighting, no line
numbers, no dark-mode-aware scheme. The file's own comment says this is
because "GtkSourceView has no binding in this port's dev shell." Verified: the
flake's `gtkStack` (`flake.nix`) lists `glib gobject-introspection cairo pango
gdk-pixbuf graphene atk gtk4 libadwaita harfbuzz librsvg gnome-online-accounts`
— no `gtksourceview5` (or 4) and no `gtksourceview`-typelib package. The claim
is accurate, but it is an environment gap that was never escalated or fixed,
not an upstream API limitation — `gtksourceview5` and its introspection data
are packaged in nixpkgs and could be added to `gtkStack`. See
`accountability-ensurance.md` for why this belongs in that report too.

This widget identity gap (component exists, but with three of its four
behavioural facets — CSS/scheme, markdown highlighting, line numbers — absent)
is carried into `component-parity.md` as an open item.

## Scope not re-covered here

Full per-file widget/CSS/signal tables for every one of the ~30 ported units
are already in `.reports/component-inventory.md` and were spot-checked, not
rebuilt from scratch, in this pass (preferences dialog, task toolbar, sidebar,
window, notes dialog, trash, today, tags). See `component-parity.md` for the
behavioural judgement on each.
