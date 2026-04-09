local Players       = game:GetService("Players")
local workspace     = game:GetService("Workspace")
local HttpService   = game:GetService("HttpService")
local VIM           = game:GetService("VirtualInputManager")
local UIS           = game:GetService("UserInputService")
local RunService    = game:GetService("RunService")
local LocalPlayer   = Players.LocalPlayer

local Rayfield = loadstring(game:HttpGet("https://sirius.menu/rayfield"))()

local Window = Rayfield:CreateWindow({
	Name            = "Hamood vibecoding",
	LoadingTitle    = "UMT SCRIPT",
	LoadingSubtitle = "by Hamood",
	Theme           = "Default",
})

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
--  ORE ESP
-- ══════════════════════════════════════════════════════════════════════════════
local OreTab = Window:CreateTab("Ores", 6022668955)
OreTab:CreateSection("Ore ESP")

local oreAdornments = {}
local oreESPEnabled = false

local function addOreESP(part)
	if not part:IsA("BasePart") then return end
	if oreAdornments[part] then return end

	local color = part.Color

	local highlight = Instance.new("Highlight")
	highlight.Adornee             = part
	highlight.FillColor           = color
	highlight.OutlineColor        = color
	highlight.FillTransparency    = 0.5
	highlight.OutlineTransparency = 0
	highlight.DepthMode           = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent              = workspace.CurrentCamera

	oreAdornments[part] = { highlight = highlight }
end

local function removeOreESP(part)
	local data = oreAdornments[part]
	if data then
		data.highlight:Destroy()
		oreAdornments[part] = nil
	end
end

local function clearAllOreESP()
	for part in pairs(oreAdornments) do removeOreESP(part) end
end

local function refreshOreESP()
	clearAllOreESP()
	local placedOre = workspace:FindFirstChild("PlacedOre")
	if not placedOre then return end
	for _, desc in placedOre:GetDescendants() do addOreESP(desc) end
end

OreTab:CreateToggle({
	Name         = "Show Ore ESP",
	Info         = "Highlights all ores in Workspace.PlacedOre through walls",
	CurrentValue = false,
	Flag         = "OreESP",
	Callback     = function(enabled)
		oreESPEnabled = enabled
		if enabled then
			if not workspace:FindFirstChild("PlacedOre") then
				Rayfield:Notify({ Title = "Ore ESP", Content = "PlacedOre not found.", Duration = 4 })
				return
			end
			refreshOreESP()
		else
			clearAllOreESP()
		end
	end,
})

local function setupOreConnections(placedOre)
	track(placedOre.DescendantAdded:Connect(function(desc)
		if oreESPEnabled then addOreESP(desc) end
	end))
	track(placedOre.DescendantRemoving:Connect(function(desc)
		if oreESPEnabled then removeOreESP(desc) end
	end))
	track(RunService.Heartbeat:Connect(function()
		if not oreESPEnabled then return end
		for _, desc in placedOre:GetDescendants() do
			if desc:IsA("BasePart") and not oreAdornments[desc] then
				addOreESP(desc)
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
local TpTab = Window:CreateTab("Teleport", 3926305904)
TpTab:CreateSection("Locations")

local function teleportTo(model)
	local char = LocalPlayer.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	if not model then
		Rayfield:Notify({ Title = "Teleport", Content = "Location not found in workspace.", Duration = 3 })
		return
	end

	local target = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	if not target then
		Rayfield:Notify({ Title = "Teleport", Content = "No valid part found in " .. model.Name, Duration = 3 })
		return
	end

	hrp.CFrame = target.CFrame + Vector3.new(0, 5, 0)
end

TpTab:CreateButton({
	Name     = "Mine",
	Info     = "Teleport to the mine",
	Callback = function()
		teleportTo(workspace:FindFirstChild("CollapseStuff"))
	end,
})

TpTab:CreateButton({
	Name     = "My Plot",
	Info     = "Teleport to your assigned plot",
	Callback = function()
		local plots = workspace:FindFirstChild("Plots")
		if not plots then
			Rayfield:Notify({ Title = "Teleport", Content = "Plots folder not found.", Duration = 3 })
			return
		end

		local myPlot
		for _, plot in plots:GetChildren() do
			local id = plot:GetAttribute("PlayerId")
				or plot:GetAttribute("OwnerId")
				or plot:GetAttribute("Owner")
				or plot:GetAttribute("UserId")
			if id == LocalPlayer.UserId then
				myPlot = plot
				break
			end
		end

		if myPlot then
			teleportTo(myPlot)
		else
			Rayfield:Notify({ Title = "Teleport", Content = "Your plot was not found.\nMake sure you own one.", Duration = 4 })
		end
	end,
})

TpTab:CreateSection("Stores")
for _, storeName in ipairs({ "Explosives Store", "Pickaxe Store", "Backpack Store", "Prestige Store" }) do
	TpTab:CreateButton({
		Name     = storeName,
		Info     = "Teleport to the " .. storeName,
		Callback = function()
			teleportTo(workspace:FindFirstChild(storeName))
		end,
	})
end


-- ══════════════════════════════════════════════════════════════════════════════
--  MISC
-- ══════════════════════════════════════════════════════════════════════════════
local MiscTab = Window:CreateTab("Misc", 4483362458)
MiscTab:CreateSection("Character")

-- ── Walkspeed ──────────────────────────────────────────────────────────────
local DEFAULT_SPEED = 16
local BOOST_SPEED   = 50
local walkBoostOn   = false

local function applyWalkSpeed(speed)
	local char = LocalPlayer.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then hum.WalkSpeed = speed end
end

track(LocalPlayer.CharacterAdded:Connect(function(char)
	local hum = char:WaitForChild("Humanoid", 10)
	if hum and walkBoostOn then
		hum.WalkSpeed = BOOST_SPEED
	end
end))

MiscTab:CreateSlider({
	Name         = "Boost WalkSpeed",
	Info         = "Speed used when the F1 boost toggle is ON",
	Range        = { 16, 250 },
	Increment    = 2,
	Suffix       = " ws",
	CurrentValue = BOOST_SPEED,
	Flag         = "BoostSpeed",
	Callback     = function(value)
		BOOST_SPEED = value
		if walkBoostOn then applyWalkSpeed(BOOST_SPEED) end
	end,
})

MiscTab:CreateToggle({
	Name         = "WalkSpeed Boost  [F1]",
	Info         = "Toggle the speed boost on/off (also bound to F1)",
	CurrentValue = false,
	Flag         = "WalkBoost",
	Callback     = function(enabled)
		walkBoostOn = enabled
		applyWalkSpeed(enabled and BOOST_SPEED or DEFAULT_SPEED)
		Rayfield:Notify({
			Title    = "WalkSpeed",
			Content  = enabled and ("Boost ON  (" .. BOOST_SPEED .. " ws)") or "Boost OFF  (16 ws)",
			Duration = 2,
		})
	end,
})

track(UIS.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.F1 then
		walkBoostOn = not walkBoostOn
		applyWalkSpeed(walkBoostOn and BOOST_SPEED or DEFAULT_SPEED)
		pcall(function() Rayfield.Flags["WalkBoost"]:Set(walkBoostOn) end)
		Rayfield:Notify({
			Title    = "WalkSpeed  [F1]",
			Content  = walkBoostOn and ("Boost ON  (" .. BOOST_SPEED .. " ws)") or "Boost OFF  (16 ws)",
			Duration = 2,
		})
	end
end))

-- ── Refresh Cooldowns ──────────────────────────────────────────────────────
MiscTab:CreateButton({
	Name     = "Refresh Cooldowns",
	Info     = "Kills your character and teleports you back to the same spot",
	Callback = function()
		local char = LocalPlayer.Character
		if not char then return end
		local hrp = char:FindFirstChild("HumanoidRootPart")
		local hum = char:FindFirstChildOfClass("Humanoid")
		if not hrp or not hum then return end

		local savedCFrame = hrp.CFrame
		local conn
		conn = LocalPlayer.CharacterAdded:Connect(function(newChar)
			conn:Disconnect()
			local newHRP = newChar:WaitForChild("HumanoidRootPart", 10)
			if newHRP then
				task.wait(0.2)
				newHRP.CFrame = savedCFrame
			end
		end)

		hum.Health = 0

		Rayfield:Notify({ Title = "Cooldowns Refreshed", Content = "Respawning and teleporting back.", Duration = 3 })
	end,
})


-- ══════════════════════════════════════════════════════════════════════════════
--  AUTO SELL
-- ══════════════════════════════════════════════════════════════════════════════
MiscTab:CreateSection("Auto Sell")

local autoSellEnabled = false
local autoSellThread  = nil
local SELL_INTERVAL   = 60

local function getUnloader()
	local ok, result = pcall(function()
		return workspace.FactoryGridItemsClient.DSBuild3.DSBuild3.Unloader1
	end)
	return ok and result or nil
end

local function pressE()
	VIM:SendKeyEvent(true,  Enum.KeyCode.E, false, game)
	task.wait(0.1)
	VIM:SendKeyEvent(false, Enum.KeyCode.E, false, game)
end

local function doSell()
	local char = LocalPlayer.Character
	if not char then return end
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local unloader = getUnloader()
	if not unloader then
		Rayfield:Notify({ Title = "Auto Sell", Content = "Unloader not found in workspace.", Duration = 3 })
		return
	end

	local sellPart = unloader.PrimaryPart or unloader:FindFirstChildWhichIsA("BasePart")
	if not sellPart then
		Rayfield:Notify({ Title = "Auto Sell", Content = "No BasePart found on Unloader.", Duration = 3 })
		return
	end

	local returnCFrame = hrp.CFrame

	hrp.CFrame = sellPart.CFrame + Vector3.new(0, 4, 0)
	task.wait(0.5)

	pressE()
	task.wait(0.5)

	hrp.CFrame = returnCFrame
end

local function stopAutoSellLoop()
	autoSellEnabled = false
	if autoSellThread then
		task.cancel(autoSellThread)
		autoSellThread = nil
	end
end

local function startAutoSellLoop()
	autoSellThread = task.spawn(function()
		while autoSellEnabled do
			doSell()
			local elapsed = 0
			while elapsed < SELL_INTERVAL and autoSellEnabled do
				task.wait(1)
				elapsed += 1
			end
		end
	end)
end

MiscTab:CreateButton({
	Name     = "Sell Now",
	Info     = "Teleport to the unloader, press E once, and return",
	Callback = function()
		doSell()
	end,
})

MiscTab:CreateSlider({
	Name         = "Sell Interval (seconds)",
	Info         = "How often Auto Sell fires",
	Range        = { 10, 300 },
	Increment    = 5,
	Suffix       = "s",
	CurrentValue = SELL_INTERVAL,
	Flag         = "SellInterval",
	Callback     = function(value)
		SELL_INTERVAL = value
	end,
})

MiscTab:CreateToggle({
	Name         = "Auto Sell",
	Info         = "Automatically sells on the chosen interval",
	CurrentValue = false,
	Flag         = "AutoSell",
	Callback     = function(enabled)
		if enabled then
			autoSellEnabled = true
			startAutoSellLoop()
		else
			stopAutoSellLoop()
		end
	end,
})


-- ══════════════════════════════════════════════════════════════════════════════
--  SETTINGS
-- ══════════════════════════════════════════════════════════════════════════════
local CONFIG_PATH = "MiningESP_config.json"

local function saveConfig()
	local data = {
		oreESPEnabled    = oreESPEnabled,
		autoSellInterval = SELL_INTERVAL,
		boostSpeed       = BOOST_SPEED,
	}
	local ok, err = pcall(function()
		writefile(CONFIG_PATH, HttpService:JSONEncode(data))
	end)
	if ok then
		Rayfield:Notify({ Title = "Config", Content = "Saved successfully.", Duration = 2 })
	else
		Rayfield:Notify({ Title = "Config", Content = "Save failed: " .. tostring(err), Duration = 4 })
	end
end

local function loadConfig()
	if not isfile(CONFIG_PATH) then return end
	local ok, data = pcall(function()
		return HttpService:JSONDecode(readfile(CONFIG_PATH))
	end)
	if not ok or type(data) ~= "table" then return end

	if type(data.oreESPEnabled) == "boolean" then
		pcall(function() Rayfield.Flags["OreESP"]:Set(data.oreESPEnabled) end)
	end

	if type(data.autoSellInterval) == "number" then
		SELL_INTERVAL = data.autoSellInterval
		pcall(function() Rayfield.Flags["SellInterval"]:Set(data.autoSellInterval) end)
	end

	if type(data.boostSpeed) == "number" then
		BOOST_SPEED = data.boostSpeed
		pcall(function() Rayfield.Flags["BoostSpeed"]:Set(data.boostSpeed) end)
	end

	Rayfield:Notify({ Title = "Config", Content = "Settings loaded.", Duration = 2 })
end

local SettingsTab = Window:CreateTab("Settings", 3944680095)
SettingsTab:CreateSection("Config")

SettingsTab:CreateButton({
	Name     = "Save Config",
	Info     = "Saves current toggle and filter settings to file",
	Callback = saveConfig,
})

SettingsTab:CreateSection("Menu")

SettingsTab:CreateButton({
	Name     = "Unload",
	Info     = "Destroys the GUI and disconnects all hooks",
	Callback = function()
		stopAutoSellLoop()
		disconnectAll()
		clearAllOreESP()
		applyWalkSpeed(DEFAULT_SPEED)
		pcall(function() Rayfield:Destroy() end)
	end,
})


-- ══════════════════════════════════════════════════════════════════════════════
--  AUTOLOAD
-- ══════════════════════════════════════════════════════════════════════════════
task.defer(loadConfig)
