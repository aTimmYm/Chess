------------| СЕКЦИЯ ЛОКАЛИЗАЦИИ ФУНКЦИЙ |-----------
local string_rep = string.rep
local string_match = string.match
local table_insert = table.insert
-----------------------------------------------------
local M = {}

function M.DEBUG()
	local dbg = peripheral.wrap("left")
	return dbg
end

function M.printTable(...) --вывод массива
	local table = {...}
	for	_,v in pairs(table) do
		if type(v) == "table" then
			for i,v in pairs(v) do
				print(i,"-",v)
			end
		else
			error("The variable type 'table' is not a table")
		end
	end
end

function M.findMaxLenStrOfArray(array)
	local max = 0
	for _, v in pairs(array) do
		max = math.max(max, #v)
	end
	return max
end

function M.openFile(root,path,args)
	local safe_env = {}
	setmetatable(safe_env, { __index = _G })

	safe_env.require = require
	safe_env.shell = shell

	safe_env.os = setmetatable({}, { __index = _G.os })
	safe_env.os.reboot = nil
	safe_env.os.shutdown = nil
	safe_env.os.loadAPI = function()
		return error("Use require instead os.loadAPI")
	end

	safe_env.bOS = nil
	safe_env.root = nil

	local func, load_err = loadfile(path, "t", safe_env)
	if not func then
		local UI = require("ui")
		local infoWin = UI.New_MsgWin(root, "INFO")
		infoWin:callWin(" Load error ", tostring(load_err))
	else
		M.termClear()
		local ret, exec_err = pcall(func, args)
		if not ret then
			local UI = require("ui")
			local infoWin = UI.New_MsgWin(root, "INFO")
			infoWin:callWin(" ERROR ", tostring(exec_err))
		end
	end
	term.setCursorBlink(false)
end


function M.readFile(filePath)
	local lines = {}
	for line in io.lines(filePath) do
		table_insert(lines,line)
	end
	if #lines == 1 or #lines == 0 then return lines[1] end
	return lines
end

function M.readConf(filePath)
	local lines = {}
	for line in io.lines(filePath) do
		if string_match(line, "^%s*$") or string_match(line, "^%s*#") then
			goto continue
		end
		local key, value = string_match(line, "^%s*([^=]+)%s*=%s*(.+)%s*$")
		if value == "true" then
			lines[key] = true
		elseif value == "false" then
			lines[key] = false
		else
			lines[key] = tonumber(value) or value
		end
		::continue::
	end
	return lines
end

function M.saveConf(filePath, file)
	local openFile = fs.open(filePath, "w")
	for key, value in pairs(file) do
		openFile.write(key .. "=" .. tostring(value).."\n")
	end
	openFile.close()
end

function M.playSound(sound, volume)
	if bOS.speaker then
		bOS.speaker.playSound(sound, volume)
	end
end

return M