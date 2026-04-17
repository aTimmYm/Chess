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
	-- function Chess.drawPiece(x, y, gl, color)
	-- 	local maxW, maxH = 1, 1
	-- 	for h = 1, Chess.CELL_H do
	-- 		if gl[h] then
	-- 			maxH = math.min(Chess.CELL_H, math.max(h, maxH))
	-- 			maxW = math.min(Chess.CELL_W, math.max(#gl[h], maxW))
	-- 		end
	-- 	end
	-- 	for h = 1, maxH do
	-- 		local line = gl[h]
	-- 		for w = 1, maxW do
	-- 			if line and line:sub(w,w) == '#' then
	-- 				term.setPixel(x + w + math.floor((Chess.CELL_W - maxW)/2) - 1, y + h + math.floor((Chess.CELL_H - maxH)/2) - 1, color)
	-- 			end
	-- 		end
	-- 	end
	-- end
	function Chess.drawPiece(x, y, gl, w, h)
		term.drawPixels(x, y, gl, w, h)
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

local W, H = 14, 14
Chess.cacheSize = {}
for k, lines in pairs(Chess.pieceGlyph) do
	if type(lines) == 'table' then
		local Height = #lines
		local maxW = 0
		for y, line in ipairs(lines) do
			maxW = math.min(W, math.max(#line, maxW))
		end
		Chess.cacheSize[k] = {W = maxW, H = Height}
	end
end

Chess.cacheGlyph = {}
local function chacheGlyphs(white, black)
	if type(white) ~= 'number' or type(black) ~= 'number' then return error('All arguments may be numbers', 2) end
	for k, lines in pairs(Chess.pieceGlyph) do
		if type(lines) == 'table' then
			Chess.cacheGlyph['w' .. k] = {}
			Chess.cacheGlyph['b' .. k] = {}
			local dx = math.floor((W - Chess.cacheSize[k].W) / 2)
			local dy = math.floor((H - Chess.cacheSize[k].H) / 2)
			for y = 1, H do
				Chess.cacheGlyph['w' .. k][y] = {}
				Chess.cacheGlyph['b' .. k][y] = {}
				for x = 1, W do
					Chess.cacheGlyph['w' .. k][y][x] = -1
					Chess.cacheGlyph['b' .. k][y][x] = -1
				end
			end
			for y = 1, Chess.cacheSize[k].H do
				for x = 1, Chess.cacheSize[k].W do
					if lines[y] and lines[y]:sub(x, x) == '#' then
						Chess.cacheGlyph['w' .. k][dy + y][dx + x] = white
						Chess.cacheGlyph['b' .. k][dy + y][dx + x] = black
					end
				end
			end
		end
	end
end
chacheGlyphs(colors.white, colors.black)

local function pieceColor(p) return p and p:sub(1, 1) or nil end
Board.Chess = Chess
Board.makeBoard = makeBoard
Board.xToFile = xToFile
Board.pieceGlyph = Chess.pieceGlyph
Board.cacheGlyph = Chess.cacheGlyph
Board.cacheSize = Chess.cacheSize
Board.pieceColor = pieceColor
Game.makeBoard = makeBoard
Game.xToFile = xToFile
Game.pieceColor = pieceColor

Chess.cacheGlyphs = chacheGlyphs
Chess.Game = Game.Game
Chess.Board = Board.Board

return Chess