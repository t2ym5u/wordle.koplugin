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
