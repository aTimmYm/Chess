local decoder = require('cc.audio.dfpwm').make_decoder()
-- local S = require 'MyS'

local _speaker = {}

local musicFile, speaker
local volume = 3

local speakers = {peripheral.find('speaker')}
if #speakers == 0 and periphemu then
	periphemu.create('left', 'speaker')
	speakers = {peripheral.find('speaker')}
end
speaker = speakers[1]

local function play(self, path)
	-- self.filePath = path or self.filePath
	-- local total_chunks = getTotalChunks(self.filePath)
	-- timeLine.arr = {}
	-- for i = 1, total_chunks do
	-- 	timeLine.arr[i] = i
	-- end

	-- self.music_file = fs.open(self.filePath, "rb")
	-- if not self.music_file then error("Failed to open file: " .. self.filePath) end
	-- local ok, fileSize = pcall(function() return self.music_file.seek("end") end)
	-- fileSize = tonumber(fileSize) or 0

	-- self.data_end = fileSize
	-- if cache[temp].meta_start then
	-- 	self.data_end = cache[temp].meta_start - 1
	-- end

	-- play_at_chunk(1)
	-- self:play_next_chunk()
end

function _speaker.getOutputs()
	local output = {}
	for i, v in ipairs(speakers) do
		output[i] = peripheral.getName(v)
	end
	return output
end

function _speaker.setOutput(string)
	if not peripheral.wrap(string) then
		speaker = speakers[1]
		return false, peripheral.getName(speakers[1])
	end
	speaker = peripheral.wrap(string)
	return true
end

function _speaker.updateOutputs()
	speakers = {peripheral.find('speaker')}
end

function _speaker.setVolume(vol)
	vol = math.min(3, math.max(0, vol))
	volume = vol
end

function _speaker.playFile(path)
	if not fs.exists(path) then error('Wrong path') end
	if not speaker then return end
	musicFile = fs.open(path, "rb")
	local buffer = decoder(musicFile.read(16 * 1024))
	speaker.playAudio(buffer, volume)
end

return _speaker