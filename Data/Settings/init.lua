local settingsPath = APPDIR .. 'Data/Settings/user.json'
local defaultData = {
	['Volume'] = 15,
	['Nickname'] = 'Unknown',
	['OutputDevice'] = '',
	['Language']= 'eng',
	['ColorScheme'] = 'Default',
	['ServerType'] = 'Rednet',
	['PieceScheme'] = 'Letters'
}
local user

if fs.exists(APPDIR .. 'Data/user.json') then
	fs.move(APPDIR .. 'Data/user.json', settingsPath)
end

if fs.exists(settingsPath) then
	local file = fs.open(settingsPath, 'r')
	user = file.readAll()
	file.close()
else
	local jsonDefaultData = textutils.serialiseJSON(defaultData)
	local file = fs.open(settingsPath, 'w')
	file.write(jsonDefaultData)
	file.close()
	user = jsonDefaultData
end
user = textutils.unserialiseJSON(user)

local function saveUserSettings()
	local file = fs.open(settingsPath, 'w')
	file.write(textutils.serialiseJSON(user))
	file.close()
end
do
	user = user or {}
	local write = false
	for k, v in pairs(defaultData) do
		if not user[k] then
			user[k] = v
			write = true
		end
	end
	if write then saveUserSettings() end
end

return setmetatable(user, {
	__call = saveUserSettings,
	__metatable = false,
})