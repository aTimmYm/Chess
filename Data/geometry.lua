-- local _max = math.max
local _min = math.min
local _floor = math.floor
local _ceil = math.ceil
local _sqrt = math.sqrt

local geometry = {}


local function isInsideCirle(x, y, cx, cy, radius)
	local dx = x - cx
	local dy = y - cy
	return (dx * dx + dy * dy) <= (radius * radius + 0.01)
end

local function isInsideRect(dx, dy, radius)
	local c = radius - 0.5
	return (dx - c)*(dx - c) + (dy - c)*(dy - c) <= radius * radius + 0.01
end

function geometry.draw_rounded_rect_outline(x, y, w, h, r, bc)
	local R = _floor(r)
	R = _min(R, _floor(w / 2), _floor(h / 2))

	if R < 1 then
		term.drawPixels(x, y, bc, w, h)
		return
	end

	for i = 0, R - 1 do
		for j = 0, R - 1 do
			if isInsideRect(i, j, R) then
				if not isInsideRect(i - 1, j, R) or not isInsideRect(i, j - 1, R) then
					term.setPixel(x + i, y + j, bc)
					term.setPixel(x + w - 1 - i, y + j, bc)
					term.setPixel(x + i, y + h - 1 - j, bc)
					term.setPixel(x + w - 1 - i, y + h - 1 - j, bc)
				end
			end
		end
	end

	local drawX = x + R
	local drawW = w - R * 2
	local drawY = y + R
	local drawH = h - R * 2
	term.drawPixels(drawX, y, bc, drawW, 1)
	term.drawPixels(drawX, y + h - 1, bc, drawW, 1)
	term.drawPixels(x, drawY, bc, 1, drawH)
	term.drawPixels(x + w - 1, drawY, bc, 1, drawH)
end

local cornerCache = {}

local function getCornerOffsets(R)
    local cached = cornerCache[R]
    if cached then return cached end

    local c = R - 0.5
    local rr = R * R
    local t = {}

    for j = 0, R - 1 do
        local dy = j - c
        local dx = _sqrt(rr - dy * dy)
        t[j] = _ceil(c - dx - 1e-9)
    end

    cornerCache[R] = t
    return t
end

function geometry.draw_filled_rounded_rect(x, y, w, h, r, bc)
    local R = _floor(r or 0)
    R = _min(R, _floor(w / 2), _floor(h / 2))

    if R <= 0 then
        term.drawPixels(x, y, bc, w, h)
        return
    end

    local offsets = getCornerOffsets(R)

    local innerH = h - 2 * R
    if innerH > 0 then
        term.drawPixels(x, y + R, bc, w, innerH)
    end

    for j = 0, R - 1 do
        local off = offsets[j]
        local rowWidth = w - 2 * off

        if rowWidth > 0 then
            term.drawPixels(x + off, y + j, bc, rowWidth, 1)
            term.drawPixels(x + off, y + h - 1 - j, bc, rowWidth, 1)
        end
    end
end

function geometry.draw_circle(startX, startY, diameter, bg)
	local radius = diameter / 2

	local cx = radius - 0.5
	local cy = radius - 0.5

	for x = 0, diameter - 1 do
		for y = 0, diameter - 1 do

			if isInsideCirle(x, y, cx, cy, radius) then
				local isEdge = false

				if x == 0 or x == diameter - 1 or y == 0 or y == diameter - 1 then
					isEdge = true
				else
					if not isInsideCirle(x - 1, y, cx, cy, radius) or
					   not isInsideCirle(x + 1, y, cx, cy, radius) or
					   not isInsideCirle(x, y - 1, cx, cy, radius) or
					   not isInsideCirle(x, y + 1, cx, cy, radius) then
						isEdge = true
					end
				end

				if isEdge then
					term.setPixel(_floor(startX + x), _floor(startY + y), bg)
				end
			end

		end
	end
end

function geometry.draw_filled_circle(startX, startY, diameter, bc)
	local R = diameter / 2

	local offsets = getCornerOffsets(R)

	for j = 0, R - 1 do
        local off = offsets[j]
        local rowWidth = diameter - 2 * off

        if rowWidth > 0 then
            term.drawPixels(startX + off, startY + j, bc, rowWidth, 1)
            term.drawPixels(startX + off, startY + diameter - 1 - j, bc, rowWidth, 1)
        end
    end
end

return geometry