-- function _G.log(...)
-- 	local texts = {...}
-- 	local file = fs.open("log.txt", "a")
-- 	for i, v in ipairs(texts) do
-- 		if type(v) == "table" and not type(v) == "thread" then
-- 			v = textutils.serialise(v)
-- 		else
-- 			v = tostring(v)
-- 		end
-- 		file.write(v.."; ")
-- 	end
-- 	file.write("\n")
-- 	file.close()
-- end
package.path = package.path .. ";/Data/?" .. ";/Data/?.lua"

local UI = require "ui2"
local Classes = require "Classes"
local blittle = require "blittle_extended"
local root = UI.Root()

root.team = "black"
root.turn = true
local abc = {"a", "b", "c", "d", "e", "f", "g", "h"}

local surface = UI.Box{x = 1, y = 1, w = root.w, h = root.h, fc = colors.white, bc = colors.black}
root:addChild(surface)

local function toL(n)
	return abc[n]
end

-- local function misc()
-- 	local PM = {}

-- 	for _, v in ipairs(board.lines) do
-- 		for _, piece in ipairs(board.lines) do
-- 			piece
-- 		end
-- 	end

-- 	return PM
-- end

local function take_piece(board)
	for i = 1, 8 do
		local wp = Classes.piece{x = i, y = 2, w = 1, h = 1, team = "white", type = "pawn"}
		board:addChild(wp)
	end

	local wr1 = Classes.piece{x = 1, y = 1, w = 1, h = 1, team = "white", type = "rook"}
	board:addChild(wr1)

	local wh1 = Classes.piece{x = 2, y = 1, w = 1, h = 1, team = "white", type = "knight"}
	board:addChild(wh1)

	local wb1 = Classes.piece{x = 3, y = 1, w = 1, h = 1, team = "white", type = "bishop"}
	board:addChild(wb1)

	local wk = Classes.piece{x = 4, y = 1, w = 1, h = 1, team = "white", type = "king"}
	board:addChild(wk)

	local wq = Classes.piece{x = 5, y = 1, w = 1, h = 1, team = "white", type = "queen"}
	board:addChild(wq)

	local wb2 = Classes.piece{x = 6, y = 1, w = 1, h = 1, team = "white", type = "bishop"}
	board:addChild(wb2)

	local wh2 = Classes.piece{x = 7, y = 1, w = 1, h = 1, team = "white", type = "knight"}
	board:addChild(wh2)

	local wr2 = Classes.piece{x = 8, y = 1, w = 1, h = 1, team = "white", type = "rook"}
	board:addChild(wr2)

	for i = 1, 8 do
		local bp = Classes.piece{x = i, y = 7, w = 1, h = 1, team = "black", type = "pawn"}
		board:addChild(bp)
	end

	local br1 = Classes.piece{x = 1, y = 8, w = 1, h = 1, team = "black", type = "rook"}
	board:addChild(br1)

	local bh1 = Classes.piece{x = 2, y = 8, w = 1, h = 1, team = "black", type = "knight"}
	board:addChild(bh1)

	local bb1 = Classes.piece{x = 3, y = 8, w = 1, h = 1, team = "black", type = "bishop"}
	board:addChild(bb1)

	local bk = Classes.piece{x = 4, y = 8, w = 1, h = 1, team = "black", type = "king"}
	board:addChild(bk)

	local bq = Classes.piece{x = 5, y = 8, w = 1, h = 1, team = "black", type = "queen"}
	board:addChild(bq)

	local bb2 = Classes.piece{x = 6, y = 8, w = 1, h = 1, team = "black", type = "bishop"}
	board:addChild(bb2)

	local bh2 = Classes.piece{x = 7, y = 8, w = 1, h = 1, team = "black", type = "knight"}
	board:addChild(bh2)

	local br2 = Classes.piece{x = 8, y = 8, w = 1, h = 1, team = "black", type = "rook"}
	board:addChild(br2)

	board:onLayout()
end

local function play_game()
	surface:removeChild(true)
	surface.dirty = true

	local board = UI.Box{x = math.floor((root.w - 8)/2), y = math.floor((root.h - 8)/2), w = 8, h = 8, bc = colors.orange, bc_alt = colors.brown}
	surface:addChild(board)
	board.lines = {
		{['a'] = 0, ['b'] = 0, ['c'] = 0, ['d'] = 0, ['e'] = 0, ['f'] = 0, ['g'] = 0, ['h'] = 0},
		{['a'] = 0, ['b'] = 0, ['c'] = 0, ['d'] = 0, ['e'] = 0, ['f'] = 0, ['g'] = 0, ['h'] = 0},
		{['a'] = 0, ['b'] = 0, ['c'] = 0, ['d'] = 0, ['e'] = 0, ['f'] = 0, ['g'] = 0, ['h'] = 0},
		{['a'] = 0, ['b'] = 0, ['c'] = 0, ['d'] = 0, ['e'] = 0, ['f'] = 0, ['g'] = 0, ['h'] = 0},
		{['a'] = 0, ['b'] = 0, ['c'] = 0, ['d'] = 0, ['e'] = 0, ['f'] = 0, ['g'] = 0, ['h'] = 0},
		{['a'] = 0, ['b'] = 0, ['c'] = 0, ['d'] = 0, ['e'] = 0, ['f'] = 0, ['g'] = 0, ['h'] = 0},
		{['a'] = 0, ['b'] = 0, ['c'] = 0, ['d'] = 0, ['e'] = 0, ['f'] = 0, ['g'] = 0, ['h'] = 0},
		{['a'] = 0, ['b'] = 0, ['c'] = 0, ['d'] = 0, ['e'] = 0, ['f'] = 0, ['g'] = 0, ['h'] = 0}
	}

	local alphabet = UI.Label{x = board.x, y = board.y + board.h, h = 1, w = board.w, text = "hgfedcba", bc = surface.bc, fc = colors.lightGray}
	surface:addChild(alphabet)

	local num = UI.Label{x = board.x + board.w, y = board.y, h = board.h, w = 1, text = "1\n2\n3\n4\n5\n6\n7\n8", bc = surface.bc, fc = colors.lightGray}
	surface:addChild(num)

	board.draw = function(self)
		local function st(n)
			local string
			if n % 2 ~= 0 then
				string = colors.toBlit(self.bc)..colors.toBlit(self.bc_alt)
				return string:rep(self.w/2)
			else
				string = colors.toBlit(self.bc_alt)..colors.toBlit(self.bc)
				return string:rep(self.w/2)
			end
		end

		for i = 1, self.h do
			term.setCursorPos(self.x, self.y + i - 1)
			term.blit((" "):rep(self.w), ("0"):rep(self.w), st(i))
		end

		local p = self.selected_piece
		if p then
			local pm = self:checkMoves(p)
			term.setCursorPos(p.x, p.y)
			for i, v in ipairs(pm) do
				local x, y = self.x + v[1] - 1, self.y + v[2] - 1
				term.setCursorPos(x, y)
				term.setBackgroundColor(((v[1] + v[2]) % 2 ~= 0) and self.bc_alt or self.bc)
				term.setTextColor(colors.green)
				if v[3] and v[3] == "enemy" then
					term.setTextColor(colors.red)
					term.setBackgroundColor(colors.red)
				end
				if x <= self.x + self.w - 1 and x >= self.x and y >= self.y and y <= self.h + self.y - 1 then term.write("\7") end
			end
		end
	end

	board.onMouseDown = function(self, btn, x, y)
		local p = self.selected_piece
		if p then
			p.selected = false
			p.dirty = true

			local pm, enemy = self:checkMoves(p)

			for _, v in ipairs(pm) do
				if (self.x + v[1] - 1) == x and (self.y + v[2] - 1) == y then
					self.lines[p.local_y][toL(p.local_x)] = 0
					p.local_x = v[1]
					p.local_y = v[2]
					self.lines[p.local_y][toL(p.local_x)] = p
					p.hasMoved = true
					if p.type == 'pawn' then
						p.dist = 1
					end
					local ro = v[3]
					if ro then
						self.lines[ro[1].local_y][toL(ro[1].local_x)] = 0
						ro[1].local_x = ro[2][1]
						ro[1].local_y = ro[2][2]
						self.lines[ro[1].local_y][toL(ro[1].local_x)] = p
						ro[1].hasMoved = true
					end
					break
				end
			end

			for _, v in ipairs(enemy) do
				v.canBeat = false
			end

			self.selected_piece = nil
			self:onLayout()
		end
		return true
	end

	board.beatPiece = function (self, piece)
		self:onMouseDown(1, piece.x, piece.y)
		self:removeChild(piece)
	end

	local old_addChild = board.addChild
	board.addChild = function(self, child, pos)
		if self.lines[child.y][toL(child.x)] == 0 then
			self.lines[child.y][toL(child.x)] = child
			old_addChild(self, child, pos)
		end
	end

	board.checkMoves = function(self, p)
		local pm = {}
		local enemy = {}

		if not (p.type == "knight") then
			for _, dir in ipairs(p.directions) do
				local dx, dy = dir[1], dir[2]

				for dist = 1, p.dist do -- Ферзь може ходити максимум на 7 клітинок
					local target_x = p.local_x + (dx * dist)
					local target_y = p.local_y + (dy * dist)

					-- Перевірка меж дошки (1-8)
					if target_x < 1 or target_x > 8 or target_y < 1 or target_y > 8 then
						break
					end

					-- Отримуємо літеру стовпця (a-h)
					local col_letter = toL(target_x)

					-- Перевіряємо, чи є там фігура
					local square_content = self.lines[target_y][col_letter]

					if square_content == 0 then
						-- Клітинка порожня — додаємо хід
						table.insert(pm, {target_x, target_y})
					else
						if square_content.team ~= p.team and p.type ~= 'pawn' then
							table.insert(enemy, square_content)
							table.insert(pm, {target_x, target_y})
							square_content.canBeat = true
						end
						break -- Далі за фігуру ферзь стрибати не може
					end
				end
			end
		elseif p.type == "knight" then
			pm = {
				{p.local_x - 2, p.local_y + 1},
				{p.local_x - 1, p.local_y + 2},
				{p.local_x + 1, p.local_y + 2},
				{p.local_x + 2, p.local_y + 1},
				{p.local_x + 2, p.local_y - 1},
				{p.local_x + 1, p.local_y - 2},
				{p.local_x - 1, p.local_y - 2},
				{p.local_x - 2, p.local_y - 1},
			}
			for i, v in ipairs(pm) do
				if (v[1] > 8 or v[1] < 1) or (v[2] > 8 or v[2] < 1) then
					table.remove(pm, i)
				else
					local target = self.lines[v[2]][toL(v[1])]
					if target and target ~= 0 then
						if target.team == p.team then
							table.remove(pm, i)
						else
							table.insert(enemy, target)
							target.canBeat = true
						end
					end
				end
			end
		end
		if p.type == "king" and not p.hasMoved then -- башня рокирует с королем
			local left = self.lines[p.local_y][toL(p.local_x - 3)]
			local right = self.lines[p.local_y][toL(p.local_x + 4)]
			if not left.hasMoved then
				local btw = false
				for i = 1, 2 do
					if self.lines[p.local_y][toL(p.local_x - i)] ~= 0 then btw = true break end
				end
				if btw == false then table.insert(pm, {p.local_x - 2, p.local_y, {left, {3,p.local_y}}}) end
			end
			if not right.hasMoved then
				local btw = false
				for i = 1, 3 do
					if self.lines[p.local_y][toL(p.local_x + i)] ~= 0 then btw = true break end
				end
				if btw == false then table.insert(pm, {p.local_x + 2, p.local_y, {right, {5,p.local_y}}}) end
			end
		elseif p.type == "pawn" then
			local directions = {}
			if p.team == "white" then
				directions = {
					{1, 1}, {-1, 1}
				}
			else
				directions = {
					{1, -1}, {-1, -1}
				}
			end
			for _, dir in ipairs(directions) do
				local dx, dy = dir[1], dir[2]

				for dist = 1, 1 do -- Ферзь може ходити максимум на 7 клітинок
					local target_x = p.local_x + (dx * dist)
					local target_y = p.local_y + (dy * dist)

					-- Перевірка меж дошки (1-8)
					if target_x < 1 or target_x > 8 or target_y < 1 or target_y > 8 then
						break
					end

					-- Отримуємо літеру стовпця (a-h)
					local col_letter = toL(target_x)

					-- Перевіряємо, чи є там фігура
					local square_content = self.lines[target_y][col_letter]

					if square_content ~= 0  then
						if square_content.team ~= p.team then
							table.insert(enemy, square_content)
							table.insert(pm, {target_x, target_y})
							square_content.canBeat = true
						end
						break -- Далі за фігуру ферзь стрибати не може
					end
				end
			end
		end

		return pm, enemy
	end

	local BTN_Turn = UI.Button{x = root.w - 10, y = 5, w = 10, h = 1, text = root.team, bc = colors.gray, fc = colors.white}
	surface:addChild(BTN_Turn)

	BTN_Turn.pressed = function (self)
		root.turn = not root.turn
		if root.turn then
			root.team = "black"
		else
			root.team = "white"
		end
		self:setText(root.team)
	end

	take_piece(board)
end

local function main_menu()
	local logo_img = blittle.load("Data/logo.ico")
	local c_x = math.floor((root.w - 6)/2) + 1

	local logo = UI.Box{x = c_x, y = 3, w = 6, h = 5, bc = colors.black}
	surface:addChild(logo)

	logo.draw = function (self)
		blittle.draw(logo_img, self.x, self.y)
	end

	local BTN_Play = UI.Button{x = c_x, y = logo.y + logo.h + 1, w = 6, h = 1, text = "Play", align = "center", bc = colors.gray, fc = surface.fc}
	surface:addChild(BTN_Play)

	local BTN_Exit = UI.Button{x = c_x, y = BTN_Play.y + 2, w = 6, h = 1, text = "Exit", align = "center", bc = colors.gray, fc = surface.fc}
	surface:addChild(BTN_Exit)

	BTN_Play.pressed = function()
		play_game()
	end

	BTN_Exit.pressed = function()
		return os.queueEvent("terminate")
	end
end

-- local debug_screen = UI.Label{x = 10, y = 2, w = 10, h = 1, bc = colors.black, fc = colors.white, text = "text"}
-- board_page:addChild(debug_screen)

surface.onResize = function (width, height)
	surface.w, surface.h = width, height
end

play_game()
root:mainloop()