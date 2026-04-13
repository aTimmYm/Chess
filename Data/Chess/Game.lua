local _Game = {}

local fileToX = { a = 1, b = 2, c = 3, d = 4, e = 5, f = 6, g = 7, h = 8 }

local function opposite(c) return c == "w" and "b" or "w" end
local function pieceKind(p) return p and p:sub(2, 2) or nil end
local function inBounds(x, y) return x >= 1 and x <= 8 and y >= 1 and y <= 8 end

local function cloneState(src)
	local dst = _Game.Game(_Game.makeBoard())

	dst.turn = src.turn
	dst.castling = {
		wk = src.castling.wk, wq = src.castling.wq,
		bk = src.castling.bk, bq = src.castling.bq,
	}
	dst.enPassant = src.enPassant and { x = src.enPassant.x, y = src.enPassant.y } or nil
	dst.halfmove = src.halfmove
	dst.fullmove = src.fullmove
	dst.legalMoves = {}
	dst.message = src.message
	dst.selected = nil
	dst.over = src.over
	dst.result = src.result

	for y = 1, 8 do
		for x = 1, 8 do
			dst.board[y][x] = src.board[y][x]
		end
	end
	return dst
end

local function findKing(self, color)
	local target = color .. "k"
	for y = 1, 8 do
		for x = 1, 8 do
			if self.board[y][x] == target then return x, y end
		end
	end
end

local function squareAttacked(self, x, y, byColor)
	local b = self.board

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
				if _Game.pieceColor(p) == byColor then
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

local function inCheck(self, color)
	local kx, ky = self:findKing(color)
	if not kx then return false end
	return self:squareAttacked(kx, ky, opposite(color))
end

local function pseudoMovesFrom(self, x, y)
	local p = self.board[y][x]
	if not p then return {} end
	local c = _Game.pieceColor(p)
	local k = pieceKind(p)
	local moves = {}

	local function add(m) moves[#moves + 1] = m end

	if k == "p" then
	local dir = (c == "w") and -1 or 1
	local startRow = (c == "w") and 7 or 2
	local promoRow = (c == "w") and 1 or 8

	-- forward 1
	local ny = y + dir
	if inBounds(x, ny) and not self.board[ny][x] then
		add({ fx = x, fy = y, tx = x, ty = ny, piece = p, captured = nil, promo = (ny == promoRow) })
		-- forward 2
		local ny2 = y + 2 * dir
		if y == startRow and inBounds(x, ny2) and not self.board[ny2][x] then
			add({ fx = x, fy = y, tx = x, ty = ny2, piece = p, captured = nil, pawnDouble = true })
		end
	end

	-- captures / en passant
	for _, dx in ipairs({ -1, 1 }) do
		local nx, nyc = x + dx, y + dir
		if inBounds(nx, nyc) then
			local target = self.board[nyc][nx]
			if target and _Game.pieceColor(target) ~= c then
				add({ fx = x, fy = y, tx = nx, ty = nyc, piece = p, captured = target, promo = (nyc == promoRow) })
			end
			if self.enPassant and self.enPassant.x == nx and self.enPassant.y == nyc then
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
			local target = self.board[ny][nx]
			if not target or _Game.pieceColor(target) ~= c then
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
			local target = self.board[ny][nx]
			if not target then
				add({ fx = x, fy = y, tx = nx, ty = ny, piece = p, captured = nil })
			else
				if _Game.pieceColor(target) ~= c then
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
						local target = self.board[ny][nx]
						if not target or _Game.pieceColor(target) ~= c then
							add({ fx = x, fy = y, tx = nx, ty = ny, piece = p, captured = target })
						end
					end
				end
			end
		end

		-- castling
		if c == "w" and x == 5 and y == 8 and not self:inCheck("w") then
			if self.castling.wk and not self.board[8][6] and not self.board[8][7] and self.board[8][8] == "wr" then
				if not self:squareAttacked(6, 8, "b") and not self:squareAttacked(7, 8, "b") then
					add({ fx = 5, fy = 8, tx = 7, ty = 8, piece = p, castle = "K" })
				end
			end
			if self.castling.wq and not self.board[8][4] and not self.board[8][3] and not self.board[8][2] and self.board[8][1] == "wr" then
				if not self:squareAttacked(4, 8, "b") and not self:squareAttacked(3, 8, "b") then
					add({ fx = 5, fy = 8, tx = 3, ty = 8, piece = p, castle = "Q" })
				end
			end
		elseif c == "b" and x == 5 and y == 1 and not self:inCheck("b") then
			if self.castling.bk and not self.board[1][6] and not self.board[1][7] and self.board[1][8] == "br" then
				if not self:squareAttacked(6, 1, "w") and not self:squareAttacked(7, 1, "w") then
					add({ fx = 5, fy = 1, tx = 7, ty = 1, piece = p, castle = "K" })
				end
			end
			if self.castling.bq and not self.board[1][4] and not self.board[1][3] and not self.board[1][2] and self.board[1][1] == "br" then
				if not self:squareAttacked(4, 1, "w") and not self:squareAttacked(3, 1, "w") then
					add({ fx = 5, fy = 1, tx = 3, ty = 1, piece = p, castle = "Q" })
				end
			end
		end
	end

	return moves
end

local function applyMove(self, m, promoChoice)
	local p = self.board[m.fy][m.fx]
	local c = _Game.pieceColor(p)
	local k = pieceKind(p)
	local captured = m.captured
	local isCapture = false
	if captured then isCapture = true end
	-- update castling rights
	if k == "k" then
	if c == "w" then self.castling.wk, self.castling.wq = false, false
	else self.castling.bk, self.castling.bq = false, false end
	elseif k == "r" then
	if c == "w" then
		if m.fx == 1 and m.fy == 8 then self.castling.wq = false end
		if m.fx == 8 and m.fy == 8 then self.castling.wk = false end
	else
		if m.fx == 1 and m.fy == 1 then self.castling.bq = false end
		if m.fx == 8 and m.fy == 1 then self.castling.bk = false end
	end
	end
	if captured and pieceKind(captured) == "r" then
		if _Game.pieceColor(captured) == "w" then
			if m.tx == 1 and m.ty == 8 then self.castling.wq = false end
			if m.tx == 8 and m.ty == 8 then self.castling.wk = false end
		else
			if m.tx == 1 and m.ty == 1 then self.castling.bq = false end
			if m.tx == 8 and m.ty == 1 then self.castling.bk = false end
		end
	end

	self.board[m.fy][m.fx] = nil

	if m.enPassant then
		isCapture = true
		local capY = (c == "w") and (m.ty + 1) or (m.ty - 1)
		self.board[capY][m.tx] = nil
	end

	if m.castle == "K" then
	if c == "w" then
		self.board[8][7] = "wk"
		self.board[8][8] = nil
		self.board[8][6] = "wr"
	else
		self.board[1][7] = "bk"
		self.board[1][8] = nil
		self.board[1][6] = "br"
	end
	elseif m.castle == "Q" then
	if c == "w" then
		self.board[8][3] = "wk"
		self.board[8][1] = nil
		self.board[8][4] = "wr"
	else
		self.board[1][3] = "bk"
		self.board[1][1] = nil
		self.board[1][4] = "br"
	end
	else
	local placed = p
	if m.promo then
		local pr = promoChoice or "q"
		if pr ~= "q" and pr ~= "r" and pr ~= "b" and pr ~= "n" then pr = "q" end
		placed = c .. pr
	end
	self.board[m.ty][m.tx] = placed
	end

	self.enPassant = nil
	if k == "p" and m.pawnDouble then
	self.enPassant = { x = m.fx, y = (m.fy + m.ty) / 2 }
	end

	if k == "p" or captured then self.halfmove = 0 else self.halfmove = self.halfmove + 1 end
	if self.turn == "b" then self.fullmove = self.fullmove + 1 end
	self.turn = opposite(self.turn)
	return isCapture
end

local function legalMovesFrom(self, x, y)
	local p = self.board[y][x]
	if not p or _Game.pieceColor(p) ~= self.turn then return {} end
	local color = _Game.pieceColor(p)
	local res = {}
	for _, m in ipairs(self:pseudoMovesFrom(x, y)) do
		local test = cloneState(self)
		test:applyMove(m, "q")
		if not test:inCheck(color) then
			res[#res + 1] = m
		end
	end
	return res
end

local function allLegalMoves(self, color)
	local res = {}
	for y = 1, 8 do
		for x = 1, 8 do
			if self.board[y][x] and _Game.pieceColor(self.board[y][x]) == color then
				local pseudo = self:pseudoMovesFrom(x, y)
				for _, m in ipairs(pseudo) do
					local test = cloneState(self)
					test.turn = color
					test:applyMove(m, "q")
					if not test:inCheck(color) then
						res[#res + 1] = m
					end
				end
			end
		end
	end
	return res
end

local function setDefaultPieces(self)
	local function place(x, y, p) self.board[y][x] = p end

	-- Чорні
	place(1, 1, "br"); place(2, 1, "bn"); place(3, 1, "bb"); place(4, 1, "bq")
	place(5, 1, "bk"); place(6, 1, "bb"); place(7, 1, "bn"); place(8, 1, "br")
	for x = 1, 8 do place(x, 2, "bp") end

	-- Білі
	for x = 1, 8 do place(x, 7, "wp") end
	place(1, 8, "wr"); place(2, 8, "wn"); place(3, 8, "wb"); place(4, 8, "wq")
	place(5, 8, "wk"); place(6, 8, "wb"); place(7, 8, "wn"); place(8, 8, "wr")
end

local function updateGameEnd(self)
	if self.halfmove >= 80 then
		self.result = "Draw by the 40-move rule."
		self:gameOver(self.result)
		return
	end
	local moves = self:allLegalMoves(self.turn)
	if #moves == 0 then
		if self:inCheck(self.turn) then
			local winner = opposite(self.turn)
			self.result = ((winner == "w") and "White" or "Black") .. " wins by checkmate."
			self:playSound('checkmate')
		else
			self.result = "Stalemate."
		end
		self:gameOver(self.result)
	end
end

local function addToHistory(self, san, movingTeam)
	local n = #self.history
	local CONST_SAN_W = 6 -- max notation Width
	local CONST_NSS_W = 3 -- num + dot + spaces Width
	if movingTeam == 'w' then
		local moveNumber = n + 1
		-- self.history[n + 1] = tostring(moveNumber) .. ". " .. san
		local n_str = tostring(moveNumber)
		self.history[n + 1] = n_str .. (' '):rep(CONST_NSS_W - #n_str) .. san
	elseif movingTeam == 'b' then
		local currentText = self.history[n] or ""
		-- self.history[n] = currentText .. "   " .. san
		self.history[n] = currentText .. (' '):rep((CONST_SAN_W+CONST_NSS_W) - #currentText) .. san
	end
end

local function getSAN(self, move, promoChoice)
	-- 1. Рокіровка
	if move.castle == "K" then return "O-O" end
	if move.castle == "Q" then return "O-O-O" end

	local pieceType = pieceKind(move.piece)
	local isCapture = move.captured ~= nil or move.enPassant
	local san = ""

	if pieceType == "p" then
		-- Для пішака фіксуємо літеру вертикалі при взятті
		if isCapture then
			san = _Game.xToFile[move.fx] .. "x"
		end
	else
		-- Для інших фігур велика літера (N, B, R, Q, K)
		san = pieceType:upper()

		-- Уникнення двозначності (Disambiguation)
		local ambigFile, ambigRank = false, false
		local color = _Game.pieceColor(move.piece)

		for _, otherMove in ipairs(self:allLegalMoves(color)) do
			if (otherMove.fx ~= move.fx or otherMove.fy ~= move.fy)
			   and pieceKind(otherMove.piece) == pieceType
			   and otherMove.tx == move.tx and otherMove.ty == move.ty then
				-- Інша фігура того ж типу може піти сюди ж
				if otherMove.fx == move.fx then
					ambigRank = true -- На одній вертикалі, вказуємо горизонталь
				else
					ambigFile = true -- На різних вертикалях, вказуємо вертикаль
				end
			end
		end

		if ambigFile then
			san = san .. _Game.xToFile[move.fx]
		elseif ambigRank then
			san = san .. (9 - move.fy)
		end

		if isCapture then san = san .. "x" end
	end

	-- Додаємо цільову клітинку
	san = san .. _Game.xToFile[move.tx] .. (9 - move.ty)

	-- Додаємо перетворення пішака
	if move.promo then
		san = san .. "=" .. string.upper(promoChoice or "q")
	end

	return san
end

local function moveSelectedTo(self, x, y, selected)
	if not selected then return false end
	local chosen
	for _, m in ipairs(self.legalMoves) do
		if m.tx == x and m.ty == y then
			chosen = m
			break
		end
	end
	if not chosen then return false end

	local promo = chosen.promo and "q" or nil
	local movingTeam = self.turn

	-- 1. Генеруємо базовий SAN до зміни стану дошки
	local san = self:getSAN(chosen, promo)

	-- 2. Застосовуємо хід
	local status = 'move'
	if self:applyMove(chosen, promo) then status = 'capture' end

	-- 3. Перевіряємо шах/мат (вже для наступного гравця)
	self.legalMoves = {}
	local movesLeft = #self:allLegalMoves(self.turn)
	local isCheckNow = self:inCheck(self.turn)

	if movesLeft == 0 and isCheckNow then
		san = san .. "#"
	elseif isCheckNow then
		san = san .. "+"
	end

	-- 4. Записуємо чистий SAN в історію
	self:addToHistory(san, movingTeam)

	-- Оновлюємо статус гри
	self.message = (self.turn == "w" and "White" or "Black") .. " to move."
	if isCheckNow then
		self.message = (self.turn == "w" and "White" or "Black") .. " to move: check."
	end

	self:playSound(status)
	self:updateGameEnd()
	self:refreshStatus()
	return true
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

	local boardData = _Game.makeBoard()
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

	local s = {}
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

	return s
end

local function loadFEN(self, fen)
	local parsed, err = parseFEN(fen)
	if not parsed then
		return nil, err
	end

	for k, v in ipairs(parsed.board) do
		self.board[k] = v
	end
	parsed.board = nil

	for k, v in pairs(parsed) do
		self[k] = v
	end

	if self:inCheck(self.turn) then
		self.message = ((self.turn == "w") and "White" or "Black") .. " to move: check."
	else
		self.message = ((self.turn == "w") and "White" or "Black") .. " to move."
	end
	-- refreshStatus()
	-- if board then board.dirty = true end
	return true
end

local function restartGame(self, fen)
	self.history = {}
	return self:loadFEN(fen or 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1')
end
local function refreshStatus(self) end

local function gameOver(self, message)
	self.over = true
	self.message = message
	self:refreshStatus()
	self:overed()
end

function _Game.Game(board)
	return {
		board = board,
		turn = "w",
		team = nil,
		castling = { wk = true, wq = true, bk = true, bq = true },
		enPassant = nil,
		halfmove = 0,
		fullmove = 1,
		history = {},
		over = false,
		legalMoves = {},
		result = nil,
		message = "White to move.",

		-- cloneState = cloneState,
		squareAttacked = squareAttacked,
		findKing = findKing,
		setDefaultPieces = setDefaultPieces,
		inCheck = inCheck,
		pseudoMovesFrom = pseudoMovesFrom,
		applyMove = applyMove,
		legalMovesFrom = legalMovesFrom,
		allLegalMoves = allLegalMoves,
		updateGameEnd = updateGameEnd,
		moveSelectedTo = moveSelectedTo,
		addToHistory = addToHistory,
		loadFEN = loadFEN,
		restartGame = restartGame,
		refreshStatus = refreshStatus,
		gameOver = gameOver,
		getSAN = getSAN,
	}
end

return _Game