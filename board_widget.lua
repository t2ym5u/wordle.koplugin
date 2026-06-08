local Blitbuffer     = require("ffi/blitbuffer")
local Device         = require("device")
local Font           = require("ui/font")
local Geom           = require("ui/geometry")
local GestureRange   = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local RenderText     = require("ui/rendertext")
local UIManager      = require("ui/uimanager")

local gwb      = require("grid_widget_base")
local drawLine = gwb.drawLine

local WordleBoard = require("board")
local C_BG        = Blitbuffer.COLOR_WHITE
local C_BORDER    = Blitbuffer.COLOR_BLACK
local C_EMPTY     = Blitbuffer.COLOR_WHITE
local C_TBD       = Blitbuffer.COLOR_GRAY_E
local C_CORRECT   = Blitbuffer.COLOR_GRAY_4
local C_PRESENT   = Blitbuffer.COLOR_GRAY_9
local C_ABSENT    = Blitbuffer.COLOR_GRAY_D
local C_TEXT_DARK = Blitbuffer.COLOR_BLACK
local C_TEXT_LITE = Blitbuffer.COLOR_WHITE
local C_GRID      = Blitbuffer.COLOR_GRAY_B

-- ---------------------------------------------------------------------------
-- WordleBoardWidget
-- ---------------------------------------------------------------------------

local WordleBoardWidget = InputContainer:extend{
    board      = nil,
    cell_size  = 0,
    max_width  = 0,
    max_height = 0,
}

function WordleBoardWidget:init()
    local board   = self.board
    local cols    = board.word_len
    local rows    = board.max_tries
    local cell    = math.floor(math.min(self.max_width / cols, self.max_height / rows))
    cell          = math.max(cell, 14)
    self.cell     = cell
    self.w        = cell * cols
    self.h        = cell * rows
    self.dimen    = Geom:new{ w = self.w, h = self.h }
    self.paint_rect = nil

    local fs = math.max(8, math.floor(cell * 0.55))
    self.face = Font:getFace("cfont", fs)
end

function WordleBoardWidget:refresh()
    UIManager:setDirty(self, function()
        return "ui", self.paint_rect or self.dimen
    end)
end

function WordleBoardWidget:paintTo(bb, x, y)
    self.paint_rect = Geom:new{ x = x, y = y, w = self.w, h = self.h }
    local board = self.board
    local cols  = board.word_len
    local rows  = board.max_tries
    local cell  = self.cell
    local thin  = 1

    bb:paintRect(x, y, self.w, self.h, C_BG)

    for row = 1, rows do
        for col = 1, cols do
            local cx = x + (col - 1) * cell
            local cy = y + (row - 1) * cell
            local letter, state = "", WordleBoard.STATE_EMPTY

            local guess = board.guesses[row]
            if guess then
                letter = guess.letters[col] or ""
                state  = guess.states[col]  or WordleBoard.STATE_ABSENT
            elseif row == board.row and not board.won and not board.lost then
                letter = board.current[col] or ""
                state  = letter ~= "" and WordleBoard.STATE_TBD or WordleBoard.STATE_EMPTY
            end

            local bg = C_EMPTY
            if state == WordleBoard.STATE_TBD     then bg = C_TBD
            elseif state == WordleBoard.STATE_CORRECT then bg = C_CORRECT
            elseif state == WordleBoard.STATE_PRESENT then bg = C_PRESENT
            elseif state == WordleBoard.STATE_ABSENT  then bg = C_ABSENT
            end

            local pad = math.max(1, math.floor(cell * 0.05))
            bb:paintRect(cx + pad, cy + pad, cell - 2*pad, cell - 2*pad, bg)

            if letter ~= "" then
                local tc = (state == WordleBoard.STATE_CORRECT) and C_TEXT_LITE or C_TEXT_DARK
                local m  = RenderText:sizeUtf8Text(0, cell, self.face, letter, true, false)
                local tx = cx + math.floor((cell - m.x) / 2)
                local ty = cy + math.floor((cell - (m.y_bottom - m.y_top)) / 2) + m.y_top
                RenderText:renderUtf8Text(bb, tx, ty, self.face, letter, true, false, tc)
            end
        end
    end

    -- Grid lines
    for i = 0, cols do
        drawLine(bb, x + i*cell, y, thin, self.h, C_GRID)
    end
    for i = 0, rows do
        drawLine(bb, x, y + i*cell, self.w, thin, C_GRID)
    end

    -- Border
    local bw = math.max(2, math.floor(cell * 0.06))
    drawLine(bb, x,              y,              self.w, bw, C_BORDER)
    drawLine(bb, x,              y + self.h - bw, self.w, bw, C_BORDER)
    drawLine(bb, x,              y,              bw, self.h, C_BORDER)
    drawLine(bb, x + self.w - bw, y,             bw, self.h, C_BORDER)
end

return WordleBoardWidget
