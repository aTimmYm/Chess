local geometry = {}

-- Допоміжна функція: чи знаходиться точка (x, y) всередині кола?
local function isInsideCirle(x, y, cx, cy, radius)
	local dx = x - cx
	local dy = y - cy
	-- Використовуємо формулу кола x^2 + y^2 <= R^2 (без math.sqrt для швидкодії)
	-- Додаємо мізерну похибку (0.01), щоб нівелювати проблеми з плаваючою комою
	return (dx * dx + dy * dy) <= (radius * radius + 0.01)
end

local function isInsideRect(dx, dy, radius)
	local c = radius - 0.5
	return (dx - c)^2 + (dy - c)^2 <= radius * radius + 0.01
end

function geometry.draw_rounded_rect_outline(x, y, w, h, r, bc)
	local R = math.floor(r)
	R = math.min(R, math.floor(w / 2), math.floor(h / 2))

	if R < 1 then
		-- Якщо радіус 0, малюємо звичайний прямокутник
		-- (Тут можна додати стандартний drawLine для всіх сторін)
		return
	end

	for i = 0, R - 1 do
		for j = 0, R - 1 do
			if isInsideRect(i, j, R) then
				if not isInsideRect(i - 1, j, R) or not isInsideRect(i, j - 1, R) then
					-- Top-Left
					term.setPixel(x + i, y + j, bc)
					-- Top-Right
					term.setPixel(x + w - 1 - i, y + j, bc)
					-- Bottom-Left
					term.setPixel(x + i, y + h - 1 - j, bc)
					-- Bottom-Right
					term.setPixel(x + w - 1 - i, y + h - 1 - j, bc)
				end
			end
		end
	end

	-- Малюємо прямі з'єднувальні лінії
	-- Горизонтальні (з урахуванням відступу на радіус)
	for ix = x + R, x + w - R - 1 do
		term.setPixel(ix, y, bc)             -- Верхня
		term.setPixel(ix, y + h - 1, bc)     -- Нижня
	end
	-- Вертикальні
	for iy = y + R, y + h - R - 1 do
		term.setPixel(x, iy, bc)             -- Ліва
		term.setPixel(x + w - 1, iy, bc)     -- Права
	end
end

function geometry.draw_filled_rounded_rect(x, y, w, h, r, bc)
	local R = math.floor(r)
	R = math.min(R, math.floor(w / 2), math.floor(h / 2))

	-- 1. Малюємо верхню та нижню частини (кути + з'єднувальна лінія між ними)
	for j = 0, R - 1 do
		-- Знаходимо зміщення (offset) для поточного рядка j
		-- Шукаємо найперший піксель 'i', який потрапляє в радіус
		local offset = R
		for i = 0, R - 1 do
			if isInsideRect(i, j, R) then
				offset = i
				break
			end
		end

		-- Малюємо горизонтальну лінію для цього рівня (зверху і знизу)
		-- Лінія йде від (x + offset) до (x + w - 1 - offset)
		local rowWidth = w - 2 * offset
		if rowWidth > 0 then
			-- Верхній сегмент
			for ix = 0, rowWidth - 1 do
				term.setPixel(x + offset + ix, y + j, bc)
			end
			-- Нижній сегмент
			for ix = 0, rowWidth - 1 do
				term.setPixel(x + offset + ix, y + h - 1 - j, bc)
			end
		end
	end

	-- 2. Малюємо центральну частину (прямокутник на всю ширину між кутами)
	-- Ця частина малюється тільки якщо висота більша за сумарний радіус кутів
	if h > 2 * R then
		for iy = y + R, y + h - R - 1 do
			for ix = 0, w - 1 do
				term.setPixel(x + ix, iy, bc)
			end
		end
	end
end

function geometry.draw_circle(startX, startY, diameter, bg)
	local radius = diameter / 2

	-- Визначаємо математичний центр кола відносно його початку (0 до diameter-1)
	local cx = radius - 0.5
	local cy = radius - 0.5

	-- Скануємо кожен піксель у межах нашого квадрата
	for x = 0, diameter - 1 do
		for y = 0, diameter - 1 do

			-- Якщо піксель належить до кола (заливки)
			if isInsideCirle(x, y, cx, cy, radius) then
				local isEdge = false

				-- Якщо піксель знаходиться на самій межі квадрата - це гарантовано край
				if x == 0 or x == diameter - 1 or y == 0 or y == diameter - 1 then
					isEdge = true
				else
					-- Перевіряємо 4-х сусідів (хрестом: верх, низ, ліво, право)
					-- Якщо хоча б один сусід "порожній" (не входить у коло), значить ми на краю
					if not isInsideCirle(x - 1, y, cx, cy, radius) or
					   not isInsideCirle(x + 1, y, cx, cy, radius) or
					   not isInsideCirle(x, y - 1, cx, cy, radius) or
					   not isInsideCirle(x, y + 1, cx, cy, radius) then
						isEdge = true
					end
				end

				-- Малюємо піксель, якщо він визнаний краєм
				if isEdge then
					term.setPixel(math.floor(startX + x), math.floor(startY + y), bg)
				end
			end

		end
	end
end

function geometry.draw_filled_circle(startX, startY, diameter, bg)
	local radius = diameter / 2

	-- Визначаємо математичний центр кола відносно його початку (0 до diameter-1)
	local cx = radius - 0.5
	local cy = radius - 0.5

	-- Скануємо кожен піксель у межах нашого квадрата
	for x = 0, diameter - 1 do
		for y = 0, diameter - 1 do
			-- Якщо піксель належить до кола (заливки)
			if isInsideCirle(x, y, cx, cy, radius) then
				term.setPixel(math.floor(startX + x), math.floor(startY + y), bg)
			end
		end
	end
end

return geometry