local Chess = {}
local xToFile = { [1] = "a", [2] = "b", [3] = "c", [4] = "d", [5] = "e", [6] = "f", [7] = "g", [8] = "h" }

Chess.pieceGlyph = {
	tp = "\105", tn = "\163", tb = "1", tr = "\207", tq = "\5", tk = "\214",
	p = {
		'   ##   ',
		'  ####  ',
		' ###### ',
		'  ####  ',
		'   ##   ',
		'   ##   ',
		'  ####  ',
		' ###### ',
		'########',
	},
	b = {
		'   ##   ',
		'  ####  ',
		' ###### ',
		' ###### ',
		'  ####  ',
		'   ##   ',
		'  ####  ',
		'   ##   ',
		'   ##   ',
		' ###### ',
		'########',
		'########',
	},
	n = {
		'   ####  ',
		'  ## ### ',
		' ########',
		'#########',
		'#########',
		' ## #### ',
		'    #### ',
		'   ####  ',
		'   ####  ',
		'  ######',
		' ########',
		' ########',		
	},
	r = {
		'## ## ##',
		'## ## ##',
		'########',
		'########',
		' ###### ',
		'  ####  ',
		'  ####  ',
		'  ####  ',
		'  ####  ',
		' ######',
		'########',
		'########',
	},
	q = {
		'   ##   ',
		'## ## ##',
		' ###### ',
		' ###### ',
		'  ####  ',
		'   ##   ',
		'   ##   ',
		'   ##   ',
		'  ####  ',
		' ###### ',
		'########',
		'########',
	},
	k = {
		'   ##   ',
		'  ####  ',
		'   ##   ',
		' ###### ',
		' ###### ',
		'  ####  ',
		'   ##   ',
		'   ##   ',
		'  ####  ',
		' ###### ',
		'########',
		'########',
	},
}
Chess.BOARD_BG_A = colors.orange
Chess.BOARD_BG_B = colors.brown

local Game = dofile('Data/Chess/Game.lua')
local Board
if term.setGraphicsMode and term.getGraphicsMode() then
	Board = dofile('Data/Chess/BoardGM.lua')
	Board.UI = require 'UIGM'
	Board.font = require 'Font'
	function Chess.drawPiece(x, y, gl, color)
		local maxW, maxH = 1, 1
		for h = 1, Chess.CELL_H do
			if gl[h] then
				maxH = math.min(Chess.CELL_H, math.max(h, maxH))
				maxW = math.min(Chess.CELL_W, math.max(#gl[h], maxW))
			end
		end
		for h = 1, maxH do
			local line = gl[h]
			for w = 1, maxW do
				if line and line:sub(w,w) == '#' then
					term.setPixel(x + w + math.floor((Chess.CELL_W - maxW)/2) - 1, y + h + math.floor((Chess.CELL_H - maxH)/2) - 1, color)
				end
			end
		end
	end
	Board.drawPiece = Chess.drawPiece
else
	Board = dofile('Data/Chess/Board.lua')
	Board.UI = require 'UI'
end

local function makeBoard()
	local board = {}
	for i = 1, 8 do board[i] = {} end
	return board
end

local function pieceColor(p) return p and p:sub(1, 1) or nil end
Board.Chess = Chess
Board.makeBoard = makeBoard
Board.xToFile = xToFile
Board.pieceGlyph = Chess.pieceGlyph
Board.pieceColor = pieceColor
Game.makeBoard = makeBoard
Game.xToFile = xToFile
Game.pieceColor = pieceColor

Chess.Game = Game.Game
Chess.Board = Board.Board

return Chess