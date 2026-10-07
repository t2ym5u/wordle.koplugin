local DIR = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
package.path = DIR .. "?.lua;" .. package.path

describe("WordleBoard", function()
    local Board

    setup(function()
        Board = require("board")
    end)

    describe("new", function()
        it("picks a 5-letter secret from the language word list", function()
            local b = Board:new()
            assert.are.equal(5, #b.secret)
        end)
    end)

    describe("typeLetter / deleteLetter", function()
        it("accumulates up to word_len letters and stops accepting more", function()
            local b = Board:new()
            b:typeLetter("a")
            b:typeLetter("b")
            assert.are.same({ "A", "B" }, b.current)
            for _ = 1, 5 do b:typeLetter("z") end
            assert.are.equal(5, #b.current)
        end)

        it("deletes the last typed letter", function()
            local b = Board:new()
            b:typeLetter("a")
            b:typeLetter("b")
            b:deleteLetter()
            assert.are.same({ "A" }, b.current)
        end)
    end)

    describe("submit", function()
        it("returns short when fewer than word_len letters are typed", function()
            local b = Board:new()
            b:typeLetter("a")
            assert.are.equal("short", b:submit())
        end)

        it("returns invalid for a real-length word not in the dictionary", function()
            local b = Board:new()
            for _, ch in ipairs({ "Q","Z","X","J","K" }) do b:typeLetter(ch) end
            assert.are.equal("invalid", b:submit())
        end)

        it("wins by guessing the secret and marks every letter correct", function()
            local b = Board:new()
            for i = 1, #b.secret do b:typeLetter(b.secret:sub(i, i)) end
            assert.are.equal("win", b:submit())
            assert.is_true(b.won)
            local last = b.guesses[#b.guesses]
            for _, st in ipairs(last.states) do
                assert.are.equal(Board.STATE_CORRECT, st)
            end
            assert.are.equal(1, b.wins)
        end)

        it("evaluates present-but-misplaced letters correctly", function()
            local b = Board:new()
            b.secret = "APPLE"
            b.word_len = 5
            -- "ELPPA" shares every letter with "APPLE" but only position 3
            -- (P) lines up; the rest should report present, not absent.
            local states = b:_evaluate("ELPPA")
            assert.are.equal(Board.STATE_CORRECT, states[3])
            for i, st in ipairs(states) do
                if i ~= 3 then
                    assert.are.equal(Board.STATE_PRESENT, st)
                end
            end
        end)

        it("does not accept further input once the game is done", function()
            local b = Board:new()
            for i = 1, #b.secret do b:typeLetter(b.secret:sub(i, i)) end
            b:submit()
            assert.are.equal("done", b:submit())
        end)
    end)

    describe("newGame", function()
        it("resets guesses, row and outcome flags", function()
            local b = Board:new()
            for i = 1, #b.secret do b:typeLetter(b.secret:sub(i, i)) end
            b:submit()
            b:newGame()
            assert.are.same({}, b.guesses)
            assert.are.equal(1, b.row)
            assert.is_false(b.won)
            assert.is_false(b.lost)
        end)
    end)

    describe("serialize / load", function()
        it("round-trips secret, guesses and stats", function()
            local b = Board:new()
            for i = 1, #b.secret do b:typeLetter(b.secret:sub(i, i)) end
            b:submit()
            local data = b:serialize()

            local b2 = Board:new()
            assert.is_true(b2:load(data))
            assert.are.equal(b.secret, b2.secret)
            assert.are.equal(#b.guesses, #b2.guesses)
            assert.are.equal(b.wins, b2.wins)
        end)

        it("load returns false for invalid data", function()
            local b = Board:new()
            assert.is_false(b:load(nil))
            assert.is_false(b:load({}))
        end)
    end)
end)

describe("English word lists", function()
    local DIR2 = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
    local answers = assert(loadfile(DIR2 .. "words_en.lua"))()
    local guesses = assert(loadfile(DIR2 .. "guesses_en.lua"))()

    local Board
    setup(function() Board = require("board") end)

    local function guess(board, word)
        board.current = {}
        for i = 1, #word do board:typeLetter(word:sub(i, i)) end
        return board:submit()
    end

    it("accepts ordinary English words the old 716-word list rejected", function()
        -- Every one of these came back "invalid" before the answer/guess split.
        for _, word in ipairs({ "STARE", "TEARS", "IRATE", "NOTES", "QUIRK",
                                "FJORD", "LYMPH", "ADIEU" }) do
            local b = Board:new{ lang = "en" }
            assert.are_not.equal("invalid", guess(b, word),
                word .. " should be an acceptable guess")
        end
    end)

    it("still rejects non-words", function()
        for _, word in ipairs({ "ZZZZZ", "QQQQQ", "XKCDE" }) do
            local b = Board:new{ lang = "en" }
            assert.are.equal("invalid", guess(b, word))
        end
    end)

    it("keeps words from the previously shipped list playable", function()
        -- EMAIL in particular post-dates ENABLE, so it only survives because
        -- the old list was folded into the new one rather than replaced.
        for _, word in ipairs({ "ABOUT", "EMAIL", "PIZZA", "ZEBRA" }) do
            assert.are_not.equal("invalid", guess(Board:new{ lang = "en" }, word))
        end
    end)

    it("draws answers only from the answer list, never from the guess list", function()
        local is_answer = {}
        for _, w in ipairs(answers) do is_answer[w] = true end
        for _ = 1, 200 do
            local b = Board:new{ lang = "en" }
            assert.is_true(is_answer[b.secret], b.secret .. " is not an answer word")
        end
    end)

    it("keeps the two lists disjoint, and every entry a 5-letter word", function()
        local seen = {}
        for _, list in ipairs({ answers, guesses }) do
            for _, w in ipairs(list) do
                assert.are.equal(5, #w)
                assert.is_nil(w:match("[^A-Z]"), w .. " is not plain uppercase")
                assert.is_nil(seen[w], w .. " appears in both lists")
                seen[w] = true
            end
        end
        assert.is_true(#answers > 2000)
        assert.is_true(#guesses > 5000)
    end)

    it("leaves French alone -- it ships answers only and has no guess file", function()
        local b = Board:new{ lang = "fr" }
        assert.are.equal(5, #b.secret)
        assert.are.equal("invalid", guess(Board:new{ lang = "fr" }, "ZZZZZ"))
    end)
end)


describe("Italian word lists", function()
    local DIR2 = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
    local answers = assert(loadfile(DIR2 .. "words_it.lua"))()
    local guesses = assert(loadfile(DIR2 .. "guesses_it.lua"))()

    local Board
    setup(function() Board = require("board") end)

    local function guess(board, word)
        board.current = {}
        for i = 1, #word do board:typeLetter(word:sub(i, i)) end
        return board:submit()
    end

    it("accepts common Italian words and conjugated verb forms", function()
        for _, word in ipairs({ "TEMPO", "NOTTE", "PASTA", "AMICO", "FANNO", "STAVO", "DORMI" }) do
            local b = Board:new{ lang = "it" }
            assert.are_not.equal("invalid", guess(b, word), word .. " was rejected")
        end
    end)

    it("still rejects non-words", function()
        assert.are.equal("invalid", guess(Board:new{ lang = "it" }, "ZZZZZ"))
    end)

    it("draws answers only from the answer list, never from the guess list", function()
        local is_answer = {}
        for _, w in ipairs(answers) do is_answer[w] = true end
        for _ = 1, 200 do
            local b = Board:new{ lang = "it" }
            assert.is_true(is_answer[b.secret], b.secret .. " is not an answer word")
        end
    end)

    it("keeps the two lists disjoint, and every entry a 5-letter word", function()
        local seen = {}
        for _, list in ipairs({ answers, guesses }) do
            for _, w in ipairs(list) do
                assert.are.equal(5, #w)
                assert.is_nil(w:match("[^A-Z]"), w .. " is not plain uppercase")
                assert.is_nil(seen[w], w .. " appears in both lists")
                seen[w] = true
            end
        end
        assert.is_true(#answers > 1500)
        assert.is_true(#guesses > 5000)
    end)

    it("uses only letters native to Italian and vowel endings in answers", function()
        for _, w in ipairs(answers) do
            assert.is_nil(w:match("[JKWXY]"), w .. " has a non-Italian letter")
            assert.is_truthy(w:match("[AEIOU]$"), w .. " ends in a consonant")
        end
    end)
end)
