local path = ''
package.path = package.path .. ";/"..path.."Data/?;/"..path.."Data/?.lua;/"..path.."Data/?/init.lua"
-- log = require 'inspector'

-- term.setTextColor(colors.yellow)
-- print('Print \'t\' or \'g\' to run Chess using text or graphics mode. Or just press Enter, to auto detect mode')
-- term.setTextColor(colors.white)
-- local r = read()

-- if r == 'g' or r == '' and term.setGraphicsMode then
-- 	term.setGraphicsMode(1)
-- 	os.run(_ENV, 'GM.lua')
-- elseif r == 't' or r == '' then
-- 	os.run(_ENV, 'TM.lua')
-- end

if term.setGraphicsMode then
	term.setGraphicsMode(1)
	os.run(_ENV, path .. 'GM.lua')
elseif r == 't' or r == '' then
	os.run(_ENV, path .. 'TM.lua')
end
