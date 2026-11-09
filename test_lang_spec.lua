-- The game's language: it follows KOReader's language (PluginBase:getLang,
-- game-common 1.15.0). Up to 1.6.2 Wordle started in English whatever
-- KOReader's language, and a language picked once in its menu held for good.
--
-- The real screen.lua and board.lua run against the real PluginBase; the
-- KOReader UI modules are permissive stubs and the screen's layout methods
-- are switched off, so only the language logic and the deal are exercised.
local DIR = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"

-- A stub that is a table, a function and a number all at once: any field is
-- another stub, a call returns its table argument (Class:extend{...}) or its
-- string argument (_("x")), arithmetic gives a stub.
local function makeStub()
    local cache = {}
    local mt = {}
    local s = setmetatable({}, mt)
    mt.__index = function(_, k)
        if cache[k] == nil then cache[k] = makeStub() end
        return cache[k]
    end
    mt.__call = function(_, a, b)
        if type(b) == "table" then return b end
        if type(a) == "string" then return a end
        if type(a) == "table" and a ~= s and getmetatable(a) ~= mt then return a end
        return makeStub()
    end
    local function self_() return s end
    mt.__add, mt.__sub, mt.__mul, mt.__div, mt.__unm = self_, self_, self_, self_, self_
    mt.__idiv, mt.__mod = self_, self_
    mt.__concat = function() return "" end
    mt.__lt = function() return false end
    mt.__le = function() return false end
    return s
end

local function koreader(lang)
    _G.G_reader_settings = { readSetting = function(_, k) if k == "language" then return lang end end }
end

describe("Wordle language", function()
    local saved = {}
    local picker                     -- the last MenuHelper.openPickerMenu{} call
    local Screen, PluginBase

    local function stubSearcher(name)
        return function() return makeStub() end, name
    end

    setup(function()
        saved.path = package.path
        saved.loaded = {}
        for k, v in pairs(package.loaded) do saved.loaded[k] = v end
        saved.preload = {}
        local preload = {
            i18n = function()
                return setmetatable({ lang = function() return "en" end },
                    { __call = function(_, s) return s end })
            end,
            ["ffi/util"] = function() return { template = function(s) return s end } end,
            ["ui/time"] = function()
                return { realtime = function() return os.clock() end,
                         to_us = function(t) return math.floor(t * 1000000) end }
            end,
            screen_base = function()
                return { extend = function(_, o) return o end, init = function() end,
                         updateStatus = function() end }
            end,
            menu_helper = function()
                return { openPickerMenu = function(args) picker = args end }
            end,
        }
        for name, f in pairs(preload) do
            saved.preload[name] = package.preload[name]
            package.preload[name] = f
            package.loaded[name] = nil
        end
        for k in pairs(package.loaded) do
            if type(k) == "string" and k:sub(1, #DIR) == DIR then package.loaded[k] = nil end
        end
        package.loaded.plugin_base, package.loaded.seen_history = nil, nil
        package.path = DIR .. "common/?.lua;" .. DIR .. "?.lua;" .. package.path
        local searchers = package.searchers or package.loaders
        searchers[#searchers + 1] = stubSearcher
        PluginBase = require("plugin_base")
        Screen = dofile(DIR .. "screen.lua")
    end)

    teardown(function()
        _G.G_reader_settings = nil
        local searchers = package.searchers or package.loaders
        for i = #searchers, 1, -1 do
            if searchers[i] == stubSearcher then table.remove(searchers, i) end
        end
        for name, v in pairs(saved.preload) do package.preload[name] = v end
        for k in pairs(package.loaded) do
            if saved.loaded[k] == nil then package.loaded[k] = nil end
        end
        for k, v in pairs(saved.loaded) do package.loaded[k] = v end
        package.path = saved.path
    end)

    -- The plugin, its settings in a plain table, and its screen opened.
    local function open(store)
        store = store or {}
        local plugin = setmetatable({ name = "wordle" }, { __index = PluginBase })
        plugin.settings = {
            readSetting = function(_, k) return store[k] end,
            saveSetting = function(_, k, v) store[k] = v end,
            flush = function() end,
        }
        local screen = setmetatable({ plugin = plugin }, { __index = Screen })
        screen.buildLayout = function() end
        screen.updateStatus = function() end
        screen._startCountdown = function() end
        screen._stopCountdown = function() end
        screen:init()
        return screen, store
    end

    -- The French content, upper-cased: words, or phrases ({ text, source }).
    local FR = {}
    local function add(t)
        for k, v in pairs(t) do
            if type(k) == "string" then FR[k:upper()] = true end
            if type(v) == "string" then FR[v:upper()] = true end
            if type(v) == "table" and type(v[1]) == "string" then FR[v[1]:upper()] = true end
        end
    end
    add(dofile(DIR .. "words_fr.lua"))
    local function allFrench(list)
        if #list == 0 then return false end
        for _, e in ipairs(list) do if not FR[e.word:upper()] then return false end end
        return true
    end
    local function isFrench(screen) return FR[screen.board.secret:upper()] == true end
    local function langOf(screen) return screen.board.lang end

    it("deals French content when KOReader is in French", function()
        koreader("fr")
        local screen = open()
        assert.are.equal("fr", langOf(screen))
        assert.is_true(isFrench(screen))
        screen:onNewGame()
        assert.are.equal("fr", langOf(screen))
        assert.is_true(isFrench(screen))
    end)

    it("no longer sticks to an English choice saved by an older version", function()
        koreader("fr")
        local screen = open({ lang = "en" })
        assert.are.equal("fr", langOf(screen))
        assert.is_true(isFrench(screen))
    end)

    it("keeps the language picked in its menu while KOReader's stays the same", function()
        koreader("fr")
        local screen, store = open()
        screen:openLangMenu()
        assert.are.equal("fr", picker.current_id)
        picker.on_select("en")
        assert.are.equal("en", langOf(screen))
        assert.are.equal("en", store.lang)
        store.state = nil                               -- no game in progress
        local again = open(store)                       -- next time the game opens
        assert.are.equal("en", langOf(again))
        again:openLangMenu()
        assert.are.equal("en", picker.current_id)
        koreader("de")                                  -- KOReader changed: follow it
        assert.are.equal("en", langOf(open(store)))     -- (no German: English)
        koreader("en")
        local en = open(store)
        en:openLangMenu()
        picker.on_select("fr")
        store.state = nil
        koreader("fr")
        assert.are.equal("fr", langOf(open(store)))
    end)
end)
