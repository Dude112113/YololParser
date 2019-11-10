local loveframes = require "loveframes"
require "loveframes_ext"
local devices = require "devices"


-- Patch terrible text colors
-- when its a dark skin the text is hard to see due to its color
local textColor = {0.9, 0.9, 0.9, 1}
local color = function(s, a) return {loveframes.Color(s, a)} end
for i, v in pairs(loveframes.skins) do
	if i:sub(1, 4) == "Dark" then
		v.controls.color_fore0  = color "e5e5e5"
	end
end

-- TODO: customize this
loveframes.SetActiveSkin("Dark green")


local menus = {}


do
	local DeviceInfo = {
		deviceNamePadding=5,
		deviceFieldsPadding=5,
		deviceNameFont=love.graphics.newFont(24),
		deviceDescFont=love.graphics.newFont(14)
	}
	menus.DeviceInfo = DeviceInfo
	local base = loveframes.Create("panel")
	DeviceInfo.base = base

	local DeviceName = loveframes.Create("text", base)
	DeviceInfo.DeviceName = DeviceName

	local DeviceFields = loveframes.Create("grid", base)

	function DeviceInfo.setDevice(device)
		DeviceInfo.device = device

		for i, obj in pairs(DeviceFields.children) do
			obj:Remove()
			DeviceFields.children[i] = nil
		end

		if device == nil then
			DeviceName:SetText {
				{font=DeviceInfo.deviceNameFont, color=textColor}, "No Device Selected",
				"\n",
				{font=DeviceInfo.deviceDescFont, color=textColor}, "No Device Description."
			}
			DeviceFields:SetRows(0)
		else
			DeviceName:SetText {
				{font=DeviceInfo.deviceNameFont, color=textColor}, device.name or "<NO_DEVICE_NAME>",
				"\n",
				{font=DeviceInfo.deviceDescFont, color=textColor}, device.desc or "No Device Description."
			}
			local orderedFields = {}
			for fieldName, field in pairs(device.fields) do
				table.insert(orderedFields, {fieldName, field})
			end
			table.sort(orderedFields, function(a, b)
				if a[1].order == nil and b[1].order == nil and a[1].name ~= nil and b[1].name ~= nil then
					return a[1].name < b[1].name
				end
				return (a[1].order or -1) < (b[1].order or -1)
			end)
			DeviceFields:SetRows(#orderedFields)
			local function OnValueEditFocusGained(self)
				if self:GetText():sub(1, 1) == "\"" then
					self.indicatornum = self.indicatornum - 1
				end
			end
			for row, fieldData in ipairs(orderedFields) do
				local fieldName, field = unpack(fieldData)

				local FieldNameEdit = loveframes.Create("textinput")
				FieldNameEdit:SetSize(DeviceFields:GetCellWidth(), DeviceFields:GetCellHeight())
				FieldNameEdit:SetText(field.name)
				local newName
				function FieldNameEdit:OnEnter()
					if newName ~= nil then
						if newName ~= nil then
							field.name = newName
							newName = nil
						end
						FieldNameEdit:SetText(field.name)
					end
				end
				function FieldNameEdit:Update(dt)
					if FieldNameEdit:GetFocus() then
						newName = FieldNameEdit:GetText()
					else
						if newName ~= nil then
							field.name = newName
							newName = nil
						end
						FieldNameEdit:SetText(field.name)
					end
				end
				DeviceFields:AddItem(FieldNameEdit, row, 1)

				local FieldValueEdit = loveframes.Create("textinput")
				FieldValueEdit:SetSize(DeviceFields:GetCellWidth(), DeviceFields:GetCellHeight())
				FieldValueEdit:SetText(type(field.value) == "string" and "\"" .. field.value .. "\"" or tostring(field.value))
				local newValue
				function FieldValueEdit:OnEnter()
					if newValue ~= nil then
						if newValue:sub(1, 1) == "\"" then
							field.value = newValue:gsub("^\"", ""):gsub("\"$", "")
						else
							field.value = tonumber(newValue)
						end
						newValue = nil
						FieldValueEdit:SetText(type(field.value) == "string" and "\"" .. field.value .. "\"" or tostring(field.value))
					end
				end
				function FieldValueEdit:Update(dt)
					if FieldValueEdit:GetFocus() then
						local text = FieldValueEdit:GetText()
						newValue = text
					else
						if newValue ~= nil then
							if tonumber(newValue) ~= nil then
								field.value = tonumber(newValue)
							elseif newValue == "" then
								field.value = field.default
							else
								field.value = newValue:gsub("^\"", ""):gsub("\"$", "")
							end
							newValue = nil
						end
						FieldValueEdit:SetText(type(field.value) == "string" and "\"" .. field.value .. "\"" or tostring(field.value))
					end
				end
				FieldValueEdit.OnFocusGained = OnValueEditFocusGained
				DeviceFields:AddItem(FieldValueEdit, row, 2)
			end
		end

		DeviceFields:SetPos(DeviceInfo.deviceFieldsPadding, DeviceInfo.deviceFieldsPadding+DeviceName.height)
	end
	DeviceInfo.setDevice(nil)

	function DeviceInfo.update()
		base:SetSize(280, love.graphics.getHeight())
		base:SetPos(0, 0)

		DeviceName:SetSize(base.width-DeviceInfo.deviceNamePadding*2, DeviceInfo.deviceNameFont:getHeight())
		DeviceName:SetPos(DeviceInfo.deviceNamePadding, DeviceInfo.deviceNamePadding)

		DeviceFields:SetSize(base.width-DeviceInfo.deviceFieldsPadding*2, base.height-DeviceFields.y-DeviceInfo.deviceFieldsPadding*2)
		DeviceFields:SetPos(DeviceInfo.deviceFieldsPadding, DeviceInfo.deviceFieldsPadding+DeviceName.height)
		DeviceFields:SetColumns(2)
		DeviceFields:SetCellWidth(DeviceFields.width/2.15)
	end
end

do
	local DevicesList = {
		deviceNameFont=love.graphics.newFont(24),
		deviceDescFont=love.graphics.newFont(12)
	}
	menus.DevicesList = DevicesList
	local base = loveframes.Create("list")
	DevicesList.base = base
	base:SetPadding(0)
	base:SetSpacing(3)

	local orderedDevices = {}
	for _, device in pairs(devices) do
		table.insert(orderedDevices, device)
	end
	table.sort(orderedDevices, function(a, b)
		return (a.name or "") < (b.name or "")
	end)

	for _, device in ipairs(orderedDevices) do
		local panel = loveframes.Create("panel")

		local padding = 2
		local targetWidth = 80
		local dw, dh = device:getSize()
		local aspect = targetWidth/dw
		local panelHeight = dh*aspect + (padding*2)
		local panelWidth = base.width + padding
		local leftOfPreviewWidth = panelWidth - targetWidth - (padding*2) - 26

		local DeviceName = loveframes.Create("text", panel)
		DeviceName:SetSize(leftOfPreviewWidth, -1)
		DeviceName:SetPos(padding, padding)
		DeviceName:SetText {{font=DevicesList.deviceNameFont, color=textColor}, device.name or "<NO_DEVICE_NAME>"}

		local DescText = loveframes.Create("text", panel)
		-- TODO: move SetSize to DevicesList.update() if possible as it is based on panelWidth which is based on base which is can be changed in DevicesList.update()
		DescText:SetSize(leftOfPreviewWidth, -1)
		DescText:SetPos(padding, padding + DeviceName.y + DeviceName.height)
		DescText:SetText {{font=DevicesList.deviceDescFont, color=textColor}, device.desc or "No Device Description."}
		local descTextBottom = padding + DeviceName.y + DeviceName.height + DescText.y + DescText.height + (padding*2)
		if descTextBottom > panelHeight then
			panelHeight = descTextBottom
		end
		panel:SetSize(panelWidth, panelHeight)
		function panel:DrawOver()
			local tx, ty = self.x + self.width - targetWidth - padding, self.y + padding
			love.graphics.push()
			love.graphics.translate(tx, ty)
			love.graphics.scale(aspect, aspect)
			device:draw()
			love.graphics.pop()
		end

		base:AddItem(panel)
	end

	function DevicesList.update()
		base:SetSize(280, love.graphics.getHeight())
		base:SetPos(love.graphics.getWidth()-base.width, 0)
	end
end


return menus