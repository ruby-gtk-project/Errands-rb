# Errands-rb — translation parity (2026-11-08)

Re-verification of the 2026-11-07 finding, against today's `HEAD`
(`4beb4696`). The commits since then (ashpd wiring, shortcuts-dialog
additions, drive-harness extension, a component inventory pass) touch
neither `translations.rb` nor any widget file's string literals, and the
re-check below confirms the finding is unchanged: **still zero msgids wired
up, same shape of gap, nothing fixed.**

## Do the catalogues still match upstream?

```
grep -c '^msgid' po/errands.pot          → 150
git show origin/main:po/errands.pot | grep -c '^msgid'  → 150
diff <(sort msgids from port) <(sort msgids from upstream)  → empty
```

All 150 msgids are present, byte-identical, in both the port's and upstream's
`.pot`. 31 `.po`/`.pot` files exist under `po/`, matching upstream's
`po/LINGUAS` (30 locales + the template). The catalogue data itself has not
regressed.

## Headline finding, unchanged: zero msgids survive at runtime, despite a working i18n engine existing in the tree

`lib/errands/translations.rb` (205 lines) is a genuine, correct
gettext-compatible engine: `msgctxt`, `msgid_plural`/indexed `msgstr[n]`,
continuation lines, C-string escapes, locale resolution from
`LC_ALL`/`LC_MESSAGES`/`LANG`. Re-tested directly today:

```
LANG=fr Errands::Translations.gettext("Cancel")  => "Annuler"
```

It still works correctly in isolation. And it is still called from
**nowhere** in the application:

```
grep -rn "Translations\.\(gettext\|pgettext\|nplural\)(" lib/errands/*.rb
→ 0 matches (today, same as 2026-11-07)

grep -rln "Translations" lib/errands/*.rb
→ lib/errands/translations.rb only — no other file even requires it. (Note:
  application.rb's require_relative is still present, loading the module
  without using it — see accountability-ensurance.md.)
```

Every title/subtitle/label/toast/tooltip checked across `preferences_dialog.rb`,
`shortcuts_dialog.rb`, `window.rb`, `add_list_dialog.rb`, `notes_dialog.rb`
and the others is still a bare Ruby string literal. Spot re-checked
`preferences_dialog.rb`'s full row-title/subtitle list (System, Light, Dark,
Add new Tasks, Show Notifications, Run in Background, "Hide the application
window instead of closing it", Launch on Startup, "Launch application when
user logs in", Sync Provider, Server URL, Username, Password, Test
Connection) — same literals, same absence of any `Translations.*` wrapper,
as last round.

## What this means concretely, unchanged

Set `LANG=fr` (or any of the other 29 locales shipped in `po/`) and run the
app: every string in the UI stays in English. 0 of 150 msgids are actually
localized at runtime, against an upstream that localizes all of them through
`_("...")` / `C_(...)` / `ngettext(...)`.

## Why this still matters beyond the raw count

This remains the kind of gap a components-only audit will not catch on its
own: every widget exists, with correct English text, so a structural
component-parity pass can score this area clean. Only tracing whether the
translation path is reachable from a widget surfaces the gap. The catalogue
files being present and correct, and the translation engine working in
isolation, are both necessary but neither is sufficient — and the port has
both of those and is still at 0/150 wired.

## Fix shape (still not applied — audit is read-only)

Unchanged from last round: every `.title = "literal"` / `.subtitle =
"literal"` / label / toast / tooltip / `AccessibleProperty` string across
`lib/errands/` needs to become `Translations.gettext(...)` /
`Translations.pgettext(...)` / `Translations.nplural(...)`, matching the
exact upstream call so the existing `.po` catalogues resolve. ~150 msgids
across ~30 files; no part of this was done between 2026-11-07 and today.
