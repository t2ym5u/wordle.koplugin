# Changelog

All notable changes to this project will be documented in this file.

## [1.6.3] - 2026-11-09

### Fixed
- The game now starts in KOReader's language (French when KOReader is in
  French) instead of always English; a language picked in the game holds
  until KOReader's language changes.

## [1.6.2] - 2026-11-05

### Fixed
- "Lynch" and its forms (LYNCHED, LYNCHING, LYNCHERS...; LYNCHAGE,
  LYNCHER... in French) are added to the family-friendly blocklist, so the
  game never draws or reveals them. They are still accepted when typed.

## [1.6.1] - 2026-11-04

### Fixed
- A game no longer crashes when an outdated plugin is installed alongside:
  shared modules left behind by an older plugin are replaced by this
  plugin's own copy instead of being used as they are.

## [1.6.0] - 2026-11-04

### Changed
- Bigger keys in landscape: the keyboard panel beside the grid is wider
  (45 % of the screen instead of 36 %), so each key is about a quarter wider.
  The grid shrinks only slightly. Portrait is unchanged.
- Needs game-common 1.13.0.
- Uses less memory: the game loads when you open it, not when KOReader
  starts, so it no longer takes memory or startup time while unplayed.
- Uses less memory: the word lists load when the game opens, only for the
  language played, and are freed when it closes.

## [1.5.0] - 2026-11-03

### Changed
- No more repeated words: the game remembers the words already played and
  draws a new one each time; a word only comes back once the whole list has
  been played (about 3,000 games). Solo games and multiplayer matches share
  this memory, and a match never shows the same word twice.
- More English words: 2,951 possible answers instead of 2,307, still common
  words (FJORD, GECKO, KAZOO, LATTE, SUSHI, TAROT…), plus a few newer ones
  now accepted as guesses too (EMOJI, INBOX, RAMEN, MANGA…).

### Fixed
- README listed features the game never had (hard mode, daily puzzle,
  guess distribution, hatched tiles).

## [1.4.0] - 2026-11-02

### Added
- Multiplayer mode for 2 to 4 teams ("Wordle · multiplayer" under Tools →
  Games → Party & quiz, or Mode: Multiplayer in the game menu): one shared
  grid, teams take turns, the team to play is shown in big type. Optional
  "First letter shown" (on by default). The team that finds the word scores
  the rows left (6 on the first row … 1 on the last); a full grid reveals the
  word and nobody scores; a word not in the list is refused and the turn
  passes. Matches of 3/5/7/10 words, team names remembered, final scoreboard,
  match saved and restored apart from the solo game.

### Changed
- Family-friendly words: the answer is never a vulgar, sexual,
  scatological, slur or drug-related word any more (`blocklist.lua`, applied
  to the answer pool) -- 6 English and 47 French words. They are still
  accepted as guesses.

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
