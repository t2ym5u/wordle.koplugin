-- Spec for party_game.lua (Wordle in teams).
local DIR = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
package.path = DIR .. "?.lua;" .. DIR .. "common/?.lua;" .. package.path

package.loaded["i18n"] = package.loaded["i18n"] or function(s) return s end
package.loaded["ffi/util"] = package.loaded["ffi/util"] or { template = function(s, ...)
    local args = { ... }
    return (s:gsub("%%(%d)", function(n) return tostring(args[tonumber(n)]) end))
end }

local WordleParty = dofile(DIR .. "party_game.lua")

local function newMatch(opts)
    opts = opts or {}
    local m = WordleParty.new{
        names        = opts.names or { "Red", "Blue", "Green" },
        rounds       = opts.rounds or 3,
        lang         = "en",
        first_letter = opts.first_letter,
    }
    m.board.secret = "CRANE"
    m.board:clearRow()
    return m
end

local function play(m, word)
    m.board:clearRow()
    for i = #m.board.current + 1, #word do m.board:typeLetter(word:sub(i, i)) end
    return m:submit()
end

describe("WordleParty", function()
    it("gives the first letter, locked, when the option is on", function()
        local m = newMatch()
        assert.are.same({ "C" }, m.board.current)
        m.board:deleteLetter()
        assert.are.same({ "C" }, m.board.current)
        local off = newMatch{ first_letter = false }
        assert.are.same({}, off.board.current)
    end)

    it("passes the turn after each row", function()
        local m = newMatch()
        assert.are.equal(1, m.turn)
        assert.are.equal("ok", play(m, "CLOTH"))
        assert.are.equal(2, m.turn)
        assert.are.equal("ok", play(m, "CHAIR"))
        assert.are.equal(3, m.turn)
        assert.are.equal("ok", play(m, "CRASH"))
        assert.are.equal(1, m.turn)
    end)

    it("refuses an unknown word and passes the turn without using a row", function()
        local m = newMatch()
        assert.are.equal("invalid", play(m, "CQXZZ"))
        assert.are.equal(2, m.turn)
        assert.are.equal(1, m.board.row)
        assert.are.same({ "C" }, m.board.current)
    end)

    it("just refuses a word too short", function()
        local m = newMatch()
        m.board:typeLetter("R")
        assert.are.equal("short", m:submit())
        assert.are.equal(1, m.turn)
    end)

    it("scores the rows left to the team that finds the word", function()
        assert.are.equal(6, WordleParty.pointsForRow(1))
        assert.are.equal(1, WordleParty.pointsForRow(6))
        local m = newMatch()
        play(m, "CLOTH")            -- Red, row 1
        assert.are.equal("win", play(m, "CRANE"))   -- Blue, row 2
        assert.are.same({ 0, 5, 0 }, m.scores.points)
        assert.are.equal("win", m.last.result)
        assert.are.equal(2, m.last.team)
        assert.is_true(m:isRoundOver())
        assert.is_false(m:isMatchOver())
    end)

    it("reveals the word and scores nobody when the grid fills", function()
        local m = newMatch()
        local res
        for _ = 1, 6 do res = play(m, "CLOTH") end
        assert.are.equal("lose", res)
        assert.are.same({ 0, 0, 0 }, m.scores.points)
        assert.is_true(m:isRoundOver())
    end)

    it("rotates the starting team and ends after the last round", function()
        local m = newMatch{ rounds = 2 }
        play(m, "CRANE")
        m:startRound()
        assert.are.equal(2, m:round())
        assert.are.equal(2, m.turn)
        assert.is_false(m:isRoundOver())
        m.board.secret = "CRANE"; m.board:clearRow()
        play(m, "CRANE")
        assert.is_true(m:isMatchOver())
        assert.are.same({ 6, 6, 0 }, m.scores.points)
    end)

    it("restores a saved match, scores, turn and grid included", function()
        local m = newMatch()
        play(m, "CLOTH")
        m.board:typeLetter("R")
        local data = m:serialize()
        local r = WordleParty.load(data)
        assert.is_truthy(r)
        assert.are.equal(2, r.turn)
        assert.are.equal("CRANE", r.board.secret)
        assert.are.equal(1, #r.board.guesses)
        assert.are.same({ "C", "R" }, r.board.current)
        assert.is_true(r.board.first_letter)
        assert.are.same(m.scores.points, r.scores.points)
        assert.are.equal(1, r:round())
    end)

    it("restores a finished match as finished", function()
        local m = newMatch{ rounds = 1 }
        play(m, "CRANE")
        local r = WordleParty.load(m:serialize())
        assert.is_true(r:isMatchOver())
        assert.are.equal("win", r.last.result)
    end)

    it("rejects unusable saves", function()
        assert.is_nil(WordleParty.load(nil))
        assert.is_nil(WordleParty.load({}))
        assert.is_nil(WordleParty.load({ scores = { names = { "A" }, points = { 0 } } }))
    end)
end)
