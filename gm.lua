function _G.log(...)
	local texts = {...}
	local file = fs.open("log.txt", "a")
	for i, v in ipairs(texts) do
		if type(v) == "table" and type(v) ~= "thread" then
			v = textutils.serialise(v)
		else
			v = tostring(v)
		end
		file.write(v.."; ")
	end
	file.write("\n")
	file.close()
end
term.setGraphicsMode(1)
package.path = package.path .. ";/Data/?;/Data/?.lua"


local UI = require "UI_graphics"
local blittle = require "blittle_extended"
local speaker = require "Speaker"
local inspector = require "inspector"

local userSettings = 'Data/user.json'
local file, user, board

if fs.exists(userSettings) then
	file = fs.open(userSettings, 'r')
	user = file.readAll()
else
	local data = '{"Volume":15,"Nickname":"Unknown","OutputDevice":""}'
	file = fs.open(userSettings, 'w')
	file.write(data)
	user = data
end
file.close()
file = nil
user = textutils.unserialiseJSON(user)

local function saveUserSettings()
	local file = fs.open('Data/user.json', 'w')
	file.write(textutils.serialiseJSON(user))
	file.close()
end

local ret, newOut = speaker.setOutput(user.OutputDevice)
if not ret then
	user.OutputDevice = newOut
	saveUserSettings()
end

local root = UI.Root()
local surface = UI.Box{ x = 0, y = 0, w = root.w, h = root.h, bc = colors.black }
root:addChild(surface)

local CELL_W = 3
local BOARD_W = 26 -- 1 left rank + 8*3 board + 1 right rank
local BOARD_H = 10 -- top files + 8 ranks + bottom files
local BOARD_BG_A = colors.orange
local BOARD_BG_B = colors.brown
local CAPTURE_BG = colors.red
local SEL_BG = colors.green
local BOARD_ORIENTATION = false
local CHESS_MOVE = 'Data/sounds/chess_move'
local CHESS_CAPTURE = 'Data/sounds/chess_capture'
local CHESS_CHECKMATE = 'Data/sounds/chess_checkmate'
local VOLUMES = {}
for i = 0, 14 do
	VOLUMES[i + 1] = i/14*3
end

local files = { "a", "b", "c", "d", "e", "f", "g", "h" }
local fileToX = { a = 1, b = 2, c = 3, d = 4, e = 5, f = 6, g = 7, h = 8 }
local xToFile = { [1] = "a", [2] = "b", [3] = "c", [4] = "d", [5] = "e", [6] = "f", [7] = "g", [8] = "h" }

local pieceGlyph = {
	-- wp = "P", wn = "N", wb = "B", wr = "R", wq = "Q", wk = "K",
	wp = "\105", wn = "\163", wb = "1", wr = "\207", wq = "\5", wk = "\214",
	bp = "\105", bn = "\163", bb = "1", br = "\207", bq = "\5", bk = "\214"
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
	history = {},
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

local updateMessage = function () end

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
	updateMessage()
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
			speaker.playFile(CHESS_CHECKMATE)
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

local function addToHistory(fx, fy, tx, ty)
	local data = xToFile[fx] .. 9 - fy .. '\26' .. xToFile[tx] .. 9 - ty
	local n = #state.history

	if state.turn == 'w' then
		state.history[n + 1] = tostring(n + 1) .. (' '):rep(4 - #(tostring(n + 1))) .. data
	elseif state.turn == 'b' then
		state.history[n] = state.history[n] .. ' ' .. data
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
	addToHistory(state.selected.x, state.selected.y, x, y)
	local capture = false
	if state.board[y][x] then capture = true end
	applyMove(state, chosen, promo)
	state.selected = nil
	state.legalMoves = {}
	state.message = (state.turn == "w" and "White" or "Black") .. " to move."
	if inCheck(state, state.turn) then
		state.message = (state.turn == "w" and "White" or "Black") .. " to move: check."
	end
	if capture then
		speaker.playFile(CHESS_CAPTURE)
	else
		speaker.playFile(CHESS_MOVE)
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
	-- local x = file
	local x = BOARD_ORIENTATION and file or 9 - file
	local y = BOARD_ORIENTATION and rankFromTop or 9 - rankFromTop
	return x, y
end

local moveFromTo = function (from, to) end

local client, server, ws, were, userReady, team, online

local function restartGame()
	state = newGame()
	refreshStatus()
	board.dirty = true
end

local function send(to, message)
	if type(message) == 'table' then
		to.send(textutils.serialiseJSON(message))
	elseif type(message) == 'string' then
		to.send(message)
	end
end

local function settingsMenu()
	local settings = UI.Box{x = 1, y = 1, w = root.w, h = root.h, bc = surface.bc}
	surface:addChild(settings)

	local Settings_Label = UI.Label{x = math.floor((root.w - 8)/2) + 1, y = 2, w = 8, h = 1, text = 'SETTINGS', bc = settings.bc, fc = colors.white}
	settings:addChild(Settings_Label)

	local Sound_Label = UI.Label{x = 6, y = 4, w = 5, h = 1, text = 'Sound', bc = settings.bc, fc = colors.white}
	settings:addChild(Sound_Label)

	local VOutput_Label = UI.Label{x = 6, y = Sound_Label.y + 2, w = 13, h = 1, text = 'Output device', bc = settings.bc, fc = colors.lightGray}
	settings:addChild(VOutput_Label)

	local VOutput_Dropdown = UI.Dropdown{x = VOutput_Label.x + VOutput_Label.w + 1, y = VOutput_Label.y, bc = colors.white, fc = colors.black, array = speaker.getOutputs(), defaultValue = (user.OutputDevice ~= "") and user.OutputDevice or nil}
	settings:addChild(VOutput_Dropdown)
	VOutput_Dropdown.pressed = function (self, element)
		user.OutputDevice = element
		saveUserSettings()
	end

	local Volume_Label = UI.Label{x = 6, y = VOutput_Label.y + 2, w = 6, h = 1, text = 'Volume', bc = settings.bc, fc = colors.lightGray}
	settings:addChild(Volume_Label)

	local Volume_Slider = UI.Slider{x = Volume_Label.x + Volume_Label.w + 8, y = Volume_Label.y, w = 15, bc = settings.bc, fc = colors.white, fc_alt = colors.blue, bc_alt = colors.lightGray, fc_cl = colors.gray, arr = VOLUMES, slidePosition = user.Volume}
	settings:addChild(Volume_Slider)
	Volume_Slider.pressed = function (self)
		user.Volume = self.slidePosition
		saveUserSettings()
		speaker.setVolume(self.arr[self.slidePosition])
	end

	local Interface_Label = UI.Label{x = 6, y = Volume_Label.y + 3, w = 9, h = 1, text = 'Interface', bc = settings.bc, fc = colors.white}
	settings:addChild(Interface_Label)

	local Scheme_Label = UI.Label{x = 6, y = Interface_Label.y + 2, w = 12, h = 1, text = 'Color Scheme', bc = settings.bc, fc = colors.lightGray}
	settings:addChild(Scheme_Label)

	local Piece_Label = UI.Label{x = 6, y = Scheme_Label.y + 2, w = 12, h = 1, text = 'Piece Scheme', bc = settings.bc, fc = colors.lightGray}
	settings:addChild(Piece_Label)

	local BTN_Exit = UI.Button{x = 2, y = 2, w = 3, h = 1, text = '\27', bc = colors.gray, fc = colors.white}
	settings:addChild(BTN_Exit)
	BTN_Exit.pressed = function (self)
		surface:removeChild(settings)
		surface:removeChild(Settings_Label)
		surface:removeChild(Sound_Label)
		surface:removeChild(VOutput_Label)
		surface:removeChild(VOutput_Dropdown)
		surface:removeChild(Volume_Label)
		surface:removeChild(Interface_Label)
		surface:removeChild(Scheme_Label)
		surface:removeChild(Piece_Label)
		surface:removeChild(self)
		surface:onLayout()
	end
	local oldOnResize = surface.onResize
	surface.onResize = function (width, height)
		oldOnResize(width, height)
		settings.w, settings.h = width, height
		Settings_Label.local_x = math.floor((root.w - 8)/2) + 1
	end
end

local function aboutMenu()
	local about = UI.Box{x = 1, y = 1, w = root.w, h = root.h, bc = surface.bc}
	surface:addChild(about)

	local About_Label = UI.Label{x = math.floor((root.w - 8)/2) + 1, y = 2, w = 8, h = 1, text = 'ABOUT', bc = about.bc, fc = colors.white}
	about:addChild(About_Label)

	local BTN_Exit = UI.Button{x = 2, y = 2, w = 3, h = 1, text = '\27', bc = colors.gray, fc = colors.white}
	surface:addChild(BTN_Exit)
	BTN_Exit.pressed = function (self)
		surface:removeChild(about)
		surface:removeChild(About_Label)
		surface:removeChild(self)
		surface:onLayout()
	end
end

local mainMenu = function () end

local function startGame(FEN)
	local opponent, list
	function moveFromTo(from, to)
		local fx = math.floor(from / 10)
		local fy = from % 10

		local tx = math.floor(to / 10)
		local ty = to % 10

		selectSquare(fx, fy)
		moveSelectedTo(tx, ty)
		list:onMouseScroll(math.max(0, #list.array - list.h))
		list.dirty = true
	end
	if ws or client then
		opponent = ws or client
	end
	if type(userReady) == 'boolean' then userReady = nil end
	team = (team == 'White') and 'w' or 'b'
	if team == 'w' then
		BOARD_ORIENTATION = true
	else
		BOARD_ORIENTATION = false
	end
	were = 'InGame'
	surface:removeChild(true)

	board = UI.Box{ x = math.floor((root.w - 16 - BOARD_W)/2) + 1, y = math.floor((root.h - BOARD_H)/2) + 1, w = BOARD_W, h = BOARD_H, bc = colors.black }
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
				if online then send(host, {type = 'chess_move', from = sx * 10 + sy, to = x * 10 + y}) end
				list:onMouseScroll(math.max(0, #list.array - list.h))
				list.dirty = true
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
			local sx, sy = state.selected.x, state.selected.y
			if moveSelectedTo(x, y) then
				local host = ws and ws or client
				if online then send(host, {type = 'chess_move', from = sx * 10 + sy, to = x * 10 + y}) end
				list:onMouseScroll(math.max(0, #list.array - list.h))
				list.dirty = true
				return true
			end
		else
			return true
		end
		return true
	end

	board.draw = function(self)
		local function cellLeft(file)
			return BOARD_ORIENTATION and self.x + 1 + (file - 1) * CELL_W or self.x + 1 + (9 - file - 1) * CELL_W
		end
		local function cellTop(rankFromTop)
			return BOARD_ORIENTATION and self.y + rankFromTop or self.y + (9 - rankFromTop)
		end

		-- background + coordinates
		term.setBackgroundColor(colors.black)
		term.setTextColor(colors.lightGray)

		-- top files
		term.setCursorPos(self.x + 2, self.y)
		for i = 1, 8 do
			term.write(files[not BOARD_ORIENTATION and 9 - i or i] .. "  ")
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
			term.write(files[not BOARD_ORIENTATION and 9 - i or i] .. "  ")
		end
	end

	local panel = UI.Box{x = root.w - 15, y = math.floor((root.h - 9)/2), w = 16, h = 9, bc = colors.gray, fc = colors.white}
	surface:addChild(panel)

	local rev = UI.Button{x = panel.x, y = panel.y + panel.h, w = 3, h = 1, text = '\18', fc = colors.white, bc = colors.gray}
	surface:addChild(rev)
	rev.pressed = function()
		BOARD_ORIENTATION = not BOARD_ORIENTATION
		surface:onLayout()
	end

	local offerdraw = UI.Button{x = rev.x + rev.w, y = rev.y, w = 3, h = 1, bc = colors.lightGray, fc = panel.fc, text = "\189", align = "center"}
	surface:addChild(offerdraw)
	offerdraw.pressed = function (self)
		if not online then
			return
		end
		local host = ws and ws or client
		send(host, {type = 'game_offerdraw', team = (team == "w") and "White" or "Black"})
	end

	local resign = UI.Button{x = offerdraw.x + offerdraw.w, y = offerdraw.y, w = 10, h = 1, bc = colors.gray, fc = panel.fc, text = online and "Resign" or 'Restart', align = "center"}
	surface:addChild(resign)
	resign.pressed = function (self)
		if state.over then return end
		if not online then
			restartGame()
			state.history = {}
			list:updateArr(state.history)
			return
		end
		local host = ws and ws or client
		send(host, {type = 'game_resign'})
		state.message = (team == 'w') and 'Black wins by resignation' or 'White wins by resignation'
		state.over = true
		updateMessage()
	end

	local player1 = UI.Label{x = 1, y = 1, w = panel.w, h = 1, bc = panel.bc, fc = panel.fc, text = "\4 "..user.Nickname, align = "left"}
	panel:addChild(player1)

	local player2 = UI.Label{x = 1, y = panel.h, w = panel.w, h = 1, bc = panel.bc, fc = panel.fc, text = opponent and "\4 "..opponent.nickname or "\4 Unknown", align = "left"}
	panel:addChild(player2)

	list = UI.List{x = 1, y = 2, w = panel.w, h = panel.h - 2, bc = colors.gray, fc = colors.lightGray, array = state.history}
	panel:addChild(list)

	list.onMouseDown = function(self, btn, x, y) end

	local FEN_textfield, FEN_Btn
	if not online then
		FEN_textfield = UI.Textfield{x = 2, y = surface.h - 1, w = surface.w - 6, h = 1, hint = "Type FEN", fc = colors.white, bc = colors.gray}
		surface:addChild(FEN_textfield)

		FEN_Btn = UI.Button{x = root.w - 3, y = FEN_textfield.y, w = 3, h = 1, text = ">", fc = colors.white, bc = colors.gray}
		surface:addChild(FEN_Btn)
		FEN_Btn.pressed = function (self, btn, x, y)
			if FEN_textfield.text then
				local ret, err = loadFEN(FEN_textfield.text)
				-- if not ret then state.message = err updateMessage() log(err) end
				surface:onLayout()
			end
		end
	end


	local BTN_Exit = UI.Button{x = 2, y = 2, w = 3, h = 1, text = '\27', bc = colors.gray, fc = colors.white}
	surface:addChild(BTN_Exit)
	BTN_Exit.pressed = function (self)
		mainMenu()
	end

	local BTN_Settings = UI.Button{x = BTN_Exit.x + BTN_Exit.w + 1, y = BTN_Exit.y, w = 3, h = 1, text = '\164', bc = colors.gray, fc = colors.white}
	surface:addChild(BTN_Settings)
	BTN_Settings.pressed = function (self)
		settingsMenu()
	end

	local msgLabel = UI.Label{x = 1, y = 3, w = root.w, h = 1, fc = colors.lightGray, bc = surface.bc}
	surface:addChild(msgLabel)

	updateMessage = function ()
		msgLabel:setText(state.message)
	end

	surface.onResize = function(width, height)
		surface.w, surface.h = width, height
		board.local_y = math.floor((height - BOARD_H) / 2) + 1
		board.local_x = math.floor((width - 16 - BOARD_W)/2) + 1
		panel.local_x = width - 15
		panel.local_y = math.floor((height - 9)/2)
		if not online then
			FEN_textfield.local_y, FEN_textfield.w = height - 1, width - 6
			FEN_Btn.local_x, FEN_Btn.local_y = width - 3, height - 1
		end
		rev.local_x, rev.local_y = panel.local_x, panel.local_y + panel.h
		offerdraw.local_x, offerdraw.local_y = rev.local_x + rev.w, rev.local_y
		resign.local_x, resign.local_y = offerdraw.local_x + offerdraw.w, offerdraw.local_y
		msgLabel.w = width
	end

	surface:onLayout()
	updateGameEnd()
	restartGame()
	list:updateArr(state.history)
	if FEN ~= '' then
		loadFEN(FEN)
	end
end

local function toArr(json)
	return textutils.unserialiseJSON(json)
end

local function Lobby()
	local host = ws and ws or client
	userReady = false
	online = true
	were = 'Lobby'
	team = 'White'
	surface:removeChild(true)

	local BTN_Exit = UI.Button{x = 2, y = 2, w = 3, h = 1, bc = colors.gray, fc = colors.white, text = '\27'}
	surface:addChild(BTN_Exit)
	BTN_Exit.pressed = function (self)
		if server then
			if client then
				client.close()
			end
			server.close()
			server = nil
		elseif ws then
			ws.close()
			ws = nil
		end
		mainMenu()
	end

	local BTN_Settings = UI.Button{x = root.w - 3, y = BTN_Exit.y, w = 3, h = 1, text = '\164', bc = colors.gray, fc = colors.white}
	surface:addChild(BTN_Settings)
	BTN_Settings.pressed = function (self)
		settingsMenu()
	end

	local Lobby_Label = UI.Label{x = 2 + 4, y = 2, w = 5, h = 1, bc = surface.bc, fc = colors.white, text = 'Lobby'}
	surface:addChild(Lobby_Label)

	local player1 = UI.Label{x = 8, y = math.floor((root.h - 1)/2) + 1, w = 20, h = 1, text = user.Nickname, bc = colors.gray, fc = colors.white, align = "left"}
	surface:addChild(player1)

	local Label_Team = UI.Label{x = 6, y = player1.y, w = 2, h = 1, text = '\7', bc = player1.bc, fc = colors.white, align = 'left'}
	surface:addChild(Label_Team)
	
	local Radio_Team = UI.RadioButton{x = root.w - 7, y = player1.y, bc = surface.bc, fc = colors.white, text = {'White', 'Black'}}
	surface:addChild(Radio_Team)
	local oldMouseUp = Radio_Team.onMouseUp
	Radio_Team.onMouseUp = function (self, btn, x, y)
		if userReady then return true end
		return oldMouseUp(self, btn, x, y)
	end
	
	local BTN_Ready = UI.Button{x = root.w - 9, y = root.h - 2, w = 9, h = 1, bc = colors.gray, fc = colors.white, text = "Ready"}
	surface:addChild(BTN_Ready)
	
	local BTN_Play, Label_Fen, TF_Fen

	if server then
		BTN_Play = UI.Button{x = BTN_Ready.x - 4, y = BTN_Ready.y, w = 3, h = 1, bc = colors.gray, fc = colors.white, text = "\16"}
		surface:addChild(BTN_Play)
		BTN_Play.pressed = function (self)
			if not client then return end
			if not userReady then return end
			if not client.ready then return end
			if client.team == team then return end
			send(client, {type = 'start_game', fen = TF_Fen.text})
			startGame(TF_Fen.text)
		end
		Label_Fen = UI.Label{x = root.w - 20, y = 4, w = 4, h = 1, text = 'FEN:', bc = surface.bc, fc = colors.white, align = 'left'}
		surface:addChild(Label_Fen)
	
		TF_Fen = UI.Textfield{x = Label_Fen.x + Label_Fen.w + 1, y = 4, w = 15, h = 1, bc = colors.gray, fc = colors.white, hint = 'FEN'}
		surface:addChild(TF_Fen)
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
		
		if host then send(host, {type = 'lobby_update', ready = userReady, team = team, nickname = user.Nickname}) end
	end

	surface.onResize = function (width, height)
		surface.w, surface.h = width, height
		Label_Team.local_x = 6
		player1.local_x = 8
		Radio_Team.local_x = width - 7
		-- Radio_Team.local_y = player1.local_y
		BTN_Ready.local_x = width - 9
		BTN_Ready.local_y = height - 2
		BTN_Settings.local_x, BTN_Settings.local_y = width - 3,BTN_Exit.local_y
		if BTN_Play then
			Label_Fen.local_x = width - 20
			TF_Fen.local_x = Label_Fen.local_x + Label_Fen.w + 1
			BTN_Play.local_x = BTN_Ready.local_x - 4
			BTN_Play.local_y = BTN_Ready.local_y
		end
	end
	-- if host then
		

	surface:onLayout()
end

local function JoinMenu()
	were = 'JoinMenu'
	surface:removeChild(true)

	local BTN_Exit = UI.Button{x = 2, y = 2, w = 3, h = 1, bc = colors.gray, fc = colors.white, text = '\27'}
	surface:addChild(BTN_Exit)

	BTN_Exit.pressed = function (self)
		mainMenu()
	end

	local IP_Label = UI.Label{x = math.floor((root.w - 26)/2) + 1, y = math.floor((root.h - 2)/2) + 1, h = 1, w = 10, text = 'IP Adress:', bc = surface.bc, fc = colors.white}
	surface:addChild(IP_Label)

	local Error_Label = UI.Label{x = 1, y = IP_Label.y - 2, h = 1, w = root.w, text = '', bc = surface.bc, fc = colors.white}
	surface:addChild(Error_Label)

	local IP_TextField = UI.Textfield{x = IP_Label.x + IP_Label.w + 1, y = IP_Label.y, w = 16, h = 1, hint = "Type server ip", bc = colors.gray, fc = colors.white}
	IP_TextField.text = '192.168.191.153'
	surface:addChild(IP_TextField)

	local BTN_Connect = UI.Button{x = math.floor((root.w - 7)/2) + 1, y = IP_Label.y + 2, w = 9, h = 1, bc = colors.gray, fc = colors.white, text = 'Connect'}
	surface:addChild(BTN_Connect)

	BTN_Connect.pressed = function (self)
		local err
		ws, err = http.websocket("ws://"..IP_TextField.text..":22856")
		if ws then
			send(ws, {type = 'lobby_join', nickname = user.Nickname, ready = false, team = 'White'})
			Lobby()
		else
			Error_Label.fc = colors.red
			Error_Label:setText(err)
		end
	end

	surface.onResize = function(width, height)
		surface.w, surface.h = width, height
		IP_Label.local_x, IP_Label.local_y = math.floor((width - 26)/2) + 1, math.floor((height - 2)/2) + 1
		IP_TextField.local_x, IP_TextField.local_y = IP_Label.local_x + IP_Label.w + 1, IP_Label.local_y
		BTN_Connect.local_x, BTN_Connect.local_y = math.floor((root.w - 7)/2) + 1, IP_Label.local_y + 2
	end

	surface:onLayout()
end

function mainMenu()
	were = 'MainMenu'
	if type(team) == 'string' then team = nil end
	if type(online) == 'boolean' then online = nil end
	if type(userReady) == 'boolean' then userReady = nil end
	surface:removeChild(true)

	local logo_img = blittle.load("Data/logo.ico")

	local logo = UI.Box{x = math.floor((root.w - 75)/2) + 1, y = 5, w = 75, h = 75, bc = colors.blue}
	surface:addChild(logo)

	-- logo.draw = function (self)
	-- 	-- blittle.draw(logo_img, self.x, self.y)
	-- 	term.drawPixels(self.x)
	-- end

	local Nickname_L = UI.Label{x = 0, y = 0, w = 50, h = 15, bc = surface.bc, fc = colors.white, text = "Nickname: "}
	surface:addChild(Nickname_L)

	local Nickname = UI.Textfield{x = Nickname_L.x + Nickname_L.w, y = 1, w = 10, h = 1, bc = colors.gray, fc = colors.white}
	Nickname.text = user.Nickname
	local oldCharType = Nickname.onCharTyped
	Nickname.onCharTyped = function (self, char)
		local ret = oldCharType(self, char)
		user.Nickname = self.text
		saveUserSettings()
		return ret
	end
	surface:addChild(Nickname)

	local center = math.floor((root.w - 75)/2)+1
	local BTN_Create = UI.Button{x = center, y = logo.y + logo.h + 5, w = 40, h = 10, bc = colors.gray, fc = colors.white, bc_hv = colors.lightGray, fc_hv = colors.black, text = "Create"}
	surface:addChild(BTN_Create)
	BTN_Create.pressed = function ()
		server = http.websocketServer(22856)
		Lobby()
	end

	local BTN_Join = UI.Button{x = center + 40 + 5, y = logo.y + logo.h + 5, w = 30, h = 10, bc = colors.gray, fc = colors.white, bc_hv = colors.lightGray, fc_hv = colors.black, text = "Join", bc_hc = colors.lightGray, fc_hc = colors.black}
	surface:addChild(BTN_Join)
	BTN_Join.pressed = function ()
		JoinMenu()
	end

	local BTN_LocalGame = UI.Button{x = center, y = BTN_Join.y + BTN_Join.h + 5, w = 75, h = 10, bc = colors.gray, fc = colors.white, bc_hv = colors.lightGray, fc_hv = colors.black, text = "Local Game", bc_hc = colors.lightGray, fc_hc = colors.black}
	surface:addChild(BTN_LocalGame)
	BTN_LocalGame.pressed = function (self)
		startGame()
	end

	local BTN_Settings = UI.Button{x = center, y = BTN_LocalGame.y + BTN_LocalGame.h + 5, w = 75, h = 10, bc = colors.gray, fc = colors.white, bc_hv = colors.lightGray, fc_hv = colors.black, text = "Settings", bc_hc = colors.lightGray, fc_hc = colors.black}
	surface:addChild(BTN_Settings)
	BTN_Settings.pressed = function (self)
		settingsMenu()
	end

	local BTN_Quit = UI.Button{x = center, y = BTN_Settings.y + BTN_Settings.h + 5, w = 75, h = 10, bc = colors.gray, fc = colors.white, bc_hv = colors.lightGray, fc_hv = colors.black, text = "Quit", bc_hc = colors.lightGray, fc_hc = colors.black}
	surface:addChild(BTN_Quit)
	BTN_Quit.pressed = function (self)
		os.queueEvent('terminate')
	end

	local Version_Label = UI.Label{x = 0, y = root.h - 6, w = root.w, h = 6, bc = surface.bc, fc = colors.gray, text = "Ver. 26W05.7", align = "left"}
	surface:addChild(Version_Label)

	local BTN_About = UI.Button{x = root.w - 15, y = 5, w = 10, h = 10, radius = 5, bc = colors.gray, fc = colors.white, text = "?"}
	surface:addChild(BTN_About)
	BTN_About.pressed = function (self)
		aboutMenu()
	end

	surface.onResize = function(width, height)
		surface.w, surface.h = width, height
		local cenetr = math.floor((width - 14)/2) + 1
		logo.local_x = math.floor((width - 6)/2) + 1
		BTN_Create.local_x = cenetr
		BTN_Join.local_x = cenetr + 9
		BTN_Quit.local_x = cenetr
		BTN_LocalGame.local_x, BTN_LocalGame.local_y = cenetr, logo.local_y + logo.h + 3
		BTN_Settings.local_x, BTN_Settings.local_y = cenetr, BTN_LocalGame.local_y + 2
		Version_Label.local_y, Version_Label.w = height, width
		BTN_About.local_x = width - 3
	end

	surface:onLayout()
end

function root.custom_handlers.websocket_server_connect(port, arr)
	client = arr

	return true
end
function root.custom_handlers.websocket_server_message(userdata, string, bool)
	local recieve = toArr(string)
	local Type = recieve.type

	if Type == 'lobby_join' and were == 'Lobby' then
		if not client.player then
			local bc = recieve.ready and colors.green or colors.gray
			client.player = UI.Label{x = 8, y = math.floor((root.h - 1)/2) + 3, w = 20, h = 1, text = recieve.nickname, bc = bc, fc = colors.white, align = "left"}
			surface:addChild(client.player)
			client.label_team = UI.Label{x = 6, y = client.player.y, w = 2, h = 1, text = '\7', bc = client.player.bc, fc = colors.white, align = 'left'}
			surface:addChild(client.label_team)
			surface:onLayout()
		end
		send(client, {type = 'lobby_update', nickname = user.Nickname, ready = userReady, team = team})
	elseif Type == 'lobby_update' and were == 'Lobby' then
		if recieve.team == 'White' then
			client.label_team.fc = colors.white
		elseif recieve.team == 'Black' then
			client.label_team.fc = colors.black
		end
		if recieve.ready then
			client.player.bc = colors.green
			client.label_team.bc = colors.green
		else
			client.player.bc = colors.gray
			client.label_team.bc = colors.gray
		end
		client.team = recieve.team
		client.ready = recieve.ready
		client.nickname = recieve.nickname
		client.player.dirty = true
		client.label_team.dirty = true
	elseif Type == 'chess_move' then
		moveFromTo(recieve.from, recieve.to)
	elseif Type == 'game_resign' then
		state.message = (client.team == 'White') and 'Black wins by resignation' or 'White wins by resignation'
		state.over = true
		updateMessage()
	elseif Type == 'game_offerdraw' then
		if recieve.message then
			state.message = 'Draw.'
			state.over = true
			updateMessage()
			return
		end
		local msgLabel, Yes, No
		msgLabel = UI.Label{x = math.floor((root.w - 25)/2) + 1, y = root.h - 1, w = 17, h = 1, text = recieve.team .. ' offers draw', bc = surface.bc, fc = colors.white}
		surface:addChild(msgLabel)
		Yes = UI.Button{x = msgLabel.x + msgLabel.w + 1, y = root.h - 1, w = 3, h = 1, text = 'Y', bc = colors.green, fc = colors.white}
		surface:addChild(Yes)
		Yes.pressed = function (self)
			surface:removeChild(msgLabel)
			surface:removeChild(No)
			surface:removeChild(self)
			surface:onLayout()
			state.message = 'Draw.'
			state.over = true
			updateMessage()
			send(ws, {type = 'game_offerdraw', message = 'Yes', team = (team == 'w') and 'White' or 'Black'})
		end
		No = UI.Button{x = Yes.x + Yes.w + 1, y = root.h - 1, w = 3, h = 1, text = 'N', bc = colors.red, fc = colors.white}
		surface:addChild(No)
		No.pressed = function (self)
			surface:removeChild(msgLabel)
			surface:removeChild(Yes)
			surface:removeChild(self)
			surface:onLayout()
		end
	end

	return true
end
function root.custom_handlers.websocket_server_closed()
	surface:removeChild(client.player)
	surface:removeChild(client.label_team)
	surface:onLayout()
	client = nil
	if were == 'InGame' then mainMenu() end
	return true
end
function root.custom_handlers.websocket_message(ip, message, bool)
	local recieve = toArr(message)
	local Type = recieve.type

	if Type == 'lobby_update' and were == 'Lobby' then
		if not ws.player then
			local bc = recieve.ready and colors.green or colors.gray
			ws.player = UI.Label{x = 8, y = math.floor((root.h - 1)/2) + 3, w = 20, h = 1, text = recieve.nickname, bc = bc, fc = colors.white, align = "left"}
			surface:addChild(ws.player)
			ws.label_team = UI.Label{x = 6, y = ws.player.y, w = 2, h = 1, text = '\7', bc = ws.player.bc, fc = colors.white, align = 'left'}
			surface:addChild(ws.label_team)
			surface:onLayout()
		end
		if recieve.team == 'White' then
			ws.label_team.fc = colors.white
		elseif recieve.team == 'Black' then
			ws.label_team.fc = colors.black
		end
		if recieve.ready then
			ws.player.bc = colors.green
			ws.label_team.bc = colors.green
		else
			ws.player.bc = colors.gray
			ws.label_team.bc = colors.gray
		end
		ws.team = recieve.team
		ws.ready = recieve.ready
		ws.nickname = recieve.nickname
		ws.player.dirty = true
		ws.label_team.dirty = true
	elseif Type == 'start_game' then
		startGame(recieve.fen)
	elseif Type == 'chess_move' then
		moveFromTo(recieve.from, recieve.to)
	elseif Type == 'game_resign' then
		state.message = (ws.team == 'White') and 'Black wins by resignation' or 'White wins by resignation'
		state.over = true
		updateMessage()
	elseif Type == 'game_offerdraw' then
		if recieve.message then
			state.message = 'Draw.'
			state.over = true
			updateMessage()
			return
		end
		local msgLabel, Yes, No
		msgLabel = UI.Label{x = math.floor((root.w - 25)/2) + 1, y = root.h - 1, w = 17, h = 1, text = recieve.team .. ' offers draw', bc = surface.bc, fc = colors.white}
		surface:addChild(msgLabel)
		Yes = UI.Button{x = msgLabel.x + msgLabel.w + 1, y = root.h - 1, w = 3, h = 1, text = 'Y', bc = colors.green, fc = colors.white}
		surface:addChild(Yes)
		Yes.pressed = function (self)
			surface:removeChild(msgLabel)
			surface:removeChild(No)
			surface:removeChild(self)
			surface:onLayout()
			state.message = 'Draw.'
			state.over = true
			updateMessage()
			send(ws, {type = 'game_offerdraw', message = 'Yes', team = (team == 'w') and 'White' or 'Black'})
		end
		No = UI.Button{x = Yes.x + Yes.w + 1, y = root.h - 1, w = 3, h = 1, text = 'N', bc = colors.red, fc = colors.white}
		surface:addChild(No)
		No.pressed = function (self)
			surface:removeChild(msgLabel)
			surface:removeChild(Yes)
			surface:removeChild(self)
			surface:onLayout()
		end
	end

	return true
end
function root.custom_handlers.websocket_closed(ip, message, key)
	surface:removeChild(ws.player)
	surface:removeChild(ws.label_team)
	ws = nil
	mainMenu()
	return true
end

mainMenu()
root:mainloop()
