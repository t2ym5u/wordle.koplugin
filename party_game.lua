-- party_game.lua — Wordle's "· multiplayer" mode, in teams (no UI here, so
-- busted can test it).
--
-- One shared grid on the table. Teams take turns: each guess is one row, then
-- the next team plays. The team whose guess is the word scores the rows left
-- (6 points on the first row down to 1 on the sixth); a full grid reveals the
-- word and nobody scores. A guess that is not in the word list is refused and
-- the turn passes (the TV rule), without using up a row; a guess too short is
-- just refused. With first_letter on, every row starts with the word's first
-- letter, locked. A match is `rounds` words; each round another team starts.

local _dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
local function lrequire(name)
    local key = _dir .. name
    if not package.loaded[key] then
        package.loaded[key] = assert(loadfile(_dir .. name .. ".lua"))()
    end
    return package.loaded[key]
end

local Party       = require("party")
local WordleBoard = lrequire("board")

local WordleParty = {}
WordleParty.__index = WordleParty

WordleParty.MIN_TEAMS     = 2
WordleParty.MAX_TEAMS     = 4
WordleParty.ROUND_CHOICES = { 3, 5, 7, 10 }
WordleParty.DEFAULT_ROUNDS = 5

-- Points for finding the word on row r (1-based).
function WordleParty.pointsForRow(r)
    return math.max(1, WordleBoard.MAX_TRIES - r + 1)
end

-- opts: names (team names), rounds, lang, first_letter
function WordleParty.new(opts)
    local self = setmetatable({
        scores       = Party.newScores(opts.names),
        rounds       = opts.rounds or WordleParty.DEFAULT_ROUNDS,
        first_letter = opts.first_letter ~= false,
        lang         = opts.lang or "en",
        turn         = 1,
        last         = nil,
    }, WordleParty)
    self:startRound()
    return self
end

function WordleParty:teamCount()
    return #self.scores.names
end

function WordleParty:teamName(i)
    return self.scores.names[i or self.turn]
end

function WordleParty:round()
    return self.scores.round
end

-- The next word. Round k is started by team k (cycling).
function WordleParty:startRound()
    Party.nextRound(self.scores)
    self.board = WordleBoard:new{ lang = self.lang, first_letter = self.first_letter }
    self.turn  = (self.scores.round - 1) % self:teamCount() + 1
    self.last  = nil
end

function WordleParty:passTurn()
    self.turn = self.turn % self:teamCount() + 1
end

function WordleParty:isRoundOver()
    return self.board.won or self.board.lost
end

function WordleParty:isMatchOver()
    return self:isRoundOver() and self.scores.round >= self.rounds
end

-- The current team submits the row it typed. Returns the board's result
-- ("short", "invalid", "ok", "win", "lose", "done"); self.last describes it.
function WordleParty:submit()
    if self:isRoundOver() then return "done" end
    local team = self.turn
    local res  = self.board:submit()
    if res == "short" then
        return res
    elseif res == "invalid" then
        self.board:clearRow()
        self:passTurn()
        self.last = { result = "invalid", team = team }
    elseif res == "ok" then
        self:passTurn()
        self.last = { result = "ok", team = team }
    elseif res == "win" then
        local pts = WordleParty.pointsForRow(#self.board.guesses)
        Party.award(self.scores, team, pts)
        self.last = { result = "win", team = team, points = pts }
    elseif res == "lose" then
        self.last = { result = "lose" }
    end
    return res
end

-- ---------------------------------------------------------------------------
-- Persistence
-- ---------------------------------------------------------------------------

function WordleParty:serialize()
    return {
        scores       = Party.copyScores(self.scores),
        rounds       = self.rounds,
        first_letter = self.first_letter,
        lang         = self.lang,
        turn         = self.turn,
        last         = self.last,
        board        = self.board:serialize(),
    }
end

-- A saved match, or nil when the table is unusable.
function WordleParty.load(data)
    if type(data) ~= "table" then return nil end
    local scores = Party.restoreScores(data.scores)
    if not scores or #scores.names < WordleParty.MIN_TEAMS then return nil end
    local self = setmetatable({
        scores       = scores,
        rounds       = tonumber(data.rounds) or WordleParty.DEFAULT_ROUNDS,
        first_letter = data.first_letter ~= false,
        lang         = data.lang or "en",
        turn         = tonumber(data.turn) or 1,
        last         = type(data.last) == "table" and data.last or nil,
    }, WordleParty)
    if self.turn < 1 or self.turn > #scores.names then self.turn = 1 end
    self.board = WordleBoard:new{ lang = self.lang, first_letter = self.first_letter }
    if not self.board:load(data.board) then return nil end
    return self
end

return WordleParty
