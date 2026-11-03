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

local Font            = require("ui/font")
local TextBoxWidget   = require("ui/widget/textboxwidget")
local TextWidget      = require("ui/widget/textwidget")
local Party           = require("party")
local WordleParty     = lrequire("party_game")

local DeviceScreen = Device.screen

-- Party seats are teams here, 2 to 4.
local TEAMS = { teams = true, max = 4 }

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

local PARTY_RULES_EN = _([[
Wordle · multiplayer — Rules

For 2 to 4 teams around one reader laid in the middle of the table. Everyone sees the same grid; one player of the team to play types on the on-screen keyboard.

Setup (game menu)
• Teams: 2, 3 or 4. Team names: tap a team to rename it (names are remembered).
• Rounds: 3, 5, 7 or 10 words per match.
• First letter shown (on by default): every row starts with the word's first letter, locked in place.
• Language: the word list (EN or FR).

A round
• The team written in big type plays one row: a 5-letter word, then ↵. The tiles show the hints as in solo: green = right letter, right place; yellow = in the word, elsewhere; grey = not in the word.
• Then the next team plays the next row, on the same grid, and so on.
• A word that is not in the word list is refused: the row is cleared and the turn passes to the next team (no row is used up). A word too short is just refused, the same team retries.
• Each round, another team starts.

Scoring
• The team that finds the word scores the rows left, counting its own: 6 points on row 1, 5 on row 2, 4 on row 3, 3 on row 4, 2 on row 5, 1 on row 6.
• If all 6 rows are used without finding it, the word is revealed and nobody scores.
• The scores stay on screen under the team to play; "Scores" in the menu shows the ranking.

End of the match
After the last round the final scoreboard shows the winner: the team with the most points. Teams with the same total share their place; if several teams are first, it's a tie. "New game" starts a new match.
]])

local PARTY_RULES_FR = [[
Wordle · à plusieurs — Règles

Pour 2 à 4 équipes autour d'une liseuse posée au milieu de la table. Tout le monde voit la même grille ; un joueur de l'équipe qui joue tape sur le clavier à l'écran.

Réglages (menu du jeu)
• Équipes : 2, 3 ou 4. Noms des équipes : touchez une équipe pour la renommer (les noms sont mémorisés).
• Manches : 3, 5, 7 ou 10 mots par partie.
• Première lettre donnée (activé par défaut) : chaque ligne commence par la première lettre du mot, bloquée.
• Langue : la liste de mots (EN ou FR).

Une manche
• L'équipe écrite en gros joue une ligne : un mot de 5 lettres, puis ↵. Les cases donnent les indices comme en solo : vert = bonne lettre, bien placée ; jaune = dans le mot, ailleurs ; gris = absente du mot.
• Puis l'équipe suivante joue la ligne suivante, sur la même grille, et ainsi de suite.
• Un mot absent de la liste est refusé : la ligne est effacée et la main passe à l'équipe suivante (aucune ligne n'est perdue). Un mot trop court est simplement refusé, la même équipe recommence.
• À chaque manche, une autre équipe commence.

Points
• L'équipe qui trouve le mot marque les lignes restantes, la sienne comprise : 6 points à la ligne 1, 5 à la ligne 2, 4 à la ligne 3, 3 à la ligne 4, 2 à la ligne 5, 1 à la ligne 6.
• Si les 6 lignes sont jouées sans trouver, le mot est révélé et personne ne marque.
• Les scores restent affichés sous l'équipe qui joue ; « Scores » dans le menu donne le classement.

Fin de partie
Après la dernière manche, le tableau final affiche la gagnante : l'équipe qui a le plus de points. Des équipes à égalité partagent leur place ; si plusieurs sont premières, c'est une égalité. « Nouvelle partie » relance une partie.
]]

local RULES = {
    solo  = { GAME_RULES_EN, GAME_RULES_FR },
    party = { PARTY_RULES_EN, PARTY_RULES_FR },
}

local WordleScreen = ScreenBase:extend{}

function WordleScreen:init()
    -- Party matches are saved under their own key: the solo game in
    -- progress (and its wins/streak) is left as it was.
    self.party = self.plugin.launch_mode == "party"
    if self.party then
        self.match = WordleParty.load(self.plugin:loadState("party_state"), self.plugin)
                     or self:_newMatch()
        self.board = self.match.board
    else
        -- A saved game is restored; otherwise a fresh word is drawn.
        self.board  = WordleBoard:new{ lang = self.plugin:getSetting("lang", "en"),
                                       plugin = self.plugin, data = self.plugin:loadState() }
    end
    ScreenBase.init(self)
end

function WordleScreen:isRoundOver()
    return self.board.won or self.board.lost
end

function WordleScreen:getRoundOverButtons()
    if self.party and not self.match:isMatchOver() then
        return { { text = _("Next round"), callback = function() self:onNextRound() end } }
    end
    return ScreenBase.getRoundOverButtons(self)
end

function WordleScreen:serializeState()
    return self.board:serialize()
end

function WordleScreen:_save()
    if self.party then
        self.plugin:saveState(self.match:serialize(), "party_state")
    else
        self.plugin:saveState(self.board:serialize())
    end
end

-- ScreenBase's version saves serializeState() as the solo game; a party
-- match goes to its own key instead.
function WordleScreen:closeScreen()
    self:_save()
    self.plugin:onScreenClosed()
    UIManager:close(self)
    UIManager:setDirty(nil, "full")
end

-- ---------------------------------------------------------------------------
-- Party mode (teams)
-- ---------------------------------------------------------------------------

function WordleScreen:_teamCount()
    return Party.loadCount(self.plugin, TEAMS)
end

function WordleScreen:_newMatch()
    return WordleParty.new{
        names        = Party.loadPlayers(self.plugin, self:_teamCount(), TEAMS),
        rounds       = self.plugin:getSetting("party_rounds", WordleParty.DEFAULT_ROUNDS),
        lang         = self.plugin:getSetting("lang", "en"),
        first_letter = self.plugin:getSetting("party_first_letter", true),
        plugin       = self.plugin,
    }
end

function WordleScreen:_redraw()
    self:buildLayout()
    UIManager:setDirty(self, function() return "ui", self.dimen end)
end

function WordleScreen:onNextRound()
    self.match:startRound()
    self.board = self.match.board
    self:_save()
    self:_redraw()
end

function WordleScreen:openTeamCountMenu()
    Party.pickCount(self.plugin, function() self:onNewGame() end, self, TEAMS)
end

-- Renaming keeps the match going.
function WordleScreen:openTeamNames()
    local names = self.match.scores.names
    Party.editPlayers(self.plugin, names, function()
        self:_save()
        self:_redraw()
    end, self, TEAMS)
end

function WordleScreen:openRoundsMenu()
    local items = {}
    for _i, n in ipairs(WordleParty.ROUND_CHOICES) do
        items[#items + 1] = { id = n, text = tostring(n) }
    end
    MenuHelper.openPickerMenu{
        title      = _("Rounds"),
        items      = items,
        current_id = self.match.rounds,
        parent     = self,
        on_select  = function(n)
            self.plugin:saveSetting("party_rounds", n)
            self:onNewGame()
        end,
    }
end

function WordleScreen:toggleFirstLetter()
    self.plugin:saveSetting("party_first_letter",
        not self.plugin:getSetting("party_first_letter", true))
    self:onNewGame()
end

function WordleScreen:openModeMenu()
    MenuHelper.openPickerMenu{
        title      = _("Mode"),
        items      = { { id = "solo",  text = _("Solo") },
                       { id = "party", text = _("Multiplayer") } },
        current_id = self.party and "party" or "solo",
        parent     = self,
        on_select  = function(mode) self:setMode(mode) end,
    }
end

-- Switches between solo and party, then starts a new game in that mode.
function WordleScreen:setMode(mode)
    if (mode == "party") == self.party then return end
    self:_save()
    self.plugin.launch_mode = mode
    self.party = mode == "party"
    if self.party then
        self.match = self:_newMatch()
        self.board = self.match.board
    else
        self.match = nil
        self.board = WordleBoard:new{ lang = self.plugin:getSetting("lang", "en"),
                                      plugin = self.plugin, data = self.plugin:loadState() }
        if self.board.loaded then self.board:newGame() end
    end
    self:_save()
    self:_redraw()
end

function WordleScreen:_modeLabel()
    return T(_("Mode: %1"), self.party and _("Multiplayer") or _("Solo"))
end

-- The big line over the keyboard: whose turn it is, then who scored.
function WordleScreen:_bannerText()
    local m = self.match
    if m:isMatchOver() then
        local leaders = Party.leaders(m.scores)
        if #leaders == 1 then return T(_("%1 wins!"), m:teamName(leaders[1])) end
        return _("It's a tie!")
    end
    local last = m.last
    if last and last.result == "win" then
        return T(_("%1 scores %2!"), m:teamName(last.team), last.points)
    elseif self.board.lost then
        return self.board.secret
    end
    return m:teamName()
end

-- Big bold line, shrunk until it fits the controls' width (the landscape
-- side panel is narrow).
function WordleScreen:_buildBanner(text, width)
    local w
    for _i, size in ipairs({ 30, 26, 22, 18 }) do
        if w then w:free() end
        w = TextWidget:new{ text = text, face = Font:getFace("tfont", size), bold = true }
        if w:getSize().w <= width then return w end
    end
    w:free()
    return TextWidget:new{ text = text, face = Font:getFace("tfont", 18), bold = true,
        max_width = width }
end

function WordleScreen:_partyMenu()
    local fl = self.plugin:getSetting("party_first_letter", true)
    return {
        { text = _("New game"), callback = function() self:onNewGame() end },
        { text = T(_("Teams: %1"), self.match:teamCount()),
          callback = function() self:openTeamCountMenu() end },
        { text = _("Team names"), callback = function() self:openTeamNames() end },
        { text = T(_("Rounds: %1"), self.match.rounds),
          callback = function() self:openRoundsMenu() end },
        { text = T(_("First letter shown: %1"), fl and _("On") or _("Off")),
          callback = function() self:toggleFirstLetter() end },
        { text = self:_langLabel(), callback = function() self:openLangMenu() end },
        { text = self:_modeLabel(), callback = function() self:openModeMenu() end },
        { text = _("Scores"), callback = function() Party.showScoreboard(self.match.scores) end },
        self:makeModeRulesButtonConfig(RULES),
    }
end

function WordleScreen:buildLayout()
    local is_landscape = self:isLandscape()

    -- Top bar
    local title_bar = self:buildTitleBar(_("Wordle"), function()
        if self.party then return self:_partyMenu() end
        return {
            { text = _("New game"),     callback = function() self:onNewGame() end },
            { text = self:_langLabel(), callback = function() self:openLangMenu() end },
            { text = self:_modeLabel(), callback = function() self:openModeMenu() end },
            self:makeModeRulesButtonConfig(RULES),
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
    if self.party then
        -- Readable from across the table: whose turn it is, then the scores.
        table.insert(controls, 1, self:_buildBanner(self:_bannerText(), controls_w))
        table.insert(controls, 2, TextBoxWidget:new{
            text      = Party.statusText(self.match.scores),
            face      = Font:getFace("cfont", 20),
            width     = controls_w,
            alignment = "center",
        })
        table.insert(controls, 3, VerticalSpan:new{ width = Size.span.vertical_default })
    end

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
    if key == "↵" and self.party then
        local result = self.match:submit()
        if result == "short" then
            self:updateStatus(_("Word too short!"))
            return
        elseif result == "done" then
            return
        end
        self:_save()
        self:_redraw()
        if result == "invalid" then
            self:updateStatus(_("Not in word list! Turn passes."))
        end
        if self.match:isMatchOver() then
            Party.showScoreboard(self.match.scores, { final = true })
        end
    elseif key == "↵" then
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
    if self.party then
        self.match = self:_newMatch()
        self.board = self.match.board
        self:_save()
        self:_redraw()
        return
    end
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
        local round = self.party
            and T(_("Round %1/%2"), self.match:round(), self.match.rounds)
        if self.party and self.board.won then
            status = self:joinStatus(T(_("The word was %1."), self.board.secret), round)
        elseif self.party and self.board.lost then
            status = self:joinStatus(T(_("The word was %1."), self.board.secret), _("Nobody scores"))
        elseif self.party then
            status = self:joinStatus(round,
                T(_("Try %1/%2"), self.board.row, self.board.max_tries))
        elseif self.board.won then
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
