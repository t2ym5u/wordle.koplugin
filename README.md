# wordle.koplugin

A Wordle plugin for [KOReader](https://github.com/koreader/koreader).

## Concept

Guess the hidden 5-letter word in 6 attempts. After each guess, each letter is marked:
- **Correct** — right letter, right position
- **Present** — letter is in the word but in the wrong position
- **Absent** — letter is not in the word

## Planned Features

- **Multiple languages** — word lists for EN, FR, DE, ES (and more)
- **Configurable word length** — 4, 5 or 6 letters
- **On-screen keyboard** — shows letter status at a glance
- **Hard mode** — revealed hints must be used in subsequent guesses
- **Daily puzzle** — one puzzle per day derived from the date (reproducible seed)
- **Free play** — unlimited random puzzles
- **Statistics** — win streak, guess distribution histogram
- **Auto-save** — resume an in-progress game after closing KOReader

## Controls

| Action | How |
|--------|-----|
| Type a letter | Tap the on-screen keyboard |
| Delete last letter | Tap **⌫** |
| Submit guess | Tap **Enter** |
| New random game | Tap **New game** |

## Why e-ink friendly?

Each guess is a discrete, low-frequency interaction. The letter-status feedback
uses distinct fill patterns (solid / hatched / empty) instead of colours alone,
so the puzzle remains readable on greyscale e-ink screens.

## License

GPL-3.0
