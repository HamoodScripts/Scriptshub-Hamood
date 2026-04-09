local Players       = game:GetService("Players")
local workspace     = game:GetService("Workspace")
local VIM           = game:GetService("VirtualInputManager")
local UIS           = game:GetService("UserInputService")
local RunService    = game:GetService("RunService")
local Lighting      = game:GetService("Lighting")
local LocalPlayer   = Players.LocalPlayer

-- ══════════════════════════════════════════════════════════════════════════════
--  LINORIA BOILERPLATE (UPDATED URL)
-- ══════════════════════════════════════════════════════════════════════════════
local repo = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'

local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()

local Window = Library:CreateWindow({
	Title = 'Hamood vibecoding',
	Center = true,
	AutoShow = true,
	TabPadding = 8,
	MenuFadeTime = 0.2
})

local Tabs = {
	Ores = Window:AddTab('Ores'),
	Teleports = Window:AddTab('Teleports'),
	Misc = Window:AddTab('Misc'),
	Visuals = Window:AddTab('Visuals'),
	['UI Settings'] = Window:AddTab('UI Settings'),
}

Library:SetWatermark('Hamood vibecoding | Linoria')


-- ══════════════════════════════════════════════════════════════════════════════
--  CONNECTION REGISTRY
-- ══════════════════════════════════════════════════════════════════════════════
local connections = {}
local function track(conn) connections[#connections + 1] = conn end

local function disconnectAll()
	for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
	table.clear(connections)
end


-- ══════════════════════════════════════════════════════════════════════════════
--  ORE ESP (OPTIMIZED FOR 240 FPS)
-- ══════════════════════════════════════════════════════════════════════════════
local oreAdornments = {}
local oreESPEnabled = false
local showTracers = false
local maxEspDistance = 1000

local OreESPGroup = Tabs.Ores:AddLeftGroupbox('ESP Settings')

local function addOreESP(part)
	if not part:IsA("BasePart") then return end
	if oreAdornments[part] then return end

	local color = part.Color

	local box = Instance.new("BoxHandleAdornment")
	box.Adornee             = part
	box.Size                = part.Size
	box.Color3              = color
	box.Transparency        = 0.5
	box.ZIndex              = 5
	box.AlwaysOnTop         = true
	box.Parent              = workspace.CurrentCamera
	box.Visible             = oreESPEnabled

	local tracer = Drawing.new("Line")
	tracer.Visible      = false
	tracer.Color        = color
	tracer.Thickness    = 1
	tracer.Transparency = 1

	oreAdornments[part] = { box = box, tracer = tracer, inRange = true }
end

local function removeOreESP(part)
	local data = oreAdornments[part]
	if data then
		if data.box then data.box:Destroy() end
		if data.tracer then data.tracer:Remove() end
		oreAdornments[part] = nil
	end
end

local function clearAllOreESP()
	for part in pairs(oreAdornments) do removeOreESP(part) end
end

OreESPGroup:AddToggle('OreESP', {
	Text = 'Show Ore ESP',
	Default = false,
	Tooltip = 'Highlights all ores in workspace',
	Callback = function(Value)
		oreESPEnabled = Value
		if Value then
			local placedOre = workspace:FindFirstChild("PlacedOre")
			if not placedOre then return Library:Notify("PlacedOre folder not found.", 4) end
			
			for _, desc in placedOre:GetDescendants() do
				if desc:IsA("BasePart") and not oreAdornments[desc] then
					addOreESP(desc)
				end
			end
		else
			for part, data in pairs(oreAdornments) do
				if data.box then data.box.Visible = false end
				if data.tracer then data.tracer.Visible = false end
			end
		end
	end
})

OreESPGroup:AddToggle('OreTracers', {
	Text = 'Show Tracers',
	Default = false,
	Callback = function(Value) showTracers = Value end
})

OreESPGroup:AddSlider('MaxEspDistance', {
	Text = 'ESP Max Distance',
	Default = 1000,
	Min = 50,
	Max = 5000,
	Rounding = 0,
	Compact = false,
	Callback = function(Value) maxEspDistance = Value end
})

local function setupOreConnections(placedOre)
	track(placedOre.DescendantAdded:Connect(function(desc)
		if desc:IsA("BasePart") then addOreESP(desc) end
	end))
	track(placedOre.DescendantRemoving:Connect(function(desc)
		removeOreESP(desc)
	end))
	
	local lastDistanceCheck = 0

	track(RunService.RenderStepped:Connect(function()
		if not oreESPEnabled then return end
		
		local char = LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local camera = workspace.CurrentCamera
		
		local now = os.clock()
		local shouldUpdateDistance = false
		if now - lastDistanceCheck > 0.5 then
			shouldUpdateDistance = true
			lastDistanceCheck = now
		end
		
		for part, data in pairs(oreAdornments) do
			if part and part.Parent and hrp then
				
				if shouldUpdateDistance then
					local dist = (hrp.Position - part.Position).Magnitude
					data.inRange = dist <= maxEspDistance
					data.box.Visible = data.inRange
				end
				
				if showTracers and data.inRange then
					local screenPos, onScreen = camera:WorldToViewportPoint(part.Position)
					if onScreen then
						data.tracer.From = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y)
						data.tracer.To = Vector2.new(screenPos.X, screenPos.Y)
						data.tracer.Visible = true
					else
						data.tracer.Visible = false
					end
				else
					if data.tracer.Visible then data.tracer.Visible = false end
				end
			else
				data.box.Visible = false
				if data.tracer.Visible then data.tracer.Visible = false end
			end
		end
	end))
end

local existingPlacedOre = workspace:FindFirstChild("PlacedOre")
if existingPlacedOre then
	setupOreConnections(existingPlacedOre)
else
	task.spawn(function()
		local placedOre = workspace:WaitForChild("PlacedOre", 60)
		if placedOre then setupOreConnections(placedOre) end
	end)
end


-- ══════════════════════════════════════════════════════════════════════════════
--  TELEPORT
-- ══════════════════════════════════════════════════════════════════════════════
local TpLoc = Tabs.Teleports:AddLeftGroupbox('Locations')
local TpStore = Tabs.Teleports:AddRightGroupbox('Stores')

local function teleportTo(model)
	local char = LocalPlayer.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	if not model then return Library:Notify("Location not found in workspace.", 3) end

	local target = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if not target then return Library:Notify("No valid part found.", 3) end

	hrp.CFrame = target.CFrame + Vector3.new(0, 5, 0)
end

TpLoc:AddButton({ Text = 'Mine', Func = function() teleportTo(workspace:FindFirstChild("CollapseStuff")) end })
TpLoc:AddButton({
	Text = 'My Plot',
	Func = function()
		local plots = workspace:FindFirstChild("Plots")
		if not plots then return Library:Notify("Plots folder not found.", 3) end
		local myPlot
		for _, plot in plots:GetChildren() do
			local id = plot:GetAttribute("PlayerId") or plot:GetAttribute("OwnerId") or plot:GetAttribute("Owner") or plot:GetAttribute("UserId")
			if id == LocalPlayer.UserId then myPlot = plot break end
		end
		if myPlot then teleportTo(myPlot) else Library:Notify("Your plot was not found.", 4) end
	end
})

for _, storeName in ipairs({ "Explosives Store", "Pickaxe Store", "Backpack Store", "Prestige Store" }) do
	TpStore:AddButton({ Text = storeName, Func = function() teleportTo(workspace:FindFirstChild(storeName)) end })
end


-- ══════════════════════════════════════════════════════════════════════════════
--  MISC & CHARACTER
-- ══════════════════════════════════════════════════════════════════════════════
local MiscMove = Tabs.Misc:AddLeftGroupbox('Movement')
local MiscUtils = Tabs.Misc:AddLeftGroupbox('Utilities')
local MiscSell = Tabs.Misc:AddRightGroupbox('Auto Sell')

local DEFAULT_SPEED = 16
local BOOST_SPEED   = 50
local walkBoostOn   = false
local infJumpOn     = false
local noclipOn      = false

local function applyWalkSpeed(speed)
	local char = LocalPlayer.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then hum.WalkSpeed = speed end
end

track(LocalPlayer.CharacterAdded:Connect(function(char)
	local hum = char:WaitForChild("Humanoid", 10)
	if hum and walkBoostOn then hum.WalkSpeed = BOOST_SPEED end
end))

MiscMove:AddSlider('BoostSpeed', { Text = 'Boost WalkSpeed', Default = 50, Min = 16, Max = 250, Rounding = 0, Callback = function(v) BOOST_SPEED = v if walkBoostOn then applyWalkSpeed(BOOST_SPEED) end end })
MiscMove:AddToggle('WalkBoost', {
	Text = 'WalkSpeed Boost',
	Default = false,
	Callback = function(Value)
		walkBoostOn = Value
		applyWalkSpeed(Value and BOOST_SPEED or DEFAULT_SPEED)
	end
}):AddKeyPicker('WalkBoostKey', {
	Default = 'F1',
	SyncToggleState = true,
	Mode = 'Toggle',
	Text = 'WalkSpeed Boost'
})

MiscMove:AddToggle('InfJump', { Text = 'Infinite Jump', Default = false, Callback = function(v) infJumpOn = v end })
MiscMove:AddToggle('Noclip', { Text = 'Noclip', Default = false, Callback = function(v) noclipOn = v end })

track(UIS.JumpRequest:Connect(function()
	if infJumpOn then
		local char = LocalPlayer.Character
		if char then
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
		end
	end
end))

track(RunService.Stepped:Connect(function()
	if noclipOn then
		local char = LocalPlayer.Character
		if char then
			for _, part in ipairs(char:GetDescendants()) do
				if part:IsA("BasePart") and part.CanCollide then
					part.CanCollide = false
				end
			end
		end
	end
end))

MiscUtils:AddButton({
	Text = 'Refresh Cooldowns',
	Tooltip = 'Kills your character and teleports you back',
	Func = function()
		local char = LocalPlayer.Character
		if not char then return end
		local hrp, hum = char:FindFirstChild("HumanoidRootPart"), char:FindFirstChildOfClass("Humanoid")
		if not hrp or not hum then return end
		local savedCFrame = hrp.CFrame
		local conn
		conn = LocalPlayer.CharacterAdded:Connect(function(newChar)
			conn:Disconnect()
			local newHRP = newChar:WaitForChild("HumanoidRootPart", 10)
			if newHRP then task.wait(0.2) newHRP.CFrame = savedCFrame end
		end)
		hum.Health = 0
	end
})


-- ══════════════════════════════════════════════════════════════════════════════
--  AUTO SELL
-- ══════════════════════════════════════════════════════════════════════════════
local autoSellEnabled = false
local autoSellThread  = nil
local SELL_INTERVAL   = 60

local function getUnloader()
	local ok, result = pcall(function() return workspace.FactoryGridItemsClient.DSBuild3.DSBuild3.Unloader1 end)
	return ok and result or nil
end

local function doSell()
	local char = LocalPlayer.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local unloader = getUnloader()
	if not unloader then return end
	local sellPart = unloader.PrimaryPart or unloader:FindFirstChildWhichIsA("BasePart")
	if not sellPart then return end

	local returnCFrame = hrp.CFrame
	hrp.CFrame = sellPart.CFrame + Vector3.new(0, 4, 0)
	task.wait(0.5)
	VIM:SendKeyEvent(true, Enum.KeyCode.E, false, game)
	task.wait(0.1)
	VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
	task.wait(0.5)
	hrp.CFrame = returnCFrame
end

local function stopAutoSellLoop() autoSellEnabled = false if autoSellThread then task.cancel(autoSellThread) autoSellThread = nil end end
local function startAutoSellLoop()
	autoSellThread = task.spawn(function()
		while autoSellEnabled do
			doSell()
			local elapsed = 0
			while elapsed < SELL_INTERVAL and autoSellEnabled do task.wait(1) elapsed += 1 end
		end
	end)
end

MiscSell:AddButton({ Text = 'Sell Now', Func = doSell })
MiscSell:AddSlider('SellInterval', { Text = 'Sell Interval (s)', Default = 60, Min = 10, Max = 300, Rounding = 0, Callback = function(v) SELL_INTERVAL = v end })
MiscSell:AddToggle('AutoSell', { Text = 'Auto Sell', Default = false, Callback = function(v) if v then autoSellEnabled = true startAutoSellLoop() else stopAutoSellLoop() end end })


-- ══════════════════════════════════════════════════════════════════════════════
--  VISUALS (FULLBRIGHT)
-- ══════════════════════════════════════════════════════════════════════════════
local EnvGroup = Tabs.Visuals:AddLeftGroupbox('Environment')

local fullbrightEnabled = false
local defaultLighting = {
	Ambient = Lighting.Ambient,
	OutdoorAmbient = Lighting.OutdoorAmbient,
	Brightness = Lighting.Brightness,
	ClockTime = Lighting.ClockTime,
	FogEnd = Lighting.FogEnd,
	GlobalShadows = Lighting.GlobalShadows,
}

local function applyFullbright()
	if fullbrightEnabled then
		Lighting.Ambient = Color3.new(1, 1, 1)
		Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
		Lighting.Brightness = 2
		Lighting.ClockTime = 14
		Lighting.FogEnd = 100000
		Lighting.GlobalShadows = false
	else
		Lighting.Ambient = defaultLighting.Ambient
		Lighting.OutdoorAmbient = defaultLighting.OutdoorAmbient
		Lighting.Brightness = defaultLighting.Brightness
		Lighting.ClockTime = defaultLighting.ClockTime
		Lighting.FogEnd = defaultLighting.FogEnd
		Lighting.GlobalShadows = defaultLighting.GlobalShadows
	end
end

EnvGroup:AddToggle('Fullbright', {
	Text = 'Fullbright',
	Default = false,
	Callback = function(Value)
		fullbrightEnabled = Value
		applyFullbright()
	end
})

track(Lighting:GetPropertyChangedSignal("Ambient"):Connect(function() applyFullbright() end))
track(Lighting:GetPropertyChangedSignal("OutdoorAmbient"):Connect(function() applyFullbright() end))


-- ══════════════════════════════════════════════════════════════════════════════
--  LINORIA MANAGERS (SETTINGS & AUTOLOAD)
-- ══════════════════════════════════════════════════════════════════════════════
local MenuGroup = Tabs['UI Settings']:AddLeftGroupbox('Menu')
MenuGroup:AddButton('Unload Script', function()
	stopAutoSellLoop()
	disconnectAll()
	clearAllOreESP()
	applyWalkSpeed(DEFAULT_SPEED)
	if fullbrightEnabled then
		fullbrightEnabled = false
		applyFullbright()
	end
	Library:Unload()
end)

MenuGroup:AddLabel('Menu Bind'):AddKeyPicker('MenuKeybind', { Default = 'RightControl', NoUI = true, Text = 'Menu keybind' })
Library.ToggleKeybind = Options.MenuKeybind

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ 'MenuKeybind' })

ThemeManager:SetFolder('HamoodHub')
SaveManager:SetFolder('HamoodHub/Mining')

SaveManager:BuildConfigSection(Tabs['UI Settings'])
ThemeManager:BuildFeatureSection(Tabs['UI Settings'])

Window:SelectTab(1)
SaveManager:LoadAutoloadConfig()
