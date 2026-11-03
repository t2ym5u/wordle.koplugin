-- Answers are not repeated: solo games and party matches draw through one
-- answer history kept in the plugin settings (game-common seen_history.lua),
-- so a word only comes back once its whole list has been played; a party
-- match never repeats a word. Also checks the answer lists themselves.
local DIR = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
package.path = DIR .. "?.lua;" .. DIR .. "common/?.lua;" .. package.path

package.loaded["i18n"] = package.loaded["i18n"] or function(s) return s end
package.loaded["ffi/util"] = package.loaded["ffi/util"] or { template = function(s, ...)
    local args = { ... }
    return (s:gsub("%%(%d)", function(n) return tostring(args[tonumber(n)]) end))
end }

local Blocklist = dofile(DIR .. "blocklist.lua")

-- A plugin's settings, kept across "sessions" (new board objects).
local function fakePlugin(store)
    store = store or {}
    return {
        store = store,
        getSetting  = function(_self, k, d) local v = store[k]; if v == nil then return d end; return v end,
        saveSetting = function(_self, k, v) store[k] = v end,
    }
end

local function answers(lang)
    local Board = require("board")
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

describe("answer history", function()
    local Board, WordleParty
    setup(function()
        Board = require("board")
        WordleParty = dofile(DIR .. "party_game.lua")
    end)

    it("does not repeat a word across two sessions", function()
        local store, seen = {}, {}
        for session = 1, 2 do
            local plugin = fakePlugin(store)
            local b = Board:new{ lang = "en", plugin = plugin }
            seen[b.secret] = (seen[b.secret] or 0) + 1
            for _g = 1, 299 do
                b:newGame()
                seen[b.secret] = (seen[b.secret] or 0) + 1
            end
        end
        local n = 0
        for w, c in pairs(seen) do
            n = n + 1
            assert.are.equal(1, c, w)
        end
        assert.are.equal(600, n)
        assert.are.equal(600, #store.seen_answers_en_5)
    end)

    it("restores a saved game without drawing a word", function()
        local plugin = fakePlugin()
        local b = Board:new{ lang = "fr", plugin = plugin }
        local saved = b:serialize()
        local again = Board:new{ lang = "fr", plugin = plugin, data = saved }
        assert.is_true(again.loaded)
        assert.are.equal(b.secret, again.secret)
        assert.are.equal(1, #plugin.store.seen_answers_fr_5)
    end)

    it("keeps one history per language", function()
        local plugin = fakePlugin()
        Board:new{ lang = "en", plugin = plugin }
        Board:new{ lang = "fr", plugin = plugin }
        assert.are.equal(1, #plugin.store.seen_answers_en_5)
        assert.are.equal(1, #plugin.store.seen_answers_fr_5)
    end)

    it("party: no repeat within a match, even once the list is used up", function()
        -- Every English answer but two already played.
        local all = answers("en")
        local store = { seen_answers_en_5 = {} }
        for k = 3, #all do store.seen_answers_en_5[#store.seen_answers_en_5 + 1] = all[k] end
        local plugin = fakePlugin(store)
        local m = WordleParty.new{ names = { "A", "B" }, rounds = 10, lang = "en", plugin = plugin }
        local words = { [m.board.secret] = true }
        assert.is_true(m.board.secret == all[1] or m.board.secret == all[2])
        for _r = 2, 10 do
            -- a saved and restored match keeps its list of used words
            m = WordleParty.load(m:serialize(), plugin)
            m:startRound()
            assert.is_nil(words[m.board.secret], m.board.secret)
            words[m.board.secret] = true
        end
    end)

    it("party: shares the history with solo games", function()
        local plugin = fakePlugin()
        local b = Board:new{ lang = "en", plugin = plugin }
        local m = WordleParty.new{ names = { "A", "B" }, rounds = 3, lang = "en", plugin = plugin }
        assert.are_not.equal(b.secret, m.board.secret)
        assert.are.equal(2, #plugin.store.seen_answers_en_5)
    end)
end)

describe("answer lists", function()
    local function raw(file)
        return dofile(DIR .. file)
    end

    for _i, lang in ipairs({ "en", "fr" }) do
        it(lang .. ": five letters A-Z, no duplicates, family-friendly draws", function()
            local list, set = raw("words_" .. lang .. ".lua"), {}
            for _j, w in ipairs(list) do
                assert.is_truthy(w:match("^[A-Z][A-Z][A-Z][A-Z][A-Z]$"), w)
                assert.is_nil(set[w], w)
                set[w] = true
            end
            local drawn = answers(lang)
            for _j, w in ipairs(drawn) do assert.is_false(Blocklist.isBlocked(w, lang), w) end
            if lang == "en" then
                assert.is_true(#drawn >= 2900, tostring(#drawn))
            else
                assert.is_true(#drawn >= 5700, tostring(#drawn))
            end
        end)
    end

    it("en: no answer is duplicated in the guess list", function()
        local set = {}
        for _j, w in ipairs(raw("words_en.lua")) do set[w] = true end
        local g = raw("guesses_en.lua")
        for _j, w in ipairs(g) do assert.is_nil(set[w], w) end
        assert.is_true(#g + #raw("words_en.lua") >= 8640)
    end)
end)
