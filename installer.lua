local link = 'https://raw.githubusercontent.com/aTimmYm/Chess/refs/heads/dev/'

local function write_file(path, data)
	local file = fs.open(path, 'w')
	file.write(data)
	file.close()
end

local function checkUpdates(shaSum)
	local ret = false
	local filesToUpdate = {}
	for line in shaSum:gmatch('([^\n]+)\n?') do
		local path = line:sub(66)
		table.insert(filesToUpdate, path)
		ret = true
	end
	return ret, filesToUpdate
end

local response, err = http.get(link .. 'sha256-sums')
if response then
	print('installing')
	local shaSum = response.readAll()
	response.close()
	local ret, filesToUpdate = checkUpdates(shaSum)
	if ret then
		for i, path in ipairs(filesToUpdate) do
			local request, erra = http.get(link .. path)
			if request then
				write_file(path, request.readAll())
				request.close()
			else
				print(path..': '..erra)
			end
		end
	end
	print('success')
else
	print(err)
end