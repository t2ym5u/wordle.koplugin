-- Family-friendly words: the game is also played at a family table, so the
-- answer (revealed when the round ends) must never be one of blocklist.lua's
-- vulgar, sexual, scatological, slur or drug-related words. Such a word stays
-- a valid guess: only the answer pool leaves it out.
local DIR = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
package.path = DIR .. "?.lua;" .. package.path

local Blocklist = dofile(DIR .. "blocklist.lua")

local function everyAnswer(Board, lang)
    local b = Board:new({ lang = lang })
    local real, n, i, out = math.random, nil, 0, {}
    math.random = function(m) n = m; return i == 0 and 1 or i end
    b:newGame()
    for k = 1, n do
        i = k
        b:newGame()
        out[#out + 1] = b.secret
    end
    math.random = real
    return out
end

describe("family-friendly answers", function()
    local Board

    setup(function()
        Board = require("board")
    end)

    for _, lang in ipairs({ "en", "fr" }) do
        it("never picks a blocklisted " .. lang .. " answer", function()
            local all = everyAnswer(Board, lang)
            assert.is_true(#all > 1000)
            for _, w in ipairs(all) do
                assert.is_false(Blocklist.isBlocked(w, lang), w)
            end
        end)
    end

    it("still accepts a blocklisted French word as a guess", function()
        local seen = {}
        for _, w in ipairs(dofile(DIR .. "words_fr.lua")) do seen[w] = true end
        assert.is_true(seen.MERDE)               -- the raw list carries it
        local b = Board:new({ lang = "fr" })
        b.secret = "TABLE"
        b.current = {}
        for c in ("MERDE"):gmatch(".") do b:typeLetter(c) end
        assert.are_not.equal("invalid", b:submit())
    end)
end)
