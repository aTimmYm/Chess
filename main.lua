APPDIR = ''
APPVERSION = '1.0.1'
package.path = package.path  ..  ";/" .. APPDIR .. "Data/?;/" .. APPDIR .. "Data/?.lua;/" .. APPDIR .. "Data/?/init.lua"
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
	os.run(_ENV, APPDIR  ..  'GM.lua')
elseif r == 't' or r == '' then
	os.run(_ENV, APPDIR  ..  'TM.lua')
end