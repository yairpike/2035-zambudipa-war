# Game language

One setting, **Settings > Language**, switches menus, HUD, tooltips, unit and building names, briefings, objectives, subtitles, and the multiplayer lobby between English, Burmese, Mandarin, Thai, and Malay. The voice language follows it and can be set apart on the Audio page.

## How it works
- `game/<locale>.po` are gettext catalogs. The msgid is the English line as written in the scripts, so a `Label` or `Button` translates itself through `TranslationServer` with no change at the call site.
- `en.po` is the English the player sees. Its msgstr equals the msgid except where a flavour word gets an English gloss.
- `SMLang` (`addons/rts_advanced/sm_lang.gd`) loads the catalogs and matches lines built from a format string (`"Credits %d"`, `"%s built"`) back to their template. It also translates the `%s` arguments.
- Voices play only the selected voice language. A missing take leaves the subtitle and never switches to another language.
- `fonts/` holds Noto subsets for Burmese, Thai, and Chinese, used as fallbacks behind the menu faces. Thai and Burmese lines carry zero-width spaces between words so they wrap.

## Workflow
1. After changing player-facing text, run `python3 tools/loc/extract.py`. It refreshes `en.po` from the scripts and faction JSON. `game/extra.txt` adds lines the extractor cannot see. `game/ignore.txt` drops literals that are never shown.
2. Fill the other catalogs: `python3 tools/loc/translate.py` (needs `GEMINI_API_KEY`), or edit the `.po` files by hand. Lines that are already translated are kept.
3. Rebuild the Chinese font subset when `zh.po` gains characters: `bash tools/loc/subset_fonts.sh`.
4. `godot --headless --path . -s res://tools/loc_coverage.gd -- --locale my` walks the menus, HUDs, and missions and lists any on-screen line with no catalog entry, or one that stays English.
5. `bash tools/run_tests.sh` runs `test_game_language`. It checks that every line exists in every language with the same placeholders, that no English line carries non-Latin script, and that the fonts draw every character.
