local Classes = {}

local function check(self,x,y)
	return (x >= self.x and x < self.w + self.x and
			y >= self.y and y < self.h + self.y)
end
local function onKeyDown(self,key,held) return true end
local function onKeyUp(self,key) return true end
local function onCharTyped(self,chr) return true end
local function onPaste(self,text) return true end
local function onMouseDown(self,btn,x,y) return true end
local function onMouseMove(self,btn,x,y) return false end
local function onMouseUp(self,btn,x,y) return true end
local function onMouseScroll(self,dir,x,y) return false end
local function onMouseDrag(self,btn,x,y) return true end
local function onFocus(self,focused) return true end
local function focusPostDraw(self) end
local function pressed(self) end
local function onLayout(self) self.dirty = true end
local function draw(self) end
local function redraw(self)
	if self.dirty then self:draw() self.dirty = false end
end
local function onEvent(self,evt)
	local event_name = evt[1]
	if event_name == "mouse_drag" then
		return self:onMouseDrag(evt[2],evt[3],evt[4])
	elseif event_name == "mouse_up" then
		return self:onMouseUp(evt[2],evt[3],evt[4])
	elseif event_name == "mouse_click" then
		if self.root then self.root.focus = self end
		return self:onMouseDown(evt[2],evt[3],evt[4])
	elseif event_name == "mouse_scroll" then
		return self:onMouseScroll(evt[2],evt[3],evt[4])
	elseif event_name == "mouse_move" then
		return self:onMouseMove(evt[2],evt[3],evt[4])
	elseif event_name == "char" then
		return self:onCharTyped(evt[2])
	elseif event_name == "key" then
		return self:onKeyDown(evt[2],evt[3])
	elseif event_name == "key_up" then
		return self:onKeyUp(evt[2])
	elseif event_name == "paste" then
		return self:onPaste(evt[2])
	end
	return false
end

local function Widget(args)
	return {
		x = args.x, y = args.y,
		w = args.w, h = args.h,
		dirty = true,
		parent = nil,
		bc = args.bc,
		bc_alt = args.bc_alt,
		fc = args.fc,
		fc_alt = args.fc_alt,
		fc_hv = args.fc_hv,
		bc_hv = args.bc_hv,
		fc_cl = args.fc_cl,
		bc_cl = args.bc_cl,

		check = check,
		onKeyDown = onKeyDown,
		onKeyUp = onKeyUp,
		onCharTyped = onCharTyped,
		onPaste = onPaste,
		onMouseDown = onMouseDown,
		onMouseMove = onMouseMove,
		onMouseUp = onMouseUp,
		onMouseScroll = onMouseScroll,
		onMouseDrag = onMouseDrag,
		onFocus = onFocus,
		focusPostDraw = focusPostDraw,
		draw = draw,
		redraw = redraw,
		onLayout = onLayout,
		onEvent = onEvent,
	}
end

local function remove_piece(self)
	self.parent:onLayout()
	self.parent:removeChild(self)
end

local function piece_onMouseUp(self, btn, x, y)
	-- if not self.root.turn then return end
	local selected_piece = self.parent.selected_piece
	if self.root.team ~= self.team then
		if selected_piece and self.canBeat then
			-- selected_piece.selected = false
			-- selected_piece.local_x = self.local_x
			-- selected_piece.local_y = self.local_y
			self.parent:beatPiece(self)
		end
		return true
	end
	if selected_piece then
		selected_piece.selected = false
		selected_piece.dirty = true
		self.parent.selected_piece = nil
	end
	if self:check(x, y) then
		self.selected = true
		self.parent.selected_piece = self
		self.parent:onLayout()
	end
	self.dirty = true
	return true
end

local function piece_draw(self)
	local parent = self.parent
	term.setCursorPos(self.x, self.y)
	if self.selected then
		term.setBackgroundColor(colors.green)
	elseif self.canBeat then
		term.setBackgroundColor(colors.red)
	else
		term.setBackgroundColor(((self.local_x + self.local_y) % 2 ~= 0) and parent.bc_alt or parent.bc)
	end
	term.setTextColor((self.team == "white") and colors.white or colors.black)
	local name = self.type:sub(1, 1):upper()
	if self.type == "knight" then
		name = "N"
	end
	term.write(name)
end

local DIRECTIONS = {
	['king'] = function(self)
		return {
			{-1, 1}, {0, 1}, {1, 1},
			{-1, 0},		{1, 0},
			{-1, -1}, {0, -1}, {1, -1}
		}, 1
	end,
	['pawn'] = function(self)
		if self.team == 'white' then
			return {{0, 1}}, 2
		else
			return {{0, -1}}, 2
		end
	end,
	['rook'] = function(self)
		return {
			{-1, 0}, {1, 0},
			{0, -1}, {0, 1}
		}, 7
	end,
	['bishop'] = function(self)
		return {
			{-1, 1}, {1, 1},
			{-1, -1}, {1, -1}
		}, 7
	end,
	['queen'] = function(self)
		return {
			{-1, 1}, {0, 1}, {1, 1},
			{-1, 0},		{1, 0},
			{-1, -1}, {0, -1}, {1, -1}
		}, 7
	end,
	['knight'] = function(self)
		return
	end
}

-- local function piece_onMouseDown(self,btn,x,y) return false end

function Classes.piece(args)
	local instance = Widget(args)

	-- instance.coords = {x = args.board_x, y = args.board_y}
	instance.type = args.type
	instance.team = args.team
	instance.hasMoved = false
	instance.canBeat = false
	instance.directions, instance.dist = DIRECTIONS[args.type](instance)

	instance.remove = remove_piece
	instance.draw = piece_draw
	instance.onMouseUp = piece_onMouseUp
	-- instance.onMouseDown = piece_onMouseDown

	return instance
end

return Classes