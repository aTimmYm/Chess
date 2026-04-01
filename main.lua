package.path = package.path .. ";/Data/?" .. ";/Data/?.lua"

function _G.log(...)
	local texts = {...}
	local file = fs.open("log.txt", "a")
	for i, v in ipairs(texts) do
		if type(v) == "table" and not type(v) == "thread" then
			v = textutils.serialise(v)
		else
			v = tostring(v)
		end
		file.write(v.."; ")
	end
	file.write("\n")
	file.close()
end

local UI = require "UI"
local blittle = require "blittle_extended"

local userSettings = 'Data/user.json'
local file

if fs.exists(userSettings) then
	file = fs.open(userSettings, 'r')
else
	file = fs.open(userSettings, 'w')
	file.write('{"Nickname":"Unknown"}')
end
local user = file.readAll()
file.close()
file = nil
user = textutils.unserialiseJSON(user)

local function saveUserSettings()
	local file = fs.open('Data/user.json', 'w')
	file.write(textutils.serialiseJSON(user))
	file.close()
end

local root = UI.Root()
local surface = UI.Box{ x = 1, y = 1, w = root.w, h = root.h, bc = colors.black }
root:addChild(surface)

local CELL_W = 3
local BOARD_W = 26 -- 1 left rank + 8*3 board + 1 right rank
local BOARD_H = 10 -- top files + 8 ranks + bottom files
local BOARD_BG_A = colors.orange
local BOARD_BG_B = colors.brown
local CAPTURE_BG = colors.red
local SEL_BG = colors.green

local files = { "a", "b", "c", "d", "e", "f", "g", "h" }
local fileToX = { a = 1, b = 2, c = 3, d = 4, e = 5, f = 6, g = 7, h = 8 }
local xToFile = { [1] = "a", [2] = "b", [3] = "c", [4] = "d", [5] = "e", [6] = "f", [7] = "g", [8] = "h" }

local pieceGlyph = {
	wp = "P", wn = "N", wb = "B", wr = "R", wq = "Q", wk = "K",
	bp = "P", bn = "N", bb = "B", br = "R", bq = "Q", bk = "K",
}

local function opposite(c) return c == "w" and "b" or "w" end
local function pieceColor(p) return p and p:sub(1, 1) or nil end
local function pieceKind(p) return p and p:sub(2, 2) or nil end
local function inBounds(x, y) return x >= 1 and x <= 8 and y >= 1 and y <= 8 end
local function sqName(x, y) return xToFile[x] .. tostring(9 - y) end

local function makeBoard()
	local board = {}
	for y = 1, 8 do
		board[y] = {}
	end
	return board
end

local function newGame()
	local b = makeBoard()
	local function place(x, y, p) b[y][x] = p end

	-- Black
	place(1, 1, "br"); place(2, 1, "bn"); place(3, 1, "bb"); place(4, 1, "bq")
	place(5, 1, "bk"); place(6, 1, "bb"); place(7, 1, "bn"); place(8, 1, "br")
	for x = 1, 8 do
		place(x, 2, "bp")
	end

	-- White
	for x = 1, 8 do
		place(x, 7, "wp")
	end
	place(1, 8, "wr"); place(2, 8, "wn"); place(3, 8, "wb"); place(4, 8, "wq")
	place(5, 8, "wk"); place(6, 8, "wb"); place(7, 8, "wn"); place(8, 8, "wr")

	return {
	board = b,
	turn = "w",
	castling = { wk = true, wq = true, bk = true, bq = true },
	enPassant = nil,
	halfmove = 0,
	fullmove = 1,
	selected = nil,
	legalMoves = {},
	message = "White to move.",
	over = false,
	result = nil,
	}
end

local state = newGame()

local function cloneState(src)
	local dst = {
	board = makeBoard(),
	turn = src.turn,
	castling = {
		wk = src.castling.wk, wq = src.castling.wq,
		bk = src.castling.bk, bq = src.castling.bq,
	},
	enPassant = src.enPassant and { x = src.enPassant.x, y = src.enPassant.y } or nil,
	halfmove = src.halfmove,
	fullmove = src.fullmove,
	selected = nil,
	legalMoves = {},
	message = src.message,
	over = src.over,
	result = src.result,
	}
	for y = 1, 8 do
		for x = 1, 8 do
			dst.board[y][x] = src.board[y][x]
		end
	end
	return dst
end

local function findKing(s, color)
	local target = color .. "k"
	for y = 1, 8 do
		for x = 1, 8 do
			if s.board[y][x] == target then return x, y end
		end
	end
end

local function squareAttacked(s, x, y, byColor)
	local b = s.board

	-- pawns
	if byColor == "w" then
		local py = y + 1
		if py <= 8 then
			if x > 1 and b[py][x - 1] == "wp" then return true end
			if x < 8 and b[py][x + 1] == "wp" then return true end
		end
	else
		local py = y - 1
		if py >= 1 then
			if x > 1 and b[py][x - 1] == "bp" then return true end
			if x < 8 and b[py][x + 1] == "bp" then return true end
		end
	end

	-- knights
	local knightDeltas = {
	{1, 2}, {2, 1}, {2, -1}, {1, -2},
	{-1, -2}, {-2, -1}, {-2, 1}, {-1, 2},
	}
	for _, d in ipairs(knightDeltas) do
		local nx, ny = x + d[1], y + d[2]
		if inBounds(nx, ny) and b[ny][nx] == byColor .. "n" then return true end
	end

	-- king
	for dy = -1, 1 do
		for dx = -1, 1 do
			if not (dx == 0 and dy == 0) then
			local nx, ny = x + dx, y + dy
			if inBounds(nx, ny) and b[ny][nx] == byColor .. "k" then return true end
			end
		end
	end

	-- sliders
	local rays = {
	{1, 0,  true, false}, {-1, 0, true, false}, {0, 1, true, false}, {0, -1, true, false},
	{1, 1,  false, true},  {1, -1, false, true}, {-1, 1, false, true}, {-1, -1, false, true},
	}
	for _, r in ipairs(rays) do
		local dx, dy, rookLike, bishopLike = r[1], r[2], r[3], r[4]
		local nx, ny = x + dx, y + dy
		while inBounds(nx, ny) do
			local p = b[ny][nx]
			if p then
				if pieceColor(p) == byColor then
					local k = pieceKind(p)
					if (rookLike and (k == "r" or k == "q")) or (bishopLike and (k == "b" or k == "q")) then
					return true
					end
				end
				break
			end
			nx = nx + dx
			ny = ny + dy
		end
	end

	return false
end

local function inCheck(s, color)
	local kx, ky = findKing(s, color)
	if not kx then return false end
	return squareAttacked(s, kx, ky, opposite(color))
end

local function pseudoMovesFrom(s, x, y)
	local p = s.board[y][x]
	if not p then return {} end
	local c = pieceColor(p)
	local k = pieceKind(p)
	local moves = {}

	local function add(m) moves[#moves + 1] = m end

	if k == "p" then
	local dir = (c == "w") and -1 or 1
	local startRow = (c == "w") and 7 or 2
	local promoRow = (c == "w") and 1 or 8

	-- forward 1
	local ny = y + dir
	if inBounds(x, ny) and not s.board[ny][x] then
		add({ fx = x, fy = y, tx = x, ty = ny, piece = p, captured = nil, promo = (ny == promoRow) })
		-- forward 2
		local ny2 = y + 2 * dir
		if y == startRow and inBounds(x, ny2) and not s.board[ny2][x] then
			add({ fx = x, fy = y, tx = x, ty = ny2, piece = p, captured = nil, pawnDouble = true })
		end
	end

	-- captures / en passant
	for _, dx in ipairs({ -1, 1 }) do
		local nx, nyc = x + dx, y + dir
		if inBounds(nx, nyc) then
			local target = s.board[nyc][nx]
			if target and pieceColor(target) ~= c then
				add({ fx = x, fy = y, tx = nx, ty = nyc, piece = p, captured = target, promo = (nyc == promoRow) })
			end
			if s.enPassant and s.enPassant.x == nx and s.enPassant.y == nyc then
				add({ fx = x, fy = y, tx = nx, ty = nyc, piece = p, captured = opposite(c) .. "p", enPassant = true })
			end
		end
	end

	elseif k == "n" then
	local deltas = {
		{1, 2}, {2, 1}, {2, -1}, {1, -2},
		{-1, -2}, {-2, -1}, {-2, 1}, {-1, 2},
	}
	for _, d in ipairs(deltas) do
		local nx, ny = x + d[1], y + d[2]
		if inBounds(nx, ny) then
			local target = s.board[ny][nx]
			if not target or pieceColor(target) ~= c then
				add({ fx = x, fy = y, tx = nx, ty = ny, piece = p, captured = target })
			end
		end
	end

	elseif k == "b" or k == "r" or k == "q" then
		local dirs = {}
		if k == "b" or k == "q" then
			dirs[#dirs + 1] = { 1, 1 }
			dirs[#dirs + 1] = { 1, -1 }
			dirs[#dirs + 1] = { -1, 1 }
			dirs[#dirs + 1] = { -1, -1 }
		end
		if k == "r" or k == "q" then
			dirs[#dirs + 1] = { 1, 0 }
			dirs[#dirs + 1] = { -1, 0 }
			dirs[#dirs + 1] = { 0, 1 }
			dirs[#dirs + 1] = { 0, -1 }
		end

		for _, d in ipairs(dirs) do
			local nx, ny = x + d[1], y + d[2]
			while inBounds(nx, ny) do
			local target = s.board[ny][nx]
			if not target then
				add({ fx = x, fy = y, tx = nx, ty = ny, piece = p, captured = nil })
			else
				if pieceColor(target) ~= c then
					add({ fx = x, fy = y, tx = nx, ty = ny, piece = p, captured = target })
				end
				break
			end
			nx = nx + d[1]
			ny = ny + d[2]
			end
		end

	elseif k == "k" then
		for dy = -1, 1 do
			for dx = -1, 1 do
				if not (dx == 0 and dy == 0) then
					local nx, ny = x + dx, y + dy
					if inBounds(nx, ny) then
						local target = s.board[ny][nx]
						if not target or pieceColor(target) ~= c then
							add({ fx = x, fy = y, tx = nx, ty = ny, piece = p, captured = target })
						end
					end
				end
			end
		end

		-- castling
		if c == "w" and x == 5 and y == 8 and not inCheck(s, "w") then
			if s.castling.wk and not s.board[8][6] and not s.board[8][7] and s.board[8][8] == "wr" then
				if not squareAttacked(s, 6, 8, "b") and not squareAttacked(s, 7, 8, "b") then
					add({ fx = 5, fy = 8, tx = 7, ty = 8, piece = p, castle = "K" })
				end
			end
			if s.castling.wq and not s.board[8][4] and not s.board[8][3] and not s.board[8][2] and s.board[8][1] == "wr" then
				if not squareAttacked(s, 4, 8, "b") and not squareAttacked(s, 3, 8, "b") then
					add({ fx = 5, fy = 8, tx = 3, ty = 8, piece = p, castle = "Q" })
				end
			end
		elseif c == "b" and x == 5 and y == 1 and not inCheck(s, "b") then
			if s.castling.bk and not s.board[1][6] and not s.board[1][7] and s.board[1][8] == "br" then
				if not squareAttacked(s, 6, 1, "w") and not squareAttacked(s, 7, 1, "w") then
					add({ fx = 5, fy = 1, tx = 7, ty = 1, piece = p, castle = "K" })
				end
			end
			if s.castling.bq and not s.board[1][4] and not s.board[1][3] and not s.board[1][2] and s.board[1][1] == "br" then
				if not squareAttacked(s, 4, 1, "w") and not squareAttacked(s, 3, 1, "w") then
					add({ fx = 5, fy = 1, tx = 3, ty = 1, piece = p, castle = "Q" })
				end
			end
		end
	end

	return moves
end

local function applyMove(s, m, promoChoice)
	local p = s.board[m.fy][m.fx]
	local c = pieceColor(p)
	local k = pieceKind(p)
	local captured = m.captured

	-- update castling rights
	if k == "k" then
	if c == "w" then s.castling.wk, s.castling.wq = false, false
	else s.castling.bk, s.castling.bq = false, false end
	elseif k == "r" then
	if c == "w" then
		if m.fx == 1 and m.fy == 8 then s.castling.wq = false end
		if m.fx == 8 and m.fy == 8 then s.castling.wk = false end
	else
		if m.fx == 1 and m.fy == 1 then s.castling.bq = false end
		if m.fx == 8 and m.fy == 1 then s.castling.bk = false end
	end
	end
	if captured and pieceKind(captured) == "r" then
	if pieceColor(captured) == "w" then
		if m.tx == 1 and m.ty == 8 then s.castling.wq = false end
		if m.tx == 8 and m.ty == 8 then s.castling.wk = false end
	else
		if m.tx == 1 and m.ty == 1 then s.castling.bq = false end
		if m.tx == 8 and m.ty == 1 then s.castling.bk = false end
	end
	end

	s.board[m.fy][m.fx] = nil

	if m.enPassant then
	local capY = (c == "w") and (m.ty + 1) or (m.ty - 1)
	s.board[capY][m.tx] = nil
	end

	if m.castle == "K" then
	if c == "w" then
		s.board[8][7] = "wk"
		s.board[8][8] = nil
		s.board[8][6] = "wr"
	else
		s.board[1][7] = "bk"
		s.board[1][8] = nil
		s.board[1][6] = "br"
	end
	elseif m.castle == "Q" then
	if c == "w" then
		s.board[8][3] = "wk"
		s.board[8][1] = nil
		s.board[8][4] = "wr"
	else
		s.board[1][3] = "bk"
		s.board[1][1] = nil
		s.board[1][4] = "br"
	end
	else
	local placed = p
	if m.promo then
		local pr = promoChoice or "q"
		if pr ~= "q" and pr ~= "r" and pr ~= "b" and pr ~= "n" then pr = "q" end
		placed = c .. pr
	end
	s.board[m.ty][m.tx] = placed
	end

	s.enPassant = nil
	if k == "p" and m.pawnDouble then
	s.enPassant = { x = m.fx, y = (m.fy + m.ty) / 2 }
	end

	if k == "p" or captured then s.halfmove = 0 else s.halfmove = s.halfmove + 1 end
	if s.turn == "b" then s.fullmove = s.fullmove + 1 end
	s.turn = opposite(s.turn)
end

local function legalMovesFrom(s, x, y)
	local p = s.board[y][x]
	if not p or pieceColor(p) ~= s.turn then return {} end
	local color = pieceColor(p)
	local res = {}
	for _, m in ipairs(pseudoMovesFrom(s, x, y)) do
		local test = cloneState(s)
		applyMove(test, m, "q")
		if not inCheck(test, color) then
			res[#res + 1] = m
		end
	end
	return res
end

local function allLegalMoves(s, color)
	local res = {}
	for y = 1, 8 do
		for x = 1, 8 do
			if s.board[y][x] and pieceColor(s.board[y][x]) == color then
				local pseudo = pseudoMovesFrom(s, x, y)
				for _, m in ipairs(pseudo) do
					local test = cloneState(s)
					test.turn = color
					applyMove(test, m, "q")
					if not inCheck(test, color) then
						res[#res + 1] = m
					end
				end
			end
		end
	end
	return res
end

local function refreshStatus()
	local turnName = (state.turn == "w") and "White" or "Black"
	local sel = state.selected and sqName(state.selected.x, state.selected.y) or "none"
	local txt = {
	"Turn: " .. turnName,
	"Selected: " .. sel,
	"Full move: " .. tostring(state.fullmove),
	"Halfmove clock: " .. tostring(state.halfmove) .. " / 80",
	"",
	"Click a piece, then click a green move or red capture.",
	"Orange / lime board. Green = move. Red = capture.",
	}
	if inCheck(state, state.turn) and not state.over then
		txt[#txt + 1] = turnName .. " is in check."
	end
	if state.message and state.message ~= "" then
		txt[#txt + 1] = state.message
	end
end

local function parseFEN(fen)
	if type(fen) ~= "string" then
		return nil, "FEN must be a string."
	end

	fen = fen:match("^%s*(.-)%s*$") or fen
	local fields = {}
	for field in fen:gmatch("%S+") do
		fields[#fields + 1] = field
	end
	if #fields < 4 then
		return nil, "FEN must have at least 4 fields."
	end

	local placement, side, castling, ep = fields[1], fields[2], fields[3], fields[4]
	local halfmove = tonumber(fields[5] or "0") or 0
	local fullmove = tonumber(fields[6] or "1") or 1

	local rows = {}
	for row in placement:gmatch("[^/]+") do
		rows[#rows + 1] = row
	end
	if #rows ~= 8 then
		return nil, "FEN placement must contain 8 ranks."
	end

	local boardData = makeBoard()
	local validPieces = {
	p = true, r = true, n = true, b = true, q = true, k = true,
	P = true, R = true, N = true, B = true, Q = true, K = true,
	}

	for fenRank = 1, 8 do
	local row = rows[fenRank]
	local x = 1
	for i = 1, #row do
		local ch = row:sub(i, i)
		local gap = tonumber(ch)
		if gap then
			x = x + gap
		elseif validPieces[ch] then
			if x > 8 then
				return nil, "Too many squares in rank " .. tostring(fenRank) .. "."
			end
			local color = ch:match("[PRNBQK]") and "w" or "b"
			boardData[fenRank][x] = color .. ch:lower()
			x = x + 1
		else
			return nil, "Invalid FEN piece character: " .. ch
		end
	end
		if x ~= 9 then
			return nil, "Rank " .. tostring(fenRank) .. " does not sum to 8 squares."
		end
	end

	local castlingState = { wk = false, wq = false, bk = false, bq = false }
	if castling ~= "-" then
		if castling:find("K", 1, true) then castlingState.wk = true end
		if castling:find("Q", 1, true) then castlingState.wq = true end
		if castling:find("k", 1, true) then castlingState.bk = true end
		if castling:find("q", 1, true) then castlingState.bq = true end
	end

	local enPassant = nil
	if ep ~= "-" then
		local fx = fileToX[ep:sub(1, 1)]
		local ry = tonumber(ep:sub(2, 2))
		if not fx or not ry then
			return nil, "Invalid en passant square."
		end
		enPassant = { x = fx, y = 9 - ry }
	end

	local s = newGame()
	s.board = boardData
	s.turn = (side == "b") and "b" or "w"
	s.castling = castlingState
	s.enPassant = enPassant
	s.halfmove = math.max(0, halfmove)
	s.fullmove = math.max(1, fullmove)
	s.selected = nil
	s.legalMoves = {}
	s.awaitingPromotion = false
	s.pendingPromotion = nil
	s.over = false
	s.result = nil
	if inCheck(s, s.turn) then
		s.message = ((s.turn == "w") and "White" or "Black") .. " to move: check."
	else
		s.message = ((s.turn == "w") and "White" or "Black") .. " to move."
	end
	return s
end

local function loadFEN(fen)
	local parsed, err = parseFEN(fen)
	if not parsed then
		return nil, err
	end
	state = parsed
	refreshStatus()
	if board then board.dirty = true end
	return true
end

local function updateGameEnd()
	if state.halfmove >= 80 then
		state.over = true
		state.result = "Draw by the 40-move rule."
		state.message = state.result
		return
	end
	local moves = allLegalMoves(state, state.turn)
	if #moves == 0 then
		state.over = true
		if inCheck(state, state.turn) then
			local winner = opposite(state.turn)
			state.result = ((winner == "w") and "White" or "Black") .. " wins by checkmate."
		else
			state.result = "Stalemate."
		end
		state.message = state.result
	end
end

local function clearSelection()
	state.selected = nil
	state.legalMoves = {}
	board.dirty = true
	refreshStatus()
end

local function selectSquare(x, y)
	log(x, y)
	if state.over then return end
	local p = state.board[y][x]
	if p and pieceColor(p) == state.turn then
		state.selected = { x = x, y = y }
		state.legalMoves = legalMovesFrom(state, x, y)
		board.dirty = true
		refreshStatus()
	else
		clearSelection()
	end
end

local function moveSelectedTo(x, y)
	if not state.selected then return false end
	local chosen
	for _, m in ipairs(state.legalMoves) do
		if m.tx == x and m.ty == y then
			chosen = m
			break
		end
	end
	if not chosen then return false end

	local promo = nil
	if chosen.promo then
		promo = "q"
		-- if the pawn promotion choice is desired later, this is the default.
	end
	applyMove(state, chosen, promo)
	state.selected = nil
	state.legalMoves = {}
	state.message = (state.turn == "w" and "White" or "Black") .. " to move."
	if inCheck(state, state.turn) then
		state.message = (state.turn == "w" and "White" or "Black") .. " to move: check."
	end
	updateGameEnd()
	board.dirty = true
	refreshStatus()
	return true
end

local function squareAtMouse(mx, my)
	local relX = mx - board.x + 1
	local relY = my - board.y + 1
	if relX < 2 or relX > 25 or relY < 2 or relY > 9 then
		return nil
	end
	local file = math.floor((relX - 2) / CELL_W) + 1
	local rankFromTop = relY - 1
	if file < 1 or file > 8 or rankFromTop < 1 or rankFromTop > 8 then
		return nil
	end
	local x = file
	local y = rankFromTop
	return x, y
end

local function moveFromTo(from, to)
	local fx = math.floor(from / 10)
	local fy = from % 10

	local tx = math.floor(to / 10)
	local ty = to % 10

	selectSquare(fx, fy)
	moveSelectedTo(tx, ty)
end

local function restartGame()
	state = newGame()
	refreshStatus()
	board.dirty = true
end

local client, server, ws, were, player2, Radio_Team, Label2_Team, userReady, team, online

local function send(to, message)
	if type(message) == 'table' then
		to.send(textutils.serialiseJSON(message))
	elseif type(message) == 'string' then
		to.send(message)
	end
end

local function startGame()
	if type(userReady) == 'boolean' then userReady = nil end
	if player2 then
		player2 = nil
		Label2_Team = nil
	end
	team = (team == 'White') and 'w' or 'b'
	were = 'InGame'
	surface:removeChild(true)

	board = UI.Box{ x = 1, y = math.floor((root.h - BOARD_H)/2) + 1, w = BOARD_W, h = BOARD_H, bc = colors.black }
	surface:addChild(board)

	board.onMouseDown = function(self, btn, mx, my)
		if online and (state.turn ~= team) then return end
		local x, y = squareAtMouse(mx, my)
		if not x then return true end

		if state.over then return true end

		if state.selected then
			local sx, sy = state.selected.x, state.selected.y
			if moveSelectedTo(x, y) then
				local host = ws and ws or client
				send(host, {type = 'chess_move', from = sx * 10 + sy, to = x * 10 + y})
				return true
			end
			local p = state.board[y][x]
			if p and pieceColor(p) == state.turn then
				selectSquare(x, y)
			else
				clearSelection()
			end
		else
			selectSquare(x, y)
		end
		return true
	end

	board.onMouseUp = function (self, btn, mx, my)
		local x, y = squareAtMouse(mx, my)
		if not x then return true end

		if state.over then return true end
		if state.selected then
			if moveSelectedTo(x, y) then return true end
		else
			return true
		end
		return true
	end


	board.draw = function(self)
		local function cellLeft(file)
			return self.x + 1 + (file - 1) * CELL_W
		end
		local function cellTop(rankFromTop)
			return self.y + rankFromTop
		end

		-- background + coordinates
		term.setBackgroundColor(colors.black)
		term.setTextColor(colors.lightGray)

		-- top files
		term.setCursorPos(self.x + 2, self.y)
		for i = 1, 8 do
			term.write(files[i] .. "  ")
		end

		for rankFromTop = 1, 8 do
			local y = 9 - rankFromTop
			local sy = cellTop(rankFromTop)

			term.setCursorPos(self.x, sy)
			term.write(tostring(y))

			for file = 1, 8 do
				local sx = cellLeft(file)
				local p = state.board[rankFromTop][file]
				local base = ((file + rankFromTop) % 2 == 0) and BOARD_BG_A or BOARD_BG_B
				local bg = base
				local fg = (bg == BOARD_BG_A) and colors.white or colors.black
				local text = "   "

				local isSelected = state.selected and state.selected.x == file and state.selected.y == rankFromTop
				local targetType = nil
				if state.selected then
					for _, m in ipairs(state.legalMoves) do
						if m.tx == file and m.ty == rankFromTop then
						targetType = m.captured and "capture" or "move"
						break
						end
					end
				end

				if targetType == "move" then
					bg = base
					fg = colors.green
					text = " \7 "
				elseif targetType == "capture" then
					bg = CAPTURE_BG
					fg = colors.white
					if p then
						local glyph = pieceGlyph[p] or "?"
						text = " " .. glyph .. " "
					else
						text = " x "
					end
				elseif isSelected then
					bg = SEL_BG
					fg = colors.black
					if p then
						local glyph = pieceGlyph[p] or "?"
						text = " " .. glyph .. " "
					end
				elseif p then
					local glyph = pieceGlyph[p] or "?"
					text = " " .. glyph .. " "
					fg = (pieceColor(p) == "w") and colors.white or colors.black
				end

				term.setBackgroundColor(bg)
				term.setTextColor(fg)
				term.setCursorPos(sx, sy)
				term.write(text)
			end

			term.setBackgroundColor(colors.black)
			term.setTextColor(colors.lightGray)
			term.setCursorPos(self.x + 25, sy)
			term.write(tostring(y))
		end

		-- bottom files
		term.setCursorPos(self.x + 2, self.y + 9)
		for i = 1, 8 do
			term.write(files[i] .. "  ")
		end
	end

	local tablichka = UI.Box{x = root.w - 15, y = math.floor((root.h - 8)/2)+1, w = 16, h = 8, bc = colors.gray, fc = colors.white}
	surface:addChild(tablichka)

	local player1 = UI.Label{x = 1, y = 1, w = tablichka.w, h = 1, bc = tablichka.bc, fc = tablichka.fc, text = "\7".."Unknown", align = "left"}
	tablichka:addChild(player1)
	local player22 = UI.Label{x = 1, y = tablichka.h, w = tablichka.w, h = 1, bc = tablichka.bc, fc = tablichka.fc, text = "\7".."Unknown", align = "left"}
	tablichka:addChild(player22)

	local resign = UI.Button{x = 2, y = tablichka.h - 1, w = tablichka.w/2, h = 1, bc = colors.lightGray, fc = tablichka.fc, text = "Resign", align = "center"}
	tablichka:addChild(resign)

	resign.pressed = function(self)
		-- selectSquare(5, 7)
		-- moveSelectedTo(5, 5)
	end

	local offerdraw = UI.Button{x = 11, y = tablichka.h - 1, w = 3, h = 1, bc = colors.lightGray, fc = tablichka.fc, text = "\189", align = "center"}
	tablichka:addChild(offerdraw)

	surface.onResize = function(width, height)
		surface.w, surface.h = width, height
		board.local_y = math.floor((root.h - BOARD_H) / 2) + 1
		tablichka.local_x = root.w - 15
		tablichka.local_y = math.floor((root.h - 8)/2) + 1
	end
	surface:onLayout()
	updateGameEnd()
end

local function toArr(json)
	return textutils.unserialiseJSON(json)
end

local mainMenu = function () end

local function Lobby()
	userReady = false
	online = true
	were = 'Lobby'
	team = 'White'
	surface:removeChild(true)

	local BTN_Exit = UI.Button{x = 2, y = 2, w = 3, h = 1, bc = colors.gray, fc = colors.white, text = '<'}
	surface:addChild(BTN_Exit)

	BTN_Exit.pressed = function (self)
		if server then
			server.close()
		elseif ws then
			-- send(ws, {type = 'lobby_leave'})
			ws.close()
		end
		mainMenu()
	end

	local Lobby_Label = UI.Label{x = 2 + 4, y = 2, w = 5, h = 1, bc = surface.bc, fc = colors.white, text = 'Lobby'}
	surface:addChild(Lobby_Label)

	local player1 = UI.Label{x = math.floor((root.w - 20)/2) + 1, y = math.floor((root.h - 1)/2) + 1, w = 20, h = 1, text = user.Nickname, bc = colors.gray, fc = colors.white, align = "left"}
	surface:addChild(player1)

	local Label_Team = UI.Label{x = player1.x - 2, y = player1.y, w = 2, h = 1, text = '\7', bc = player1.bc, fc = colors.white, align = 'left'}
	surface:addChild(Label_Team)

	Radio_Team = UI.RadioButton{x = root.w - 7, y = player1.y, bc = surface.bc, fc = colors.white, text = {'White', 'Black'}}
	surface:addChild(Radio_Team)
	local oldMouseUp = Radio_Team.onMouseUp
	Radio_Team.onMouseUp = function (self, btn, x, y)
		if userReady then return end
		return oldMouseUp(self, btn, x, y)
	end

	local BTN_Ready = UI.Button{x = root.w - 9, y = root.h - 2, w = 9, h = 1, bc = colors.gray, fc = colors.white, text = "Ready"}
	surface:addChild(BTN_Ready)

	local BTN_Play

	if server then
		BTN_Play = UI.Button{x = BTN_Ready.x - 4, y = BTN_Ready.y, w = 3, h = 1, bc = colors.gray, fc = colors.white, text = "\16"}
		surface:addChild(BTN_Play)
		BTN_Play.pressed = function (self)
			if not player2 then return end
			if not userReady then return end
			if not player2.ready then return end
			send(client, {type = 'start_game'})
			startGame()
		end
	end

	Radio_Team.pressed = function (self, i)
		if userReady then return end
		if i == 'White' then
			Label_Team.fc = colors.white
		elseif i == 'Black' then
			Label_Team.fc = colors.black
		end
		team = i
		Label_Team.dirty = true
		local host = ws and ws or client
		if host then send(host, {type = 'lobby_update', ready = userReady, team = team, nickname = user.Nickname}) end
	end

	BTN_Ready.pressed = function (self)
		userReady = not userReady
		if userReady then
			self:setText('Unready')
			player1.bc = colors.green
			Label_Team.bc = colors.green
		else
			self:setText('Ready')
			player1.bc = colors.gray
			Label_Team.bc = colors.gray
		end
		player1.dirty = true
		Label_Team.dirty = true
		-- surface:onLayout()
		local host = ws and ws or client
		if host then send(host, {type = 'lobby_update', ready = userReady, team = team, nickname = user.Nickname}) end
	end

	surface.onResize = function (width, height)
		surface.w, surface.h = width, height
		player1.local_x = math.floor((root.w - 20)/2) + 1
		Label_Team.local_x = player1.local_x - 2
		Radio_Team.local_x = root.w - 7
		BTN_Ready.local_x = root.w - 9
		BTN_Ready.local_y = root.h - 2
		if BTN_Play then
			BTN_Play.local_x = BTN_Ready.local_x - 4
			BTN_Play.local_y = BTN_Ready.local_y
		end
	end
	surface:onLayout()
end

local function JoinMenu()
	were = 'JoinMenu'
	surface:removeChild(true)

	local ipserver = UI.Textfield{x = math.floor((root.w - 10)/2) + 1, y = math.floor((root.h - 1)/2) + 1, w = 10, h = 1, hint = "Type server ip", bc = colors.gray, fc = colors.white}
	ipserver.text = '192.168.191.153'
	surface:addChild(ipserver)

	ipserver.pressed = function (self, text)
		ws = http.websocket("ws://"..text..":22856")
		if ws then
			send(ws, {type = 'lobby_join', nickname = user.Nickname, ready = false, team = 'White'})
			Lobby()
		end
	end
	surface:onLayout()
end

function mainMenu()
	were = 'MainMenu'
	if type(team) == 'string' then team = nil end
	if type(online) == 'boolean' then online = nil end
	if type(userReady) == 'boolean' then userReady = nil end
	if player2 then
		player2 = nil
		Label2_Team = nil
	end
	surface:removeChild(true)

	local logo_img = blittle.load("Data/logo.ico")

	local logo = UI.Box{x = math.floor((root.w - 6)/2) + 1, y = 3, w = 6, h = 5, bc = colors.black}
	surface:addChild(logo)

	logo.draw = function (self)
		blittle.draw(logo_img, self.x, self.y)
	end

	local Nickname_L = UI.Label{x = 1, y = 1, w = 10, h = 1, bc = surface.bc, fc = colors.white, text = "Nickname: "}
	surface:addChild(Nickname_L)

	local Nickname = UI.Textfield{x = Nickname_L.x + Nickname_L.w, y = 1, w = 10, h = 1, bc = surface.bc, fc = colors.white}
	Nickname.text = user.Nickname
	local oldKeyDown = Nickname.onKeyDown
	Nickname.onKeyDown = function (self, key, held)
		local ret = oldKeyDown(self, key, held)
		user.Nickname = self.text
		saveUserSettings()
		return ret
	end
	surface:addChild(Nickname)

	local center = math.floor((root.w - 14)/2)+1
	local BTN_Create = UI.Button{x = center, y = logo.y + logo.h + 1, w = 8, h = 1, bc = colors.gray, fc = colors.white, bc_hv = colors.lightGray, fc_hv = colors.black, text = "Create"}
	surface:addChild(BTN_Create)
	BTN_Create.pressed = function ()
		server = http.websocketServer(22856)
		Lobby()
	end

	local BTN_Join = UI.Button{x = center + 9, y = logo.y + logo.h + 1, w = 6, h = 1, bc = colors.gray, fc = colors.white, bc_hv = colors.lightGray, fc_hv = colors.black, text = "Join", bc_hc = colors.lightGray, fc_hc = colors.black}
	surface:addChild(BTN_Join)
	BTN_Join.pressed = function ()
		JoinMenu()
	end

	local BTN_Quit = UI.Button{x = center, y = logo.y + logo.h + 3, w = 15, h = 1, bc = colors.gray, fc = colors.white, bc_hv = colors.lightGray, fc_hv = colors.black, text = "Quit", bc_hc = colors.lightGray, fc_hc = colors.black}
	surface:addChild(BTN_Quit)
	BTN_Quit.pressed = function (self)
		os.queueEvent('terminate')
	end

	surface.onResize = function(width, height)
		surface.w, surface.h = width, height
		local cenetr = math.floor((root.w - 14)/2)+1
		logo.local_x = math.floor((root.w - 6)/2) + 1
		BTN_Create.local_x = cenetr
		BTN_Join.local_x = cenetr + 9
		BTN_Quit.local_x = cenetr
	end
	-- local BTN_Multiplayer = UI.Button{}
	surface:onLayout()
end

function root.custom_handlers.websocket_server_connect(port, arr)
	client = arr

	return true
end
function root.custom_handlers.websocket_server_message(userdata, string, bool)
	local recieve = toArr(string)

	if recieve.type == 'lobby_join' and were == 'Lobby' then
		if not player2 then
			player2 = UI.Label{x = math.floor((root.w - 20)/2) + 1, y = math.floor((root.h - 1)/2) + 3, w = 20, h = 1, text = recieve.nickname, bc = colors.gray, fc = colors.white, align = "left"}
			player2.ready = recieve.ready
			surface:addChild(player2)
			Label2_Team = UI.Label{x = player2.x - 2, y = player2.y, w = 2, h = 1, text = '\7', bc = player2.bc, fc = colors.white, align = 'left'}
			surface:addChild(Label2_Team)
			surface:onLayout()
		end
		send(client, {type = 'lobby_update', nickname = user.Nickname, ready = userReady, team = team})
	elseif recieve.type == 'lobby_update' and were == 'Lobby' then
		if recieve.team == 'White' then
			Label2_Team.fc = colors.white
		elseif recieve.team == 'Black' then
			Label2_Team.fc = colors.black
		end
		if recieve.ready then
			player2.bc = colors.green
			Label2_Team.bc = colors.green
		else
			player2.bc = colors.gray
			Label2_Team.bc = colors.gray
		end
		player2.ready = recieve.ready
		player2.dirty = true
		Label2_Team.dirty = true
	elseif recieve.type == 'chess_move' then
		moveFromTo(recieve.from, recieve.to)
	end

	return true
end
function root.custom_handlers.websocket_server_closed()
	client = nil
	player2 = nil
	Label2_Team = nil
	surface:onLayout()
	return true
end
function root.custom_handlers.websocket_message(ip, message, bool)
	local recieve = toArr(message)

	if recieve.type == 'lobby_update' then
		if not player2 then
			local bc = recieve.ready and colors.green or colors.gray
			player2 = UI.Label{x = math.floor((root.w - 20)/2) + 1, y = math.floor((root.h - 1)/2) + 3, w = 20, h = 1, text = recieve.nickname, bc = bc, fc = colors.white, align = "left"}
			player2.ready = recieve.ready
			surface:addChild(player2)
			Label2_Team = UI.Label{x = player2.x - 2, y = player2.y, w = 2, h = 1, text = '\7', bc = player2.bc, fc = colors.white, align = 'left'}
			surface:addChild(Label2_Team)
			surface:onLayout()
		end
		if recieve.team == 'White' then
			Label2_Team.fc = colors.white
		elseif recieve.team == 'Black' then
			Label2_Team.fc = colors.black
		end
		if recieve.ready then
			player2.bc = colors.green
			Label2_Team.bc = colors.green
		else
			player2.bc = colors.gray
			Label2_Team.bc = colors.gray
		end
		player2.dirty = true
		Label2_Team.dirty = true
	elseif recieve.type == 'start_game' then
		startGame()
	elseif recieve.type == 'chess_move' then
		moveFromTo(recieve.from, recieve.to)
	end

	return true
end
function root.custom_handlers.websocket_closed(ip, message, key)
	mainMenu()

	return true
end

surface.onResize = function(width, height)
	surface.w, surface.h = width, height
end

refreshStatus()
-- startGame()
mainMenu()
root:mainloop()
