local _Screen = {
	current = nil,
	screens = {},
	surface = nil,
	modal = nil,
}

function _Screen.switch(self, name, ...)
	if self.current then
		self.surface:removeChild(self.current.surface)
	end

	local screen = self.screens[name]

	self.current = screen:new(...)
	self.current.surface:onLayout()
end

function _Screen.openModal(self, name, ...)
	if self.modal then self:closeModal() end

	local screen = self.screens[name]

	self.modal = screen:new(...)
	self.modal.surface:onLayout()
end

function _Screen.closeModal(self)
	if self.modal then
		self.surface:removeChild(self.modal.surface)
		self.modal = nil
		self.surface:onLayout()
	end
end

function _Screen.getCurrent(self)
	return self.current
end

function _Screen.register(self, name, class)
	self.screens[name] = class
end

return _Screen