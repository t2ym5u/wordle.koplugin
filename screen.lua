local _dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
local function lrequire(name)
    local key = _dir .. name
    if not package.loaded[key] then
        package.loaded[key] = assert(loadfile(_dir .. name .. ".lua"))()
    end
    return package.loaded[key]
end

local Blitbuffer      = require("ffi/blitbuffer")
local ButtonTable     = require("ui/widget/buttontable")
local Device          = require("device")
local FrameContainer  = require("ui/widget/container/framecontainer")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan  = require("ui/widget/horizontalspan")
local Size            = require("ui/size")
local UIManager       = require("ui/uimanager")
local VerticalGroup   = require("ui/widget/verticalgroup")
local VerticalSpan    = require("ui/widget/verticalspan")
local _               = require("gettext")
local T               = require("ffi/util").template

local ScreenBase        = require("screen_base")
local MenuHelper        = require("menu_helper")
local WordleBoard       = lrequire("board")
local WordleBoardWidget = lrequire("board_widget")

local DeviceScreen = Device.screen

-- ---------------------------------------------------------------------------
-- WordleScreen
-- ---------------------------------------------------------------------------

local GAME_RULES_EN = _([[
Wordle — Rules

Guess the secret 5-letter word in 6 attempts.

After each guess:
• Green tile — the letter is in the correct position.
• Yellow tile — the letter is in the word but in the wrong position.
• Grey tile — the letter is not in the word.

Use the on-screen keyboard to enter letters. Press ↵ to submit a guess, ⌫ to delete.
The keyboard shows the status of each letter used so far.
]])

local GAME_RULES_FR = [[
Wordle — Règles

Devinez le mot secret de 5 lettres en 6 tentatives.

Après chaque proposition :
• Case verte — la lettre est à la bonne position.
• Case jaune — la lettre est dans le mot mais à la mauvaise position.
• Case grise — la lettre n'est pas dans le mot.

Utilisez le clavier à l'écran pour entrer des lettres. Appuyez sur ↵ pour valider, sur ⌫ pour effacer.
Le clavier affiche l'état de chaque lettre utilisée.
]]

local WordleScreen = ScreenBase:extend{}

-- Keyboard rows
local KEY_ROWS = {
    {"Q","W","E","R","T","Y","U","I","O","P"},
    {"A","S","D","F","G","H","J","K","L"},
    {"↵","Z","X","C","V","B","N","M","⌫"},
}

function WordleScreen:init()
    local state = self.plugin:loadState()
    local lang  = self.plugin:getSetting("lang", "en")
    self.board  = WordleBoard:new{ lang = lang }
    if not self.board:load(state) then
        -- fresh game
    end
    ScreenBase.init(self)
end

function WordleScreen:serializeState()
    return self.board:serialize()
end

function WordleScreen:buildLayout()
    local sw           = DeviceScreen:getWidth()
    local sh = DeviceScreen:getHeight()
    local is_landscape = self:isLandscape()

    local btn_width = is_landscape
        and math.max(math.floor(sw * 0.38), 120)
        or  math.floor(sw * 0.9)

    -- Top bar
    local top_buttons = ButtonTable:new{
        shrink_unneeded_width = true,
        width   = btn_width,
        buttons = {{
            { text = _("New"), callback = function() self:onNewGame() end },
            { id = "lang_btn", text = self:_langLabel(),
              callback = function() self:openLangMenu() end },
            self:makeRulesButtonConfig(GAME_RULES_EN, GAME_RULES_FR),
            self:makeCloseButtonConfig(),
        }},
    }
    self.lang_btn = top_buttons:getButtonById("lang_btn")

    -- Board widget
    local max_cell = is_landscape and math.floor(sh * 0.7) or math.floor(sw * 0.9)
    local max_w    = math.floor(max_cell * (self.board.word_len / self.board.max_tries))
    local max_h    = max_cell
    if is_landscape then
        max_w = math.floor(sw * 0.42)
        max_h = sh - 40
    end

    self.board_widget = WordleBoardWidget:new{
        board      = self.board,
        max_width  = math.max(max_w, 60),
        max_height = math.max(max_h, 60),
    }

    local board_frame = FrameContainer:new{
        padding = Size.padding.default,
        margin  = Size.margin.default,
        self.board_widget,
    }

    -- Keyboard (keys coloured by best known state: dark=correct, grey=absent)
    local key_rows_cfg = {}
    for _, row in ipairs(KEY_ROWS) do
        local btns = {}
        for _, key in ipairs(row) do
            local k  = key
            local ks = self.board.key_state[k]
            local btn = {
                id       = "key_" .. k,
                text     = k,
                callback = function() self:onKeyPress(k) end,
            }
            if ks == WordleBoard.STATE_CORRECT then
                btn.background = Blitbuffer.COLOR_GRAY_3
                btn.text_color = Blitbuffer.COLOR_WHITE
            elseif ks == WordleBoard.STATE_ABSENT or ks == WordleBoard.STATE_PRESENT then
                btn.background = Blitbuffer.COLOR_GRAY_D
            end
            btns[#btns + 1] = btn
        end
        key_rows_cfg[#key_rows_cfg + 1] = btns
    end
    self.keyboard_widget = ButtonTable:new{
        shrink_unneeded_width = true,
        width   = btn_width,
        buttons = key_rows_cfg,
    }

    if is_landscape then
        local right = VerticalGroup:new{
            align = "center",
            top_buttons,
            VerticalSpan:new{ width = Size.span.vertical_large },
            self.status_text,
            VerticalSpan:new{ width = Size.span.vertical_large },
            self.keyboard_widget,
        }
        self.layout = HorizontalGroup:new{
            align  = "center",
            board_frame,
            HorizontalSpan:new{ width = Size.span.horizontal_default },
            right,
        }
    else
        self.layout = VerticalGroup:new{
            align = "center",
            VerticalSpan:new{ width = Size.span.vertical_large },
            top_buttons,
            VerticalSpan:new{ width = Size.span.vertical_large },
            board_frame,
            VerticalSpan:new{ width = Size.span.vertical_large },
            self.keyboard_widget,
            VerticalSpan:new{ width = Size.span.vertical_large },
            self.status_text,
            VerticalSpan:new{ width = Size.span.vertical_large },
        }
    end
    self[1] = self.layout
    self:updateStatus()
end

function WordleScreen:onKeyPress(key)
    if key == "↵" then
        local result = self.board:submit()
        if result == "short" then
            self:updateStatus(_("Word too short!"))
            return
        elseif result == "invalid" then
            self:updateStatus(_("Not in word list!"))
            return
        end
        -- Rebuild layout so keyboard reflects updated key_state colours.
        self:buildLayout()
        UIManager:setDirty(self, function() return "ui", self.dimen end)
        self.plugin:saveState(self.board:serialize())
    elseif key == "⌫" then
        self.board:deleteLetter()
        self.board_widget:refresh()
        self:updateStatus()
    else
        self.board:typeLetter(key)
        self.board_widget:refresh()
        self:updateStatus()
    end
end

function WordleScreen:onNewGame()
    self.board:newGame()
    self.plugin:saveState(self.board:serialize())
    self:buildLayout()
    UIManager:setDirty(self, function() return "ui", self.dimen end)
end

function WordleScreen:openLangMenu()
    local items = {
        { id = "en", text = _("English") },
        { id = "fr", text = _("Français") },
    }
    MenuHelper.openPickerMenu{
        title      = _("Language"),
        items      = items,
        current_id = self.plugin:getSetting("lang", "en"),
        parent     = self,
        on_select  = function(lang)
            self.board.lang = lang
            self.plugin:saveSetting("lang", lang)
            if self.lang_btn then
                self.lang_btn:setText(self:_langLabel(), self.lang_btn.width)
            end
            self:onNewGame()
        end,
    }
end

function WordleScreen:updateStatus(msg)
    local status
    if msg then
        status = msg
    elseif self.board.won then
        local attempt = #self.board.guesses
        status = T(_("Solved in %1! Streak: %2"), attempt, self.board.streak)
    elseif self.board.lost then
        status = T(_("Lost! Word: %1  W:%2 L:%3"),
            self.board.secret, self.board.wins, self.board.losses)
    else
        local typed = table.concat(self.board.current)
        if typed ~= "" then
            status = T(_("Try %1/%2: %3"), self.board.row, self.board.max_tries, typed)
        else
            status = T(_("Try %1/%2  W:%3 L:%4"),
                self.board.row, self.board.max_tries,
                self.board.wins, self.board.losses)
        end
    end
    ScreenBase.updateStatus(self, status)
end

function WordleScreen:_langLabel()
    local lang = self.plugin:getSetting("lang", "en")
    return lang == "fr" and "FR" or "EN"
end

return WordleScreen
