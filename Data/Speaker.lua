local decoder = require('cc.audio.dfpwm').make_decoder()

local _speaker = {}

local musicFile, speaker
local volume = 3

if periphemu then
	periphemu.create('left', 'speaker')
end
local speakers = {peripheral.find('speaker')}
speaker = speakers[1]

function _speaker.getOutputs()
	local output = {}
	for i, v in ipairs(speakers) do
		output[i] = peripheral.getName(v)
	end
	return output
end

function _speaker.setOutput(string)
	if not peripheral.wrap(string) then
		return false, ''
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
	if not speaker then return end
	if not fs.exists(path) then error('Wrong path') end
	musicFile = fs.open(path, "rb")
	local buffer = decoder(musicFile.read(16 * 1024))
	speaker.playAudio(buffer, volume)
end

return _speaker