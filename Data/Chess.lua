local UI = require "UI"

local Chess = {}
local onetwo = {['A'] = 1, ['B'] = 2, ['C'] = 3, ['D'] = 4, ['E'] = 5, ['F'] = 6, ['G'] = 7, ['H'] = 8}
local abc = {'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'}

local function toN(char)
	return onetwo[char]
end
local function toL(n)
	return abc[n]
end
local function invert(n)
	return 9 - n
end

local function Fift(from, to)
	local f = toN(from:sub(1,1)) + to[1]
	local r = from:sub(2) + to[2]

	return toL(f)..r
end

local function canFift(from, to)
	local f = toN(from:sub(1,1)) + to[1]
	local r = from:sub(2) + to[2]

	if f > 8 or f < 1 then return false end
	if r > 8 or r < 1 then return false end

	return true
end

local function between(source, target)
	local result = {}
	source = {toN(source:sub(1,1), source:sub(2))}

	for i

	return result
end

local function whichPiece(char)
	local chars = 'RNKQBP'
	local color
	local piece
	if not chars:find(char) then color = 'black' else color = 'white' end
	char = char:lower()
		if char == 'r' then piece = 'Rook'
	elseif char == 'n' then piece = 'Knight'
	elseif char == 'q' then piece = 'Queen'
	elseif char == 'p' then piece = 'Pawn'
	elseif char == 'k' then piece = 'King'
	elseif char == 'b' then piece = 'Bishop'
	end
	return piece, color
end

local function getAvailableMoves(self)
	local result = {}

	for i, v in ipairs(self.moves) do
		if self:canShift(v) then
			local coord = self:shift(v)
			if self:isSquareAvailableForMove(coord) then
				table.insert(result, coord)
			end
		end
	end

	return result
end

local function shift(self, shift)
	return Fift(self.coords, shift)
end

local function canShift(self, shift)
	return canFift(self.coords, shift)
end

local function isSquareAvailableForMove(self, coords)
	local board = self.parent
	if board:isSquareEmpty(coords) then
		return true
	else
		local piece = board:getPiece(coords)
		if piece.color ~= self.color then
			piece.canBeat = true
			return true
		end
	end
	return false
end

local function onMouseUp(self, btn, x, y)
	if not self:check(x, y) then return end
	local board = self.parent
	if self.color ~= self.root.team then
		if self.canBeat then
			board:onMouseDown(btn, x, y)
			board:removeChild(self)
		end
		return
	end
	if board.selected then
		board.selected.selected = false
		board.selected.dirty = true
	end
	board.selected = self
	self.selected = true
	board:onLayout()

	return true
end

local function PieceDraw(self)
	local board = self.parent
	term.setCursorPos(self.x, self.y)
	if self.selected then
		term.setBackgroundColor(colors.green)
	elseif self.canBeat then
		term.setBackgroundColor(colors.red)
	else
		term.setBackgroundColor(((self.local_x + self.local_y) % 2 ~= 0) and board.bc_alt or board.bc)
	end
	term.setTextColor((self.color == 'white') and colors.white or colors.black)
	local name = self.name:sub(1, 1):upper()
	if self.name == "Knight" then
		name = "N"
	end
	term.write(name)
end

function Chess.Piece(args)
	args.w = 1
	args.h = 1
	local instance = UI.Widget(args)

	instance.coords = args.coords
	instance.color = args.color
	instance.hasMoved = false

	instance.draw = PieceDraw
	-- instance.onMouseDown = onMouseDown
	instance.onMouseUp = onMouseUp
	instance.canShift = canShift
	instance.shift = shift
	instance.getAvailableMoves = getAvailableMoves
	instance.isSquareAvailableForMove = isSquareAvailableForMove

	return instance
end

function Chess.Pawn(args)
	local instance = Chess.Piece(args)

	instance.name = 'Pawn'

	return instance
end

function Chess.Rook(args)
	local instance = Chess.Piece(args)

	instance.name = 'Rook'

	instance.moves = {}
	for i = -7, 7 do
		if i ~= 0 then
			table.insert(instance.moves, {0, i})
			table.insert(instance.moves, {i, 0})
		end
	end

	return instance
end

function Chess.Knight(args)
	local instance = Chess.Piece(args)

	instance.name = 'Knight'

	instance.moves = {{2, 1}, {1, 2}, {-1, 2}, {-2, 1}, {-2, -1}, {-1, -2}, {2, -1}, {1, -2}}

	return instance
end

function Chess.Bishop(args)
	local instance = Chess.Piece(args)

	instance.name = 'Bishop'

	instance.moves = {}
	for i = -7, 7 do
		if i ~= 0 then
			table.insert(instance.moves, {i, i})
			table.insert(instance.moves, {i, -i})
		end
	end

	return instance
end

function Chess.Queen(args)
	local instance = Chess.Piece(args)

	instance.name = 'Queen'

	instance.moves = {}
	for i = -7, 7 do
		if i ~= 0 then
			table.insert(instance.moves, {i, i})
			table.insert(instance.moves, {i, -i})
			table.insert(instance.moves, {0, i})
			table.insert(instance.moves, {i, 0})
		end
	end

	return instance
end

-- local function KingisSquareAvailableForMove(self, coords)
-- 	local result = isSquareAvailableForMove(self, coords)
-- 	if not result then return end
-- 	local board = self.parent

-- 	for _, v in ipairs({{2, 1}, {1, 2}, {-1, 2}, {-2, 1}, {-2, -1}, {-1, -2}, {2, -1}, {1, -2}}) do
-- 		if canFift(coords, v) then
-- 			local coord = Fift(coords, v)
-- 			local piece = board:getPiece(coord)
-- 			if not board:isSquareEmpty(coord) and (piece.name == 'Knight' and piece.color ~= self.color) then return false end
-- 		end
-- 	end

-- 	for _, dir in ipairs({{-1, 1}, {1, 1}, {-1, -1}, {1, -1}}) do
-- 		for dist = 1, 7 do
-- 			local target_x = toN(coords:sub(1,1)) + (dir[1] * dist)
-- 			local target_y = coords:sub(2, 2) + (dir[2] * dist)
-- 			if target_x < 1 or target_x > 8 or target_y < 1 or target_y > 8 then
-- 				break
-- 			end
-- 			local coord = toL(target_x)..target_y
-- 			if not board:isSquareEmpty(coord) then
-- 				local piece = board:getPiece(coord)
-- 				if piece.color == self.color then break end
-- 				if (piece.name == 'Queen' and piece.color ~= self.color) or (piece.name == 'Bishop' and piece.color ~= self.color) then
-- 					return false
-- 				elseif dist == 1 and (piece.name == 'King' and piece.color ~= self.color) then
-- 					return false
-- 				end
-- 			end
-- 		end
-- 	end

-- 	for _, dir in ipairs({{0, 1}, {1, 0}, {-1, 0}, {0, -1}}) do
-- 		for dist = 1, 7 do
-- 			local target_x = toN(coords:sub(1,1)) + (dir[1] * dist)
-- 			local target_y = coords:sub(2, 2) + (dir[2] * dist)
-- 			if target_x < 1 or target_x > 8 or target_y < 1 or target_y > 8 then
-- 				break
-- 			end
-- 			local coord = toL(target_x)..target_y
-- 			if not board:isSquareEmpty(coord) then
-- 				local piece = board:getPiece(coord)
-- 				if piece.color == self.color then break end
-- 				if (piece.name == 'Queen' and piece.color ~= self.color) or (piece.name == 'Rook' and piece.color ~= self.color) then
-- 					return false
-- 				elseif dist == 1 and (piece.name == 'King' and piece.color ~= self.color) then
-- 					return false
-- 				end
-- 			end
-- 		end
-- 	end

-- 	for _, dir in ipairs(self.color == 'white' and {{-1, 1}, {1, 1}} or {{-1, -1}, {1, -1}}) do
-- 		for dist = 1, 1 do
-- 			local target_x = toN(coords:sub(1,1)) + (dir[1] * dist)
-- 			local target_y = coords:sub(2, 2) + (dir[2] * dist)
-- 			if target_x < 1 or target_x > 8 or target_y < 1 or target_y > 8 then
-- 				break
-- 			end
-- 			local coord = toL(target_x)..target_y
-- 			if not board:isSquareEmpty(coord) then
-- 				local piece = board:getPiece(coord)
-- 				if piece.color == self.color then break end
-- 				if (piece.name == 'Pawn' and piece.color ~= self.color) then
-- 					-- piece.canBeat = false
-- 					return false
-- 				end
-- 			end
-- 		end
-- 	end

-- 	return result
-- end

function Chess.King(args)
	local instance = Chess.Piece(args)
	
	instance.name = 'King'
	
	instance.moves = {}
	for i = -1, 1 do
		if i ~= 0 then
			table.insert(instance.moves, {i, i})
			table.insert(instance.moves, {i,-i})
			table.insert(instance.moves, {0, i})
			table.insert(instance.moves, {i, 0})
		end
	end
	-- instance.isSquareAvailableForMove = KingisSquareAvailableForMove

	return instance
end

local function setPiece(self, coords, piece)
	piece.coords = coords
	piece.local_x = toN(coords:sub(1,1))
	piece.local_y = invert(coords:sub(2,2))
	self.pieces[coords] = piece
end

local function removePiece(self, coords)
	self.pieces[coords] = nil
end

local function getPiece(self, coords)
	return self.pieces[coords]
end

local function isSquareEmpty(self, coords)
	return (not self.pieces[coords])
end

local function movePiece(self, from, to)
	local piece = self:getPiece(from)
	-- if not piece then return end
	self:removePiece(from)
	self:setPiece(to, piece)
	-- self:onLayout()
end

local function ColorBoardBlit(obj, n)
	local bc_blit = colors.toBlit(obj.bc)
	local bc_alt_blit = colors.toBlit(obj.bc_alt)
	if n % 2 ~= 0 then
		return (bc_blit..bc_alt_blit):rep(obj.w/2)
	else
		return (bc_alt_blit..bc_blit):rep(obj.w/2)
	end
end

local function setDefaultPieces(self, fen)
	local x, y = 1, 8
	for i = 1, #fen do
		local char = fen:sub(i, i)
		if tonumber(char) then
			x = x + char
		elseif char == '/' then
			y = y - 1
			x = 1
		elseif char == ' ' then char = fen:sub(i + 1, -1) break
		else
			local pieceN, color = whichPiece(char)
			local piece = Chess[pieceN]{x = x, y = invert(y), color = color, coords = toL(x)..y}
			self:addChild(piece)
			self:setPiece(piece.coords, piece)
			x = x + 1
		end
	end
	-- local piece
	-- -- Pawn
	-- for i = 1, 8 do
	-- 	local alph = toL(i)
	-- 	piece = Chess.Pawn{x = i, y = 2, coords = alph..'7', color = 'black'}
	-- 	self:addChild(piece)
	-- 	self:setPiece(alph..'7', piece)
	-- 	piece = Chess.Pawn{x = i, y = 7, coords = alph..'2', color = 'white'}
	-- 	self:addChild(piece)
	-- 	self:setPiece(alph..'2', piece)
	-- end
	-- -- Rook
	-- piece = Chess.Rook{x = 1, y = 8, coords = 'A1', color = 'white'}
	-- self:addChild(piece)
	-- self:setPiece('A1', piece)
	-- piece = Chess.Rook{x = 8, y = 8, coords = 'H1', color = 'white'}
	-- self:addChild(piece)
	-- self:setPiece('H1', piece)
	-- piece = Chess.Rook{x = 1, y = 1, coords = 'A8', color = 'black'}
	-- self:addChild(piece)
	-- self:setPiece('A8', piece)
	-- piece = Chess.Rook{x = 8, y = 1, coords = 'H8', color = 'black'}
	-- self:addChild(piece)
	-- self:setPiece('H8', piece)
	-- -- Knight
	-- piece = Chess.Knight{x = 2, y = 8, coords = 'B1', color = 'white'}
	-- self:addChild(piece)
	-- self:setPiece('B1', piece)
	-- piece = Chess.Knight{x = 7, y = 8, coords = 'G1', color = 'white'}
	-- self:addChild(piece)
	-- self:setPiece('G1', piece)
	-- piece = Chess.Knight{x = 2, y = 1, coords = 'B8', color = 'black'}
	-- self:addChild(piece)
	-- self:setPiece('B8', piece)
	-- piece = Chess.Knight{x = 7, y = 1, coords = 'G8', color = 'black'}
	-- self:addChild(piece)
	-- self:setPiece('G8', piece)
	-- -- Bishop
	-- piece = Chess.Bishop{x = 3, y = 8, coords = 'C1', color = 'white'}
	-- self:addChild(piece)
	-- self:setPiece('C1', piece)
	-- piece = Chess.Bishop{x = 6, y = 8, coords = 'F1', color = 'white'}
	-- self:addChild(piece)
	-- self:setPiece('F1', piece)
	-- piece = Chess.Bishop{x = 3, y = 1, coords = 'C8', color = 'black'}
	-- self:addChild(piece)
	-- self:setPiece('C8', piece)
	-- piece = Chess.Bishop{x = 6, y = 1, coords = 'F8', color = 'black'}
	-- self:addChild(piece)
	-- self:setPiece('F8', piece)
	-- -- Queen
	-- piece = Chess.Queen{x = 4, y = 8, coords = 'D1', color = 'white'}
	-- self:addChild(piece)
	-- self:setPiece('D1', piece)
	-- piece = Chess.Queen{x = 4, y = 1, coords = 'D8', color = 'black'}
	-- self:addChild(piece)
	-- self:setPiece('D8', piece)
	-- -- King
	-- piece = Chess.King{x = 5, y = 8, coords = 'E1', color = 'white'}
	-- self:addChild(piece)
	-- self:setPiece('E1', piece)
	-- piece = Chess.King{x = 5, y = 1, coords = 'E8', color = 'black'}
	-- self:addChild(piece)
	-- self:setPiece('E8', piece)
end

local function BoardOnMouseDown(self, btn, x, y)
	local selected = self.selected
	if not selected then return end
	local lX, lY = x - self.x + 1, y - self.y + 1
	for i, v in ipairs(selected:getAvailableMoves()) do
		local pX, pY = toN(v:sub(1,1)), invert(tonumber(v:sub(2,2)))
		if not self:isSquareEmpty(v) then
			local piece = self:getPiece(v)
			piece.canBeat = false
		end
		if lX == pX and lY == pY then
			log(lX, lY, pX, pY)
			self:movePiece(selected.coords, toL(lX)..invert(lY))
			-- break
		end
	end
	selected.selected = false
	self.selected = nil
	self:onLayout()
end

local function BoardDraw(self)
	for i = 1, self.h do
		term.setCursorPos(self.x, self.y + i - 1)
		term.blit((" "):rep(self.w), ("0"):rep(self.w), ColorBoardBlit(self, i))
	end

	if self.selected then
		for _, v in ipairs(self.selected:getAvailableMoves()) do
			local x, y = toN(v:sub(1,1)), invert(tonumber(v:sub(2,2)))
			term.setCursorPos(x, y)
			term.setBackgroundColor(((x + y) % 2 ~= 0) and self.bc_alt or self.bc)
			term.setTextColor(colors.green)
			term.write("\7")
		end
	end
end

function Chess.Board(args)
	args.w = 8
	args.h = 8
	local instance = UI.Container(args)

	instance.pieces = {}

	instance.draw = BoardDraw
	instance.onMouseDown = BoardOnMouseDown
	instance.setPiece = setPiece
	instance.getPiece = getPiece
	instance.removePiece = removePiece
	instance.movePiece = movePiece
	instance.setDefaultPieces = setDefaultPieces
	instance.isSquareEmpty = isSquareEmpty

	return instance
end

return Chess