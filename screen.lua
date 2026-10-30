local _dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"
local function lrequire(name)
    local key = _dir .. name
    if not package.loaded[key] then
        package.loaded[key] = assert(loadfile(_dir .. name .. ".lua"))()
    end
    return package.loaded[key]
end

local Blitbuffer      = require("ffi/blitbuffer")
local Device          = require("device")
local FrameContainer  = require("ui/widget/container/framecontainer")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan  = require("ui/widget/horizontalspan")
local Size            = require("ui/size")
local UIManager       = require("ui/uimanager")
local VerticalGroup   = require("ui/widget/verticalgroup")
local VerticalSpan    = require("ui/widget/verticalspan")
local _               = require("i18n")
local T               = require("ffi/util").template

local ScreenBase        = require("screen_base")
local MenuHelper        = require("menu_helper")
local KeyboardWidget    = lrequire("common/keyboard_widget")
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

function WordleScreen:init()
    local state = self.plugin:loadState()
    local lang  = self.plugin:getSetting("lang", "en")
    self.board  = WordleBoard:new{ lang = lang }
    if not self.board:load(state) then
        -- fresh game
    end
    ScreenBase.init(self)
end

function WordleScreen:isRoundOver()
    return self.board.won or self.board.lost
end

function WordleScreen:serializeState()
    return self.board:serialize()
end

function WordleScreen:buildLayout()
    local is_landscape = self:isLandscape()

    -- Top bar
    local title_bar = self:buildTitleBar(_("Wordle"), function()
        return {
            { text = _("New game"),     callback = function() self:onNewGame() end },
            { text = self:_langLabel(), callback = function() self:openLangMenu() end },
            self:makeRulesButtonConfig(GAME_RULES_EN, GAME_RULES_FR),
        }
    end)

    local controls_w = self:getControlsWidth()
    self.status_text:setMaxWidth(controls_w)
    self.keyboard_widget = KeyboardWidget.build{
        width      = controls_w,
        key_height = DeviceScreen:scaleBySize(52),
        backspace  = true,
        enter      = true,
        onKey      = function(k) self:onVirtualKey(k) end,
        -- Same dark-to-light order as the tiles, one step lighter: a key's
        -- label is always black, and black on the tiles' GRAY_4 is unreadable.
        keyColor   = function(k)
            local ks = self.board.key_state[k]
            if ks == WordleBoard.STATE_CORRECT then return Blitbuffer.COLOR_GRAY_7 end
            if ks == WordleBoard.STATE_PRESENT then return Blitbuffer.COLOR_GRAY_B end
            if ks == WordleBoard.STATE_ABSENT  then return Blitbuffer.COLOR_GRAY_E end
            return nil
        end,
    }
    local controls = VerticalGroup:new{
        align = "center",
        self.status_text,
        VerticalSpan:new{ width = Size.span.vertical_large },
        self.keyboard_widget,
    }

    -- No bottom actions while playing (the keyboard is the control); once
    -- the round is over, "New game" appears under it.
    self.action_bar = nil
    if self:isRoundOver() then
        table.insert(controls, VerticalSpan:new{ width = Size.span.vertical_default })
        table.insert(controls, self:buildActionBar({}))
    end

    -- Board widget: the grid draws its own thick border, so the frame only
    -- pads it.
    local frame_pad   = Size.padding.default
    local frame_extra = 2 * frame_pad
    local budget_w, budget_h = self:getBoardBudget(title_bar, controls)
    self.board_widget = WordleBoardWidget:new{
        board      = self.board,
        max_width  = math.max(budget_w - frame_extra, 60),
        max_height = math.max(budget_h - frame_extra, 60),
    }

    local board_frame = FrameContainer:new{
        padding    = frame_pad,
        margin     = 0,
        bordersize = 0,
        self.board_widget,
    }

    if is_landscape then
        local content = HorizontalGroup:new{
            align = "center",
            board_frame,
            HorizontalSpan:new{ width = self:getGutter() },
            controls,
        }
        self:buildLandscapeLayout(title_bar, content)
    else
        self:buildPortraitLayout(title_bar, board_frame,
            VerticalGroup:new{ align = "center", controls, VerticalSpan:new{ width = self:getGutter() } })
    end
    self:updateStatus()
end

function WordleScreen:onVirtualKey(key)
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
    else
        -- The running score only shows between games: mid-game the line
        -- has to fit the narrow landscape side panel.
        local score = self:joinStatus(
            T(_("Wins: %1"),   self.board.wins),
            T(_("Losses: %1"), self.board.losses))
        if self.board.won then
            status = self:joinStatus(
                T(_("Solved in %1!"), #self.board.guesses),
                T(_("Streak: %1"), self.board.streak))
        elseif self.board.lost then
            status = self:joinStatus(T(_("The word was %1."), self.board.secret), score)
        else
            status = T(_("Try %1/%2"), self.board.row, self.board.max_tries)
        end
    end
    ScreenBase.updateStatus(self, status)
end

function WordleScreen:_langLabel()
    local lang = self.plugin:getSetting("lang", "en")
    return T(_("Language: %1"), lang == "fr" and "FR" or "EN")
end

return WordleScreen
