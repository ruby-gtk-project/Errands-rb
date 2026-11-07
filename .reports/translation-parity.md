# Errands-rb — translation parity (2026-11-07)

## Headline finding: zero msgids survive, despite a full, working i18n engine existing in the tree

Upstream's `po/errands.pot` has **150 `msgid`s**, extracted from `_("...")`,
`C_("...", "...")` and plural `ngettext(...)` calls across the Python source,
covering 30 locales (`po/LINGUAS`). All 150 msgids and all 31 `.po`/`.pot`
files were copied into the port's `po/` directory unchanged (confirmed:
`po/fr.po` has `msgid "Cancel" / msgstr "Annuler"`, matching upstream).

The port also has a genuinely well-built, from-scratch gettext-compatible
engine: `lib/errands/translations.rb` (205 lines) parses `msgctxt`, `msgid`,
`msgid_plural`, indexed `msgstr[n]`, continuation lines and C string escapes,
selects a `.po` file from `LC_ALL`/`LC_MESSAGES`/`LANG`, and exposes
`gettext`, `pgettext` and `nplural`. Tested directly in this audit — it
works correctly:

```
LANG=fr Errands::Translations.gettext("Cancel")  => "Annuler"
LANG=fr Errands::Translations.gettext("Notes")   => "Notes"   (same word in fr)
```

**But nothing in the application calls it.** Grepped every file under
`lib/errands/` (32 files) for `Translations.gettext(`, `Translations.pgettext(`,
`Translations.nplural(`, or any bare `_(`/`gettext(`/`pgettext(` call:

```
grep -rn "Translations\.\(gettext\|pgettext\|nplural\)(" lib/errands/*.rb   → 0 matches
grep -rln "Translations" lib/errands/*.rb                                  → translations.rb only
```

`lib/errands/application.rb` does `require_relative 'translations'`
(line 17) — the module is loaded — and then never references it again.
Spot-checked the widest, most translatable surface in the app,
`preferences_dialog.rb` (every row title/subtitle: "System", "Light", "Dark",
"Add new Tasks", "Show Notifications", "Run in Background", "Hide the
application window instead of closing it", "Launch on Startup", "Launch
application when user logs in", "Sync Provider", "Server URL", "Username",
"Password", "Test Connection"): every one is a bare Ruby string literal
assigned directly to `row.title =` / `row.subtitle =`, upstream's `_("...")`
wrapper simply dropped on the floor during the port. This is the pattern
throughout every widget file checked, not an isolated miss in one dialog.

## What this means concretely

Set `LANG=fr` (or any of the other 29 locales shipped in `po/`) and run the
app: **every string in the UI stays in English.** The `.po` files are present,
correctly formatted, and would work if wired up — this is not a missing-data
problem, it is a missing-wiring problem. Running the app with a non-English
locale set produces an experience with 0 of 150 msgids actually localized,
against an upstream that localizes all of them.

## Why this matters beyond the raw count

This is the kind of gap that a components-only audit (grep for `Adw.EntryRow`,
count dialogs) will never catch, because every widget *exists* with the
*correct English text* — the component inventory and component-parity report
both score this area clean on structure. Only checking whether the
translation path is actually reachable from a widget surfaces it. Treat
"the `po/` files are present" and "translation support exists" as two
separate claims from now on; only the first is currently true.

## Fix shape (not applied in this audit — audit is read-only)

Every `.title = "literal"` / `.subtitle = "literal"` / string passed to a
label, dialog, toast, tooltip, or `AccessibleProperty` across `lib/errands/`
needs to become `Translations.gettext("literal")` (or `pgettext` where
upstream used `C_`/`pgettext`, or `nplural` where upstream used `ngettext`),
matching the exact upstream call site so the existing `.po` catalogues resolve
correctly. This is a mechanical but large change — 150 msgids, scattered
across ~30 files — not a small follow-up.
