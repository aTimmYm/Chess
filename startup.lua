_G.ver = '0.4.13'
package.path = package.path .. ";/Data/?;/Data/?.lua;/Data/?/init.lua"
-- function _G.log(...)
-- 	local texts = {...}
-- 	local file = fs.open("log.txt", "a")
-- 	for i, v in ipairs(texts) do
-- 		if type(v) == "table" and type(v) ~= "thread" then
-- 			v = textutils.serialise(v)
-- 		else
-- 			v = tostring(v)
-- 		end
-- 		file.write(v.."; ")
-- 	end
-- 	file.write("\n")
-- 	file.close()
-- end

local r = read()

if r == 'g' or r == '' and term.setGraphicsMode then
	term.setGraphicsMode(1)
	os.run(_ENV, 'GM.lua')
elseif r == 't' or r == '' then
	os.run(_ENV, 'TM.lua')
end
