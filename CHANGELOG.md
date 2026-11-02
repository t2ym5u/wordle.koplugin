# Changelog

All notable changes to this project will be documented in this file.

## [1.3.1] - 2026-11-02

### Changed
- Listed under **Tools → Games**, grouped by category, instead of its own
  entry in the Tools menu (game-common 1.9.1).

## [1.3.0] - 2026-10-30

### Changed
- Redesigned play screen: the grid fills the room the keyboard leaves, and
  the keys are finger-sized.
- The keyboard follows KOReader's language (AZERTY in French, QWERTZ in
  German) instead of the word list's language.
- Key shading is one step lighter than the tiles, so the black labels on
  correct and present letters stay readable.
- The status line is shorter while playing ("Try 3/6"); the wins and losses
  show once the round is over ("The word was CRANE. · Wins: 4 · Losses: 1").
  It wraps in landscape instead of being cut off.
- The title-bar menu shows "Language: …" (was the bare "EN" / "FR").
- Once the round is won or lost, "New game" appears under the keyboard, so
  the next round no longer needs the menu.

### Fixed
- Letters were sized from the tile and then scaled again for the screen's
  DPI, so they could overflow their tiles; they are now fitted and centred.

## [1.2.2] - 2026-10-07

### Fixed
- The Tools menu entry is translated again. `main.lua` took `_` from
  KOReader's `gettext`, which knows nothing of this plugin's strings, so the
  menu label stayed English while the game's own screen, which goes through
  `i18n`, was translated. `_` now comes from `i18n` here too.


## [1.2.1] - 2026-10-01

### Fixed
- Picks up game-common v1.5.0. Play statistics were recorded under a key no
  tool could match: `ReaderUI`/`FileManager:registerModule()` rewrite a plugin
  instance's `name` to `reader<id>` / `filemanager<id>` right after it is
  built, so this game's sessions were split across two rows and neither
  carried its plugin id. Rows written under the old keys are merged back on
  first read. The same release brings the `stopPlugin()` /
  `deletePluginSettings()` hooks KOReader 2026.07 calls when a plugin is
  deleted from the device (PR #15240).

  No change to this plugin's own code -- it inherits all of it from the
  shared library.

## [1.2.0] - 2026-09-30

### Added
- Separate answer and guess lists for English, the way Wordle itself splits
  them: 2,307 common words can be drawn as the answer, while 8,637 are accepted
  as guesses.

### Fixed
- Ordinary English guesses were rejected as "not a word" — STARE, TEARS, IRATE,
  NOTES, QUIRK, FJORD, LYMPH and ADIEU among them. A single 716-word list was
  serving as both the answer pool and the entire notion of "is that a word".
- README advertised word lists for "EN, FR, DE, ES (and more)" and a
  configurable 4/5/6 word length; only EN and FR have ever existed, and nothing
  sets the word length. That path also reached `math.random(0)`, since every
  bundled list is 5-letter only; it is now guarded.
