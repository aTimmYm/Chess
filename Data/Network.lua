local _Network = {}
local clients = {}
if periphemu then
	periphemu.create('back', 'modem')
end
local modems = {peripheral.find("modem")}
local modem = (#modems > 0) and peripheral.getName(modems[1])
local Rednet = nil

local function send(to, message)
	message = type(message) == 'table' and textutils.serialiseJSON(message) or message

	if type(to) == 'number' then
		rednet.send(to, message)
		return
	elseif to.rednetID then
		rednet.send(to.rednetID, message)
		return
	end

	to.send(message)
end

function _Network.updateModems()
	modems = {peripheral.find('modem')}
	if #modems > 0 then
		modem = peripheral.getName(modems[1])
	end
end

function _Network.startServer(self, port)
	if not port then
		if not modem then return false, 'No modem for use' end
		Rednet = true
		rednet.open(modem)
		self.server = true
		self.running = true
		return true
	end
	local ret, err = http.websocketServer(port)
	if not ret then return ret, err end

	for i, v in pairs(ret) do
		self[i] = v
	end

	self.server = true
	self.running = true

	return true
end

function _Network.stopServer(self)
	if not self.server then return end
	if Rednet then
		for data, client in pairs(clients) do
			send(client, 'rednet_closed')
			clients[data] = nil
		end
		rednet.close(modem)
	else
		for data, client in pairs(clients) do
			client.close()
			client[data] = nil
		end
		self.close()
	end

	self.server = nil
	self.listen = nil
	self.close = nil
	self.running = nil
end

function _Network.connectToServer(self, ip, port)
	if not port then
		if not modem then return false, 'No modem for use' end
		rednet.open(modem)
		rednet.send(tonumber(ip), 'rednet_server_connect')
		self.rednetID = tonumber(ip)
		self.running = true
		Rednet = true
		return true
	end
	local ret, err = http.websocket("ws://"..ip..":"..port)
	if not ret then return false, err end

	for i, v in pairs(ret) do
		self[i] = v
	end

	self.running = true

	return true
end

function _Network.disconnectFromServer(self)
	if Rednet then
		rednet.send(self.rednetID, 'rednet_server_closed')
		rednet.close('back')
		Rednet = nil
		return self.closeHandler()
	end
	self.close()
end
_Network.sendTo = send

function _Network.broadcast(self, message)
	if not self.server then return end
	if Rednet then
		for _, client in ipairs(clients) do
			send(client, message)
		end
		return
	end

	for _, client in pairs(clients) do
		send(client, message)
	end
end

_Network.connectHandler = function () end
_Network.messageHandler = function () end
_Network.closeHandler = function () end

function _Network.eventHandler(self, evt)
	local event = evt[1]
	if event == 'websocket_server_connect' then
		clients[evt[3].clientID] = evt[3]
		return self.connectHandler(table.unpack(evt, 2, #evt))
	elseif event == 'websocket_server_closed' then
		clients[evt[2]] = nil
		return self.closeHandler(table.unpack(evt, 2, #evt))
	elseif event == 'websocket_closed' then
		self.listen = nil
		self.close = nil
		self.running = nil
		return self.closeHandler(table.unpack(evt, 2, #evt))
	elseif event == 'rednet_message' then
		if evt[3] == 'rednet_server_connect' then
			table.insert(clients, evt[2])
			return self.connectHandler(table.unpack(evt, 2, #evt))
		elseif evt[3] == 'rednet_server_closed' then
			for i, v in ipairs(clients) do
				if v == evt[2] then
					table.remove(clients, i)
				end
			end
			return self.closeHandler(table.unpack(evt, 2, #evt))
		elseif evt[3] == 'rednet_closed' then
			self.running = nil
			self.rednetID = nil
			return self.closeHandler(table.unpack(evt, 2, #evt))
		end
	end
	self.messageHandler(table.unpack(evt, 2, #evt))
end

return _Network