local _dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"

-- ---------------------------------------------------------------------------
-- Word lists
-- ---------------------------------------------------------------------------

-- Two files per language, the way Wordle itself splits them:
--   words_<lang>.lua    -- words common enough to be a fair answer
--   guesses_<lang>.lua  -- everything else the game still accepts as a guess
--
-- English used to be a single 716-word table inlined right here, serving as
-- the answer pool AND as the whole notion of "is that even a word", so
-- ordinary guesses (STARE, TEARS, IRATE, NOTES, FJORD, LYMPH...) came back
-- as "not a word". guesses_<lang>.lua is optional -- French ships answers
-- only for now and behaves exactly as before.
--
-- Loaded lazily: the English guess list alone is several thousand words, and
-- a player who never opens Wordle should not pay for it. Only the language
-- in play is kept (switching drops the other one), and WordleBoard.release()
-- (the screen closing) drops it too: it is quick to read again.

local Blocklist = assert(loadfile(_dir .. "blocklist.lua"))()

-- Answers already played, remembered in the plugin settings (game-common
-- seen_history.lua): a new word is one not seen yet, and a word only comes
-- back once the whole list for that language and length has been played.
-- One key per language and word length; FR has more words than SEEN_MAX, so
-- the oldest are forgotten first -- a repeat still takes 3,000 games.
local SeenHistory = require("seen_history")
local SEEN_MAX = 3000

local _lists = {}

local function loadLang(lang)
    local entry = _lists[lang]
    if entry then return entry end

    entry = { answers = {}, valid = {} }
    local answers_fn = loadfile(_dir .. "words_" .. lang .. ".lua")
    entry.answers = (answers_fn and answers_fn()) or {}
    for _, w in ipairs(entry.answers) do entry.valid[w] = true end
    -- A blocklisted word (blocklist.lua) stays a valid guess but is never
    -- the answer: French has no separate guess list to move it to.
    entry.answers = Blocklist.filter(entry.answers, lang)

    -- Every answer is also a valid guess, so guesses_<lang>.lua only needs to
    -- carry the extras -- no duplication between the two files.
    local guesses_fn = loadfile(_dir .. "guesses_" .. lang .. ".lua")
    if guesses_fn then
        for _, w in ipairs(guesses_fn() or {}) do entry.valid[w] = true end
    end

    _lists = { [lang] = entry }
    return entry
end

-- Filter to exact word_len
local function filterWords(list, len)
    local out = {}
    for _, w in ipairs(list) do
        if #w == len then out[#out + 1] = w end
    end
    return out
end

-- Candidate answers for lang (returns array)
local function getWordList(lang, len)
    return filterWords(loadLang(lang).answers, len)
end

-- Accepted as a guess: an answer, or one of the extra words for that language.
local function isValidWord(lang, word)
    return loadLang(lang).valid[word] == true
end

local WORD_LEN   = 5
local MAX_TRIES  = 6
local LANG_ORDER = { "en", "fr" }

-- Cell result states
local STATE_EMPTY   = 0
local STATE_TBD     = 1   -- typed but not submitted
local STATE_CORRECT = 2   -- right letter, right position
local STATE_PRESENT = 3   -- right letter, wrong position
local STATE_ABSENT  = 4   -- letter not in word

-- ---------------------------------------------------------------------------
-- WordleBoard
-- ---------------------------------------------------------------------------

local WordleBoard = {}
WordleBoard.__index = WordleBoard

-- opts.plugin : settings holder for the answer history (none: plain random,
--               as in the specs); opts.data : a saved game to restore instead
--               of drawing a new word (obj.loaded tells whether it worked);
--               opts.exclude : set of answers this board must not draw (a
--               party match's earlier words).
function WordleBoard:new(opts)
    opts = opts or {}
    local obj = setmetatable({
        plugin    = opts.plugin,
        exclude   = opts.exclude,
        lang      = opts.lang     or "en",
        word_len  = opts.word_len or WORD_LEN,
        max_tries = MAX_TRIES,
        -- Party mode's TV-show variant: the secret's first letter is given,
        -- locked in the first tile of every row.
        first_letter = opts.first_letter == true,
        secret    = "",
        guesses   = {},   -- array of { letters={}, states={} }
        current   = {},   -- current row letters (array of chars)
        row       = 1,    -- current attempt (1-indexed)
        won       = false,
        lost      = false,
        -- keyboard state per letter
        key_state = {},
        wins      = 0,
        losses    = 0,
        streak    = 0,
    }, self)
    obj.loaded = opts.data ~= nil and obj:load(opts.data) or false
    if not obj.loaded then
        obj:_newWord()
        obj.current = obj:_freshRow()
    end
    return obj
end

-- Letters a row starts with: nothing, or the given first letter.
function WordleBoard:_freshRow()
    if self.first_letter and self.secret ~= "" then
        return { self.secret:sub(1, 1) }
    end
    return {}
end

-- Empties the row being typed (back to the given first letter, if any).
function WordleBoard:clearRow()
    self.current = self:_freshRow()
end

function WordleBoard:_newWord()
    local list = getWordList(self.lang, self.word_len)
    if #list == 0 then list = filterWords(loadLang("en").answers, self.word_len) end
    -- Every bundled list is 5-letter only, so a word_len of anything else
    -- leaves both filters empty and math.random(0) would raise. Nothing sets
    -- word_len today, but a saved game from a future build might.
    if #list == 0 then list = loadLang("en").answers end
    if #list == 0 then return end
    if self.exclude then
        local left = {}
        for _i, w in ipairs(list) do
            if not self.exclude[w] then left[#left + 1] = w end
        end
        if #left > 0 then list = left end
    end
    if self.plugin then
        local key = "answers_" .. self.lang .. "_" .. self.word_len
        self.secret = SeenHistory.open(self.plugin, key, { max = SEEN_MAX }):pick(list)
    else
        self.secret = list[math.random(#list)]
    end
end

function WordleBoard:newGame()
    self:_newWord()
    self.guesses  = {}
    self.current  = self:_freshRow()
    self.row      = 1
    self.won      = false
    self.lost     = false
    self.key_state = {}
end

-- Type a letter
function WordleBoard:typeLetter(letter)
    if self.won or self.lost then return end
    if #self.current >= self.word_len then return end
    self.current[#self.current + 1] = letter:upper()
end

-- Delete last letter
function WordleBoard:deleteLetter()
    if self.won or self.lost then return end
    if #self.current <= (self.first_letter and 1 or 0) then return end
    table.remove(self.current)
end

-- Submit current guess. Returns "short", "invalid", "win", "lose", "ok"
function WordleBoard:submit()
    if self.won or self.lost then return "done" end
    if #self.current < self.word_len then return "short" end

    local guess_str = table.concat(self.current)
    if not isValidWord(self.lang, guess_str) then return "invalid" end
    local states    = self:_evaluate(guess_str)
    self.guesses[#self.guesses + 1] = {
        letters = { table.unpack(self.current) },
        states  = states,
    }

    -- Update keyboard states
    for i, letter in ipairs(self.current) do
        local st = states[i]
        local existing = self.key_state[letter]
        -- CORRECT > PRESENT > ABSENT > nil
        if not existing
                or (st == STATE_CORRECT)
                or (st == STATE_PRESENT and existing ~= STATE_CORRECT) then
            self.key_state[letter] = st
        end
    end

    self.current = self:_freshRow()
    self.row     = self.row + 1

    if guess_str == self.secret then
        self.won    = true
        self.wins   = self.wins + 1
        self.streak = self.streak + 1
        return "win"
    elseif self.row > self.max_tries then
        self.lost   = true
        self.losses = self.losses + 1
        self.streak = 0
        return "lose"
    end
    return "ok"
end

function WordleBoard:_evaluate(guess)
    local states  = {}
    local secret  = self.secret
    local used    = {}  -- secret letter positions already matched

    -- First pass: correct positions
    for i = 1, self.word_len do
        if guess:sub(i,i) == secret:sub(i,i) then
            states[i] = STATE_CORRECT
            used[i]   = true
        else
            states[i] = STATE_ABSENT
        end
    end

    -- Second pass: present but wrong position
    for i = 1, self.word_len do
        if states[i] ~= STATE_CORRECT then
            local ch = guess:sub(i, i)
            for j = 1, self.word_len do
                if not used[j] and secret:sub(j,j) == ch then
                    states[i] = STATE_PRESENT
                    used[j]   = true
                    break
                end
            end
        end
    end

    return states
end

-- ---------------------------------------------------------------------------
-- Persistence
-- ---------------------------------------------------------------------------

function WordleBoard:serialize()
    return {
        lang      = self.lang,
        word_len  = self.word_len,
        first_letter = self.first_letter or nil,
        secret    = self.secret,
        guesses   = self.guesses,
        current   = self.current,
        row       = self.row,
        won       = self.won,
        lost      = self.lost,
        key_state = self.key_state,
        wins      = self.wins,
        losses    = self.losses,
        streak    = self.streak,
    }
end

function WordleBoard:load(data)
    if type(data) ~= "table" or not data.secret then return false end
    self.lang      = data.lang      or "en"
    self.word_len  = data.word_len  or WORD_LEN
    self.secret    = data.secret    or ""
    self.first_letter = data.first_letter == true
    self.guesses   = data.guesses   or {}
    self.current   = data.current   or {}
    self.row       = data.row       or 1
    self.won       = data.won       or false
    self.lost      = data.lost      or false
    self.key_state = data.key_state or {}
    self.wins      = data.wins      or 0
    self.losses    = data.losses    or 0
    self.streak    = data.streak    or 0
    return true
end

WordleBoard.STATE_EMPTY   = STATE_EMPTY
WordleBoard.STATE_TBD     = STATE_TBD
WordleBoard.STATE_CORRECT = STATE_CORRECT
WordleBoard.STATE_PRESENT = STATE_PRESENT
WordleBoard.STATE_ABSENT  = STATE_ABSENT
WordleBoard.LANG_ORDER    = LANG_ORDER
WordleBoard.WORD_LEN      = WORD_LEN
WordleBoard.MAX_TRIES     = MAX_TRIES

-- Drops the loaded word lists (called when the game screen closes); the next
-- game reads its language's lists again.
function WordleBoard.release()
    _lists = {}
    Blocklist.release()
end

-- The languages whose word lists are loaded now (for the specs).
function WordleBoard.loadedLanguages()
    local out = {}
    for lang in pairs(_lists) do out[#out + 1] = lang end
    table.sort(out)
    return out
end

return WordleBoard
