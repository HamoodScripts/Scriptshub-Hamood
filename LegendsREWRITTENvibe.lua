-- Sharmoodie Hub v4
-- Place in a LocalScript inside StarterPlayerScripts

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TeleportService  = game:GetService("TeleportService")

local player      = Players.LocalPlayer
local MOB_FOLDER  = workspace.Mobs
local DROP_FOLDER = workspace.Drops
local Camera      = workspace.CurrentCamera

-- ============================================================
-- CONSTANTS
-- ============================================================
local DEFAULT_SPEED = 16
local HACK_SPEED    = 120

local BG_DEEP      = Color3.fromRGB(10,  10,  14)
local BG_PANEL     = Color3.fromRGB(16,  16,  22)
local BG_CARD      = Color3.fromRGB(22,  22,  30)
local BG_ELEMENT   = Color3.fromRGB(28,  28,  38)
local BORDER_COLOR = Color3.fromRGB(40,  40,  58)
local ACCENT_COLOR = Color3.fromRGB(48,  255, 106)
local TEXT_PRIMARY = Color3.fromRGB(235, 235, 245)
local TEXT_MUTED   = Color3.fromRGB(130, 135, 158)
local TEXT_SECTION = Color3.fromRGB(80,  84,  105)

local ESP_TEXT_COLOR = Color3.fromRGB(235, 235, 245)
local ESP_DIST_COLOR = Color3.fromRGB(130, 180, 255)
local ESP_HP_COLOR   = Color3.fromRGB(255, 200, 80)
local ESP_TEXT_SIZE  = 13
local ESP_BOX_THICK  = 1

-- ============================================================
-- STATE
-- ============================================================
local state = {
	guiVisible    = true,
	mobESP        = false,
	autoFarm      = false,
	autoCollect   = false,
	noclip        = false,
	speedHack     = false,
	flyHack       = false,
	selectedMob   = nil,
	farmDistance  = 5,
	flySpeed      = 60,
	attackRate    = 0.3,
	espMaxDist    = 300,
	autoServerhop = false,
	noStun        = false,
}

local uiRefreshCallbacks = {}
local function registerRefresh(fn) table.insert(uiRefreshCallbacks, fn) end
local function refreshAllUI()
	for _, fn in ipairs(uiRefreshCallbacks) do pcall(fn) end
end

-- ============================================================
-- FLY HELPERS
-- ============================================================
local flyBodyVelocity = nil
local flyBodyGyro     = nil

local function enableFly()
	local character = player.Character
	if not character then return end
	local root     = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildWhichIsA("Humanoid")
	if not root or not humanoid then return end
	humanoid.PlatformStand = true
	flyBodyVelocity = Instance.new("BodyVelocity")
	flyBodyVelocity.Velocity = Vector3.zero
	flyBodyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
	flyBodyVelocity.Parent   = root
	flyBodyGyro = Instance.new("BodyGyro")
	flyBodyGyro.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
	flyBodyGyro.D         = 50
	flyBodyGyro.Parent    = root
end

local function disableFly()
	local character = player.Character
	if character then
		local humanoid = character:FindFirstChildWhichIsA("Humanoid")
		if humanoid then humanoid.PlatformStand = false end
	end
	if flyBodyVelocity then flyBodyVelocity:Destroy(); flyBodyVelocity = nil end
	if flyBodyGyro     then flyBodyGyro:Destroy();     flyBodyGyro     = nil end
end

local function getFlyDirection()
	local cam     = workspace.CurrentCamera
	local moveDir = Vector3.zero
	if UserInputService:IsKeyDown(Enum.KeyCode.W)           then moveDir += cam.CFrame.LookVector  end
	if UserInputService:IsKeyDown(Enum.KeyCode.S)           then moveDir -= cam.CFrame.LookVector  end
	if UserInputService:IsKeyDown(Enum.KeyCode.A)           then moveDir -= cam.CFrame.RightVector end
	if UserInputService:IsKeyDown(Enum.KeyCode.D)           then moveDir += cam.CFrame.RightVector end
	if UserInputService:IsKeyDown(Enum.KeyCode.Space)       then moveDir += Vector3.new(0, 1, 0)   end
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then moveDir -= Vector3.new(0, 1, 0)   end
	return moveDir.Magnitude > 0 and moveDir.Unit or Vector3.zero
end

-- ============================================================
-- MOB ESP
-- ============================================================
local espData = {}

local function healthColor(ratio)
	local r = ratio >= 0.5 and math.floor(255 * (1 - ratio) * 2) or 255
	local g = ratio >= 0.5 and 255 or math.floor(255 * ratio * 2)
	return Color3.fromRGB(r, g, 0)
end

local function makeCornerBox(color)
	local box = {}
	for _, n in ipairs({"TL_H","TL_V","TR_H","TR_V","BL_H","BL_V","BR_H","BR_V"}) do
		local ln = Drawing.new("Line")
		ln.Visible   = false
		ln.Color     = color
		ln.Thickness = ESP_BOX_THICK
		box[n] = ln
	end
	return box
end

local function addESP(mob)
	if espData[mob] then return end
	if not mob:IsA("Model") then return end

	local hbOutline = Drawing.new("Square")
	hbOutline.Visible      = false
	hbOutline.Color        = Color3.fromRGB(0, 0, 0)
	hbOutline.Filled       = true
	hbOutline.Transparency = 0.5

	local hbFill = Drawing.new("Square")
	hbFill.Visible = false
	hbFill.Filled  = true
	hbFill.Color   = Color3.fromRGB(48, 255, 106)

	local nameText = Drawing.new("Text")
	nameText.Visible      = false
	nameText.Center       = true
	nameText.Outline      = true
	nameText.OutlineColor = Color3.fromRGB(0, 0, 0)
	nameText.Size         = ESP_TEXT_SIZE
	nameText.Font         = 2
	nameText.Color        = ESP_TEXT_COLOR

	local distText = Drawing.new("Text")
	distText.Visible      = false
	distText.Center       = true
	distText.Outline      = true
	distText.OutlineColor = Color3.fromRGB(0, 0, 0)
	distText.Size         = ESP_TEXT_SIZE - 2
	distText.Font         = 2
	distText.Color        = ESP_DIST_COLOR

	local hpText = Drawing.new("Text")
	hpText.Visible      = false
	hpText.Center       = true
	hpText.Outline      = true
	hpText.OutlineColor = Color3.fromRGB(0, 0, 0)
	hpText.Size         = ESP_TEXT_SIZE - 2
	hpText.Font         = 2
	hpText.Color        = ESP_HP_COLOR

	espData[mob] = {
		box       = makeCornerBox(Color3.fromRGB(48, 255, 106)),
		hbOutline = hbOutline,
		hbFill    = hbFill,
		nameText  = nameText,
		distText  = distText,
		hpText    = hpText,
	}
end

local function removeESP(mob)
	local d = espData[mob]
	if not d then return end
	for _, ln in pairs(d.box) do ln:Remove() end
	d.hbOutline:Remove()
	d.hbFill:Remove()
	d.nameText:Remove()
	d.distText:Remove()
	d.hpText:Remove()
	espData[mob] = nil
end

local function hideESP(d)
	for _, ln in pairs(d.box) do ln.Visible = false end
	d.hbOutline.Visible = false
	d.hbFill.Visible    = false
	d.nameText.Visible  = false
	d.distText.Visible  = false
	d.hpText.Visible    = false
end

local function updateCornerBox(box, bPos, bSize, color)
	local cs = math.max(bSize.X, bSize.Y) * 0.2
	box.TL_H.From = bPos;                                 box.TL_H.To = bPos + Vector2.new(cs, 0)
	box.TL_V.From = bPos;                                 box.TL_V.To = bPos + Vector2.new(0, cs)
	box.TR_H.From = bPos + Vector2.new(bSize.X, 0);       box.TR_H.To = bPos + Vector2.new(bSize.X - cs, 0)
	box.TR_V.From = bPos + Vector2.new(bSize.X, 0);       box.TR_V.To = bPos + Vector2.new(bSize.X, cs)
	box.BL_H.From = bPos + Vector2.new(0, bSize.Y);       box.BL_H.To = bPos + Vector2.new(cs, bSize.Y)
	box.BL_V.From = bPos + Vector2.new(0, bSize.Y);       box.BL_V.To = bPos + Vector2.new(0, bSize.Y - cs)
	box.BR_H.From = bPos + Vector2.new(bSize.X, bSize.Y); box.BR_H.To = bPos + Vector2.new(bSize.X - cs, bSize.Y)
	box.BR_V.From = bPos + Vector2.new(bSize.X, bSize.Y); box.BR_V.To = bPos + Vector2.new(bSize.X, bSize.Y - cs)
	for _, ln in pairs(box) do ln.Color = color; ln.Visible = true end
end

-- ============================================================
-- HEALTH READING HELPER
-- ============================================================
local function getMobHealth(mob)
	local hpVal  = mob:FindFirstChild("Health")
	local maxVal = mob:FindFirstChild("MaxHealth")

	local curHP = hpVal  and (type(hpVal.Value)  == "number") and hpVal.Value  or nil
	local maxHP = maxVal and (type(maxVal.Value) == "number") and maxVal.Value or nil

	if curHP == nil or maxHP == nil then
		local hum = mob:FindFirstChildWhichIsA("Humanoid")
		if hum then
			if curHP == nil then curHP = hum.Health    end
			if maxHP == nil then maxHP = hum.MaxHealth end
		end
	end

	curHP = curHP or 0
	maxHP = (maxHP and maxHP > 0) and maxHP or 1
	return curHP, maxHP
end

local function updateESP(mob, d, playerRoot)
	local mobRoot = mob:FindFirstChild("HumanoidRootPart") or mob:FindFirstChildWhichIsA("BasePart")
	if not mobRoot then hideESP(d); return end

	local cf   = mobRoot.CFrame
	local size = mob:GetExtentsSize()
	local topScreen,    topVis    = Camera:WorldToViewportPoint(cf.Position + Vector3.new(0,  size.Y / 2, 0))
	local bottomScreen, bottomVis = Camera:WorldToViewportPoint(cf.Position + Vector3.new(0, -size.Y / 2, 0))
	if not topVis or not bottomVis or topScreen.Z <= 0 then hideESP(d); return end

	local screenH = bottomScreen.Y - topScreen.Y
	if screenH <= 2 then hideESP(d); return end

	local screenW = screenH * 0.65
	local bPos    = Vector2.new(topScreen.X - screenW / 2, topScreen.Y)
	local bSize   = Vector2.new(screenW, screenH)
	local dist    = math.floor((playerRoot.Position - mobRoot.Position).Magnitude)
	if dist > state.espMaxDist then hideESP(d); return end

	local boxColor
	if dist < 30     then boxColor = Color3.fromRGB(48,  255, 106)
	elseif dist < 80 then boxColor = Color3.fromRGB(255, 220, 50)
	else                  boxColor = Color3.fromRGB(239, 79,  29)
	end
	updateCornerBox(d.box, bPos, bSize, boxColor)

	local curHP, maxHP = getMobHealth(mob)
	local ratio = math.clamp(curHP / maxHP, 0, 1)

	local barW = math.max(4, screenW * 0.10)
	local barH = screenH

	d.hbOutline.Size     = Vector2.new(barW,     barH)
	d.hbOutline.Position = Vector2.new(bPos.X - barW - 3, bPos.Y)
	d.hbOutline.Visible  = true

	local fillH = math.max(1, (barH - 2) * ratio)
	d.hbFill.Color    = healthColor(ratio)
	d.hbFill.Size     = Vector2.new(barW - 2, fillH)
	d.hbFill.Position = Vector2.new(bPos.X - barW - 2, bPos.Y + 1 + (barH - 2) - fillH)
	d.hbFill.Visible  = true

	d.nameText.Text     = mob.Name
	d.nameText.Position = Vector2.new(bPos.X + screenW / 2, bPos.Y - ESP_TEXT_SIZE - 2)
	d.nameText.Visible  = true

	d.distText.Text     = dist .. " studs"
	d.distText.Position = Vector2.new(bPos.X + screenW / 2, bPos.Y + screenH + 2)
	d.distText.Visible  = true

	d.hpText.Text     = math.floor(curHP) .. "/" .. math.floor(maxHP)
	d.hpText.Position = Vector2.new(bPos.X + screenW / 2, bPos.Y + screenH + 2 + (ESP_TEXT_SIZE - 1))
	d.hpText.Visible  = true
end

MOB_FOLDER.ChildAdded:Connect(function(mob)
	if state.mobESP and mob:IsA("Model") then addESP(mob) end
end)
MOB_FOLDER.ChildRemoved:Connect(removeESP)

-- ============================================================
-- TARGETING HELPERS
-- ============================================================
local function getMobGroupName(name)
	local group = (name:match("^(.-)%s*%d+$") or name):match("^%s*(.-)%s*$")
	if not group or group == "" then group = name end
	return group
end

local function getTargetMob()
	local character = player.Character
	if not character then return nil end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	local nearest, shortestDist = nil, math.huge
	for _, mob in ipairs(MOB_FOLDER:GetChildren()) do
		if mob:IsA("Model") then
			local groupName = getMobGroupName(mob.Name)
			local nameMatch = state.selectedMob == nil or groupName == state.selectedMob
			if nameMatch then
				local mobRoot = mob:FindFirstChild("HumanoidRootPart") or mob:FindFirstChildWhichIsA("BasePart")
				if mobRoot then
					local dist = (root.Position - mobRoot.Position).Magnitude
					if dist < shortestDist then shortestDist = dist; nearest = mobRoot end
				end
			end
		end
	end
	return nearest
end

DROP_FOLDER.ChildAdded:Connect(function(drop)
	if not state.autoCollect then return end
	task.wait(0.3)
	local x, y, z = drop:FindFirstChild("x"), drop:FindFirstChild("y"), drop:FindFirstChild("z")
	if x and y and z then
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then root.CFrame = CFrame.new(Vector3.new(x.Value, y.Value, z.Value)) end
	end
end)

-- ============================================================
-- CONFIG SYSTEM
-- ============================================================
local CONFIG_FOLDER = "sharmoodie_configs"
local AUTOLOAD_FILE = CONFIG_FOLDER .. "/autoload.txt"

local CONFIG_KEYS = {
	"mobESP", "autoFarm", "autoCollect", "noclip",
	"speedHack", "flyHack", "selectedMob",
	"farmDistance", "flySpeed", "attackRate",
	"espMaxDist", "noStun", "autoServerhop",
}

local function ensureFolder()
	local ok = pcall(function()
		if not isfolder(CONFIG_FOLDER) then makefolder(CONFIG_FOLDER) end
	end)
	return ok
end

local function serializeState()
	local parts = {}
	for _, k in ipairs(CONFIG_KEYS) do
		local v = state[k]
		local encoded
		if v == nil then
			encoded = "null"
		elseif type(v) == "boolean" then
			encoded = v and "true" or "false"
		elseif type(v) == "number" then
			encoded = tostring(v)
		elseif type(v) == "string" then
			encoded = '"' .. v:gsub('\\','\\\\'):gsub('"','\\"') .. '"'
		else
			encoded = "null"
		end
		table.insert(parts, '"' .. k .. '":' .. encoded)
	end
	return "{" .. table.concat(parts, ",") .. "}"
end

local function deserializeJSON(s)
	local t = {}
	for k in s:gmatch('"([^"]+)":true') do  t[k] = true  end
	for k in s:gmatch('"([^"]+)":false') do t[k] = false end
	for k, v in s:gmatch('"([^"]+)":(%-?%d+%.?%d*)') do
		if t[k] == nil then t[k] = tonumber(v) end
	end
	for k, v in s:gmatch('"([^"]+)":"([^"]*)"') do
		if t[k] == nil then t[k] = v end
	end
	return t
end

local function saveConfig(name)
	if not ensureFolder() then return false, "Filesystem unavailable" end
	local path = CONFIG_FOLDER .. "/" .. name .. ".json"
	local ok, err = pcall(writefile, path, serializeState())
	if ok then return true,  "Config saved: " .. name
	       else return false, "Save failed: " .. tostring(err) end
end

local function readConfig(name)
	if not ensureFolder() then return nil, "Filesystem unavailable" end
	local path = CONFIG_FOLDER .. "/" .. name .. ".json"
	local ok, data = pcall(readfile, path)
	if not ok or not data or data == "" then
		return nil, "Config not found: " .. name
	end
	return deserializeJSON(data), nil
end

local function applyConfig(t)
	for _, k in ipairs(CONFIG_KEYS) do
		if t[k] ~= nil then state[k] = t[k] end
	end
end

local function setAutoload(name)
	if not ensureFolder() then return false end
	return pcall(writefile, AUTOLOAD_FILE, name)
end

local function clearAutoload()
	if not ensureFolder() then return end
	pcall(writefile, AUTOLOAD_FILE, "")
end

local function getAutoload()
	local ok, data = pcall(readfile, AUTOLOAD_FILE)
	if ok and data and data ~= "" then
		return (data:match("^%s*(.-)%s*$"))
	end
	return nil
end

local function listConfigs()
	local names = {}
	if not ensureFolder() then return names end
	local ok, files = pcall(listfiles, CONFIG_FOLDER)
	if ok and files then
		for _, path in ipairs(files) do
			local name = path:match("[/\\]([^/\\]+)%.json$") or path:match("^([^/\\]+)%.json$")
			if name then table.insert(names, name) end
		end
	end
	return names
end

-- ============================================================
-- STATUS BAR
-- ============================================================
local statusLabel
local function setStatus(msg)
	if statusLabel then
		statusLabel.Text = msg
		task.delay(3, function()
			if statusLabel.Text == msg then statusLabel.Text = "ready" end
		end)
	end
end

-- ============================================================
-- SERVERHOP
-- ============================================================
local isHopping = false
local MAX_HOP_ATTEMPTS = 5
local HOP_RETRY_DELAY  = 4

local function doServerhop()
	if isHopping then return end
	isHopping = true

	pcall(function()
		if queue_on_teleport then
			local src
			for _, fname in ipairs({"sharmoodie.lua","Sharmoodie.lua","SharmoodieHub.lua"}) do
				local ok, content = pcall(readfile, fname)
				if ok and content and #content > 100 then src = content; break end
			end
			if src then queue_on_teleport(src) end
		end
	end)

	task.spawn(function()
		local attempt = 0

		local function tryHop()
			attempt += 1
			setStatus("Hopping... (attempt " .. attempt .. "/" .. MAX_HOP_ATTEMPTS .. ")")

			local ok = pcall(function()
				local currentJobId = game.JobId
				local maxPlayers   = Players.MaxPlayers

				local response = game:HttpGetAsync(
					"https://games.roblox.com/v1/games/" .. game.PlaceId ..
					"/servers/Public?sortOrder=Asc&limit=100"
				)

				local servers = {}
				for jobId, rest in response:gmatch('"id":"([^"]+)"(.-)%}') do
					if jobId ~= currentJobId then
						local playing = tonumber(rest:match('"playing":(%d+)'))
						local isFull  = playing and playing >= maxPlayers
						if not isFull then
							table.insert(servers, jobId)
						end
					end
				end

				if #servers == 0 then
					if attempt < MAX_HOP_ATTEMPTS then
						setStatus("All servers full, retrying in " .. HOP_RETRY_DELAY .. "s...")
						task.wait(HOP_RETRY_DELAY)
						tryHop()
					else
						setStatus("Hop failed: all servers full after " .. attempt .. " attempts")
						isHopping = false
					end
					return
				end

				local chosen = servers[math.random(1, #servers)]
				task.wait(0.5)

				-- ── FIX: listen for teleport failure so we know if the server
				--         was full between listing and actually joining it.
				local teleportConn
				teleportConn = TeleportService.TeleportInitFailed:Connect(function(plr, result, _errMsg)
					if plr ~= player then return end
					teleportConn:Disconnect()
					setStatus("Teleport failed (" .. tostring(result) .. "), retrying in " .. HOP_RETRY_DELAY .. "s...")
					task.wait(HOP_RETRY_DELAY)
					if attempt < MAX_HOP_ATTEMPTS then
						-- Reset flag so the recursive tryHop call is not blocked
						isHopping = false
						isHopping = true
						tryHop()
					else
						setStatus("Hop failed after " .. attempt .. " attempts")
						isHopping = false
					end
				end)

				-- Safety net: if neither success nor TeleportInitFailed fires within
				-- 12 seconds, something stalled — reset so the loop can retry.
				task.delay(12, function()
					if teleportConn.Connected then
						teleportConn:Disconnect()
						setStatus("Teleport timed out, retrying...")
						isHopping = false
					end
				end)

				TeleportService:TeleportToPlaceInstance(game.PlaceId, chosen, player)
			end)

			if not ok then
				if attempt < MAX_HOP_ATTEMPTS then
					setStatus("Hop error, retrying in " .. HOP_RETRY_DELAY .. "s...")
					task.wait(HOP_RETRY_DELAY)
					tryHop()
				else
					setStatus("Hop failed after " .. attempt .. " attempts, using fallback...")
					pcall(function() TeleportService:Teleport(game.PlaceId, player) end)
					task.wait(3)
					isHopping = false
				end
			end
		end

		tryHop()
	end)
end

-- ============================================================
-- GUI SETUP
-- ============================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "SharmoodieHub"
screenGui.ResetOnSpawn   = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent         = player.PlayerGui

local shadow = Instance.new("Frame")
shadow.Size             = UDim2.new(0, 268, 0, 580)
shadow.Position         = UDim2.new(0, 8, 0.5, -290)
shadow.BackgroundColor3 = BG_DEEP
shadow.BorderSizePixel  = 0
shadow.Active           = true
shadow.Draggable        = true
shadow.Parent           = screenGui
Instance.new("UICorner", shadow).CornerRadius = UDim.new(0, 12)

local mainFrame = Instance.new("Frame")
mainFrame.Size             = UDim2.new(1, -2, 1, -2)
mainFrame.Position         = UDim2.new(0, 1, 0, 1)
mainFrame.BackgroundColor3 = BG_PANEL
mainFrame.BorderSizePixel  = 0
mainFrame.Parent           = shadow
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 11)

local topBar = Instance.new("Frame")
topBar.Size             = UDim2.new(1, 0, 0, 48)
topBar.BackgroundColor3 = BG_CARD
topBar.BorderSizePixel  = 0
topBar.Parent           = mainFrame
Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 11)

local topBarSquare = Instance.new("Frame")
topBarSquare.Size             = UDim2.new(1, 0, 0, 12)
topBarSquare.Position         = UDim2.new(0, 0, 1, -12)
topBarSquare.BackgroundColor3 = BG_CARD
topBarSquare.BorderSizePixel  = 0
topBarSquare.Parent           = topBar

local accentDot = Instance.new("Frame")
accentDot.Size             = UDim2.new(0, 8, 0, 8)
accentDot.Position         = UDim2.new(0, 14, 0.5, -4)
accentDot.BackgroundColor3 = ACCENT_COLOR
accentDot.BorderSizePixel  = 0
accentDot.Parent           = topBar
Instance.new("UICorner", accentDot).CornerRadius = UDim.new(1, 0)

local titleLabel = Instance.new("TextLabel")
titleLabel.Size               = UDim2.new(1, -90, 1, 0)
titleLabel.Position           = UDim2.new(0, 30, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.TextColor3         = TEXT_PRIMARY
titleLabel.TextScaled         = false
titleLabel.TextSize           = 14
titleLabel.Font               = Enum.Font.GothamBold
titleLabel.Text               = "SHARMOODIE"
titleLabel.TextXAlignment     = Enum.TextXAlignment.Left
titleLabel.Parent             = topBar

local keyBadge = Instance.new("TextLabel")
keyBadge.Size               = UDim2.new(0, 58, 0, 22)
keyBadge.Position           = UDim2.new(1, -66, 0.5, -11)
keyBadge.BackgroundColor3   = BG_ELEMENT
keyBadge.BorderSizePixel    = 0
keyBadge.TextColor3         = TEXT_MUTED
keyBadge.TextScaled         = false
keyBadge.TextSize           = 11
keyBadge.Font               = Enum.Font.GothamBold
keyBadge.Text               = "RAlt"
keyBadge.Parent             = topBar
Instance.new("UICorner", keyBadge).CornerRadius = UDim.new(0, 6)

local sep = Instance.new("Frame")
sep.Size             = UDim2.new(1, -24, 0, 1)
sep.Position         = UDim2.new(0, 12, 0, 48)
sep.BackgroundColor3 = BORDER_COLOR
sep.BorderSizePixel  = 0
sep.Parent           = mainFrame

local statusBar = Instance.new("Frame")
statusBar.Size             = UDim2.new(1, 0, 0, 28)
statusBar.Position         = UDim2.new(0, 0, 1, -28)
statusBar.BackgroundColor3 = BG_CARD
statusBar.BorderSizePixel  = 0
statusBar.Parent           = mainFrame
Instance.new("UICorner", statusBar).CornerRadius = UDim.new(0, 11)

local statusSquare = Instance.new("Frame")
statusSquare.Size             = UDim2.new(1, 0, 0, 12)
statusSquare.Position         = UDim2.new(0, 0, 0, 0)
statusSquare.BackgroundColor3 = BG_CARD
statusSquare.BorderSizePixel  = 0
statusSquare.Parent           = statusBar

local statusDot = Instance.new("Frame")
statusDot.Size             = UDim2.new(0, 6, 0, 6)
statusDot.Position         = UDim2.new(0, 12, 0.5, -3)
statusDot.BackgroundColor3 = ACCENT_COLOR
statusDot.BorderSizePixel  = 0
statusDot.Parent           = statusBar
Instance.new("UICorner", statusDot).CornerRadius = UDim.new(1, 0)

statusLabel = Instance.new("TextLabel")
statusLabel.Size               = UDim2.new(1, -28, 1, 0)
statusLabel.Position           = UDim2.new(0, 24, 0, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.TextColor3         = TEXT_MUTED
statusLabel.TextScaled         = false
statusLabel.TextSize           = 11
statusLabel.Font               = Enum.Font.Gotham
statusLabel.Text               = "Sharmoodie"
statusLabel.TextXAlignment     = Enum.TextXAlignment.Left
statusLabel.Parent             = statusBar

local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size                = UDim2.new(1, -8, 1, -84)
scrollFrame.Position            = UDim2.new(0, 4, 0, 54)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel     = 0
scrollFrame.ScrollBarThickness  = 2
scrollFrame.ScrollBarImageColor3 = ACCENT_COLOR
scrollFrame.CanvasSize          = UDim2.new(0, 0, 0, 0)
scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollFrame.Parent              = mainFrame

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 4)
listLayout.Parent  = scrollFrame

local listPadding = Instance.new("UIPadding")
listPadding.PaddingLeft   = UDim.new(0, 4)
listPadding.PaddingRight  = UDim.new(0, 4)
listPadding.PaddingTop    = UDim.new(0, 6)
listPadding.PaddingBottom = UDim.new(0, 6)
listPadding.Parent        = scrollFrame

-- ============================================================
-- GUI HELPERS
-- ============================================================
local function makeSection(text)
	local row = Instance.new("Frame")
	row.Size             = UDim2.new(1, 0, 0, 28)
	row.BackgroundTransparency = 1
	row.Parent           = scrollFrame
	local lline = Instance.new("Frame")
	lline.Size             = UDim2.new(0, 18, 0, 1)
	lline.Position         = UDim2.new(0, 0, 0.5, 0)
	lline.BackgroundColor3 = BORDER_COLOR
	lline.BorderSizePixel  = 0
	lline.Parent           = row
	local lbl = Instance.new("TextLabel")
	lbl.Size               = UDim2.new(1, -44, 1, 0)
	lbl.Position           = UDim2.new(0, 22, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3         = TEXT_SECTION
	lbl.TextScaled         = false
	lbl.TextSize           = 11
	lbl.Font               = Enum.Font.GothamBold
	lbl.Text               = text:upper()
	lbl.TextXAlignment     = Enum.TextXAlignment.Left
	lbl.Parent             = row
	return row
end

local function makeToggle(label, stateKey, onToggle, keySuffix)
	local card = Instance.new("Frame")
	card.Size             = UDim2.new(1, 0, 0, 40)
	card.BackgroundColor3 = BG_CARD
	card.BorderSizePixel  = 0
	card.Parent           = scrollFrame
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

	local stripe = Instance.new("Frame")
	stripe.Size             = UDim2.new(0, 3, 0.6, 0)
	stripe.Position         = UDim2.new(0, 0, 0.2, 0)
	stripe.BackgroundColor3 = ACCENT_COLOR
	stripe.BorderSizePixel  = 0
	stripe.Visible          = false
	stripe.Parent           = card
	Instance.new("UICorner", stripe).CornerRadius = UDim.new(0, 2)

	local lbl = Instance.new("TextLabel")
	lbl.Size               = UDim2.new(1, -70, 1, 0)
	lbl.Position           = UDim2.new(0, 14, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3         = TEXT_MUTED
	lbl.TextScaled         = false
	lbl.TextSize           = 13
	lbl.Font               = Enum.Font.Gotham
	lbl.Text               = label .. (keySuffix and ("  [" .. keySuffix .. "]") or "")
	lbl.TextXAlignment     = Enum.TextXAlignment.Left
	lbl.Parent             = card

	local track = Instance.new("Frame")
	track.Size             = UDim2.new(0, 36, 0, 18)
	track.Position         = UDim2.new(1, -46, 0.5, -9)
	track.BackgroundColor3 = BG_ELEMENT
	track.BorderSizePixel  = 0
	track.Parent           = card
	Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

	local knob = Instance.new("Frame")
	knob.Size             = UDim2.new(0, 12, 0, 12)
	knob.Position         = UDim2.new(0, 3, 0.5, -6)
	knob.BackgroundColor3 = TEXT_MUTED
	knob.BorderSizePixel  = 0
	knob.Parent           = track
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

	local function refresh()
		local on = state[stateKey]
		track.BackgroundColor3 = on and ACCENT_COLOR or BG_ELEMENT
		knob.Position          = on and UDim2.new(1, -15, 0.5, -6) or UDim2.new(0, 3, 0.5, -6)
		knob.BackgroundColor3  = on and Color3.fromRGB(10, 10, 14) or TEXT_MUTED
		lbl.TextColor3         = on and TEXT_PRIMARY or TEXT_MUTED
		stripe.Visible         = on
	end

	registerRefresh(refresh)

	local btn = Instance.new("TextButton")
	btn.Size             = UDim2.new(1, 0, 1, 0)
	btn.BackgroundTransparency = 1
	btn.Text             = ""
	btn.Parent           = card
	btn.MouseButton1Click:Connect(function()
		state[stateKey] = not state[stateKey]
		refresh()
		if onToggle then onToggle(state[stateKey]) end
		setStatus(label .. (state[stateKey] and ": ON" or ": OFF"))
	end)

	refresh()
	return { refresh = refresh }
end

local function makeSlider(labelText, minVal, maxVal, defaultVal, stateKey, onChange)
	local card = Instance.new("Frame")
	card.Size             = UDim2.new(1, 0, 0, 56)
	card.BackgroundColor3 = BG_CARD
	card.BorderSizePixel  = 0
	card.Parent           = scrollFrame
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

	local lbl = Instance.new("TextLabel")
	lbl.Size               = UDim2.new(1, -60, 0, 22)
	lbl.Position           = UDim2.new(0, 12, 0, 4)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3         = TEXT_MUTED
	lbl.TextScaled         = false
	lbl.TextSize           = 12
	lbl.Font               = Enum.Font.Gotham
	lbl.Text               = labelText
	lbl.TextXAlignment     = Enum.TextXAlignment.Left
	lbl.Parent             = card

	local valPill = Instance.new("TextLabel")
	valPill.Size               = UDim2.new(0, 48, 0, 20)
	valPill.Position           = UDim2.new(1, -56, 0, 5)
	valPill.BackgroundColor3   = BG_ELEMENT
	valPill.BorderSizePixel    = 0
	valPill.TextColor3         = ACCENT_COLOR
	valPill.TextScaled         = false
	valPill.TextSize           = 12
	valPill.Font               = Enum.Font.GothamBold
	valPill.Text               = tostring(defaultVal)
	valPill.Parent             = card
	Instance.new("UICorner", valPill).CornerRadius = UDim.new(0, 6)

	local track = Instance.new("Frame")
	track.Size             = UDim2.new(1, -24, 0, 4)
	track.Position         = UDim2.new(0, 12, 0, 36)
	track.BackgroundColor3 = BG_ELEMENT
	track.BorderSizePixel  = 0
	track.Parent           = card
	Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)

	local fill = Instance.new("Frame")
	fill.Size             = UDim2.new((defaultVal - minVal) / (maxVal - minVal), 0, 1, 0)
	fill.BackgroundColor3 = ACCENT_COLOR
	fill.BorderSizePixel  = 0
	fill.Parent           = track
	Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

	local knob = Instance.new("TextButton")
	knob.Size             = UDim2.new(0, 14, 0, 14)
	knob.AnchorPoint      = Vector2.new(0.5, 0.5)
	knob.Position         = UDim2.new((defaultVal - minVal) / (maxVal - minVal), 0, 0.5, 0)
	knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	knob.Text             = ""
	knob.BorderSizePixel  = 0
	knob.Parent           = track
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

	local function refresh()
		local cur = stateKey and state[stateKey] or defaultVal
		if type(cur) ~= "number" then cur = defaultVal end
		local relX = math.clamp((cur - minVal) / (maxVal - minVal), 0, 1)
		fill.Size     = UDim2.new(relX, 0, 1, 0)
		knob.Position = UDim2.new(relX, 0, 0.5, 0)
		valPill.Text  = tostring(math.floor(cur))
	end

	registerRefresh(refresh)

	local dragging = false
	knob.MouseButton1Down:Connect(function() dragging = true end)
	UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
	end)
	RunService.RenderStepped:Connect(function()
		if not dragging then return end
		local mouse = player:GetMouse()
		local relX  = math.clamp((mouse.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		local val   = math.floor(minVal + relX * (maxVal - minVal))
		fill.Size     = UDim2.new(relX, 0, 1, 0)
		knob.Position = UDim2.new(relX, 0, 0.5, 0)
		valPill.Text  = tostring(val)
		if stateKey then state[stateKey] = val end
		if onChange  then onChange(val) end
	end)
end

local function makeMobList()
	local card = Instance.new("Frame")
	card.Size             = UDim2.new(1, 0, 0, 136)
	card.BackgroundColor3 = BG_CARD
	card.BorderSizePixel  = 0
	card.Parent           = scrollFrame
	Instance.new("UICorner", card).CornerRadius = UDim.new(0, 8)

	local listTitle = Instance.new("TextLabel")
	listTitle.Size               = UDim2.new(1, -12, 0, 22)
	listTitle.Position           = UDim2.new(0, 12, 0, 6)
	listTitle.BackgroundTransparency = 1
	listTitle.TextColor3         = TEXT_MUTED
	listTitle.TextScaled         = false
	listTitle.TextSize           = 11
	listTitle.Font               = Enum.Font.GothamBold
	listTitle.Text               = "TARGET MOB"
	listTitle.TextXAlignment     = Enum.TextXAlignment.Left
	listTitle.Parent             = card

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size                = UDim2.new(1, -12, 1, -36)
	scroll.Position            = UDim2.new(0, 6, 0, 30)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel     = 0
	scroll.ScrollBarThickness  = 2
	scroll.ScrollBarImageColor3 = ACCENT_COLOR
	scroll.CanvasSize          = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent              = card
	Instance.new("UIListLayout", scroll).Padding = UDim.new(0, 3)

	local mobButtons = {}
	local seen = {}

	local function makeChip(parent, text, isSelected, onClick)
		local chip = Instance.new("TextButton")
		chip.Size             = UDim2.new(1, 0, 0, 26)
		chip.BackgroundColor3 = isSelected and ACCENT_COLOR or BG_ELEMENT
		chip.TextColor3       = isSelected and BG_DEEP or TEXT_MUTED
		chip.TextScaled       = false
		chip.TextSize         = 12
		chip.Font             = isSelected and Enum.Font.GothamBold or Enum.Font.Gotham
		chip.Text             = text
		chip.BorderSizePixel  = 0
		chip.Parent           = parent
		Instance.new("UICorner", chip).CornerRadius = UDim.new(0, 6)
		chip.MouseButton1Click:Connect(onClick)
		return chip
	end

	local function refreshList()
		for _, b in ipairs(mobButtons) do b:Destroy() end
		mobButtons = {}; seen = {}
		local anyBtn = makeChip(scroll, "⚡  Any / Nearest", state.selectedMob == nil, function()
			state.selectedMob = nil
			for _, b in ipairs(mobButtons) do
				b.BackgroundColor3 = BG_ELEMENT; b.TextColor3 = TEXT_MUTED; b.Font = Enum.Font.Gotham
			end
			if mobButtons[1] then
				mobButtons[1].BackgroundColor3 = ACCENT_COLOR
				mobButtons[1].TextColor3       = BG_DEEP
				mobButtons[1].Font             = Enum.Font.GothamBold
			end
			setStatus("Target: Any")
		end)
		table.insert(mobButtons, anyBtn)
		for _, mob in ipairs(MOB_FOLDER:GetChildren()) do
			if mob:IsA("Model") then
				local groupName = getMobGroupName(mob.Name)
				if not seen[groupName] then
					seen[groupName] = true
					local isSelected = state.selectedMob == groupName
					local btn = makeChip(scroll, groupName, isSelected, function()
						state.selectedMob = groupName
						for _, b in ipairs(mobButtons) do
							b.BackgroundColor3 = BG_ELEMENT; b.TextColor3 = TEXT_MUTED; b.Font = Enum.Font.Gotham
						end
						for _, b in ipairs(mobButtons) do
							if b.Text == groupName then
								b.BackgroundColor3 = ACCENT_COLOR; b.TextColor3 = BG_DEEP; b.Font = Enum.Font.GothamBold
							end
						end
						setStatus("Target: " .. groupName)
					end)
					table.insert(mobButtons, btn)
				end
			end
		end
	end

	local refreshBtn = Instance.new("TextButton")
	refreshBtn.Size             = UDim2.new(1, 0, 0, 30)
	refreshBtn.BackgroundColor3 = BG_CARD
	refreshBtn.TextColor3       = TEXT_MUTED
	refreshBtn.TextScaled       = false
	refreshBtn.TextSize         = 12
	refreshBtn.Font             = Enum.Font.Gotham
	refreshBtn.Text             = "🔄  Refresh Mob List"
	refreshBtn.BorderSizePixel  = 0
	refreshBtn.Parent           = scrollFrame
	Instance.new("UICorner", refreshBtn).CornerRadius = UDim.new(0, 8)
	refreshBtn.MouseButton1Click:Connect(function() refreshList(); setStatus("Mob list refreshed") end)
	MOB_FOLDER.ChildAdded:Connect(function()   task.wait(0.5); refreshList() end)
	MOB_FOLDER.ChildRemoved:Connect(function() task.wait(0.5); refreshList() end)
	refreshList()
end

-- ============================================================
-- BUILD GUI
-- ============================================================
makeSection("Combat")
makeToggle("Mob ESP", "mobESP", function(on)
	if on then
		for _, mob in ipairs(MOB_FOLDER:GetChildren()) do
			if mob:IsA("Model") then addESP(mob) end
		end
	else
		for mob in pairs(espData) do removeESP(mob) end
	end
end)
makeSlider("ESP Distance",      20,   1000, 300, "espMaxDist")
makeToggle("Auto Farm",         "autoFarm",  nil)
makeToggle("No Stun",           "noStun", function(on)
	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChildWhichIsA("Humanoid")
	if not humanoid then return end
	humanoid:SetStateEnabled(Enum.HumanoidStateType.StrafingNoPhysics, not on)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding,  not on)
end)
makeMobList()
makeSlider("Farm Distance",      2,    30,   5,  "farmDistance")
makeSlider("Attack Rate (x10)",  1,    20,   3,  nil, function(v) state.attackRate = v / 10 end)

makeSection("Drops")
makeToggle("Auto Collect",    "autoCollect",   nil)
makeToggle("Auto Serverhop",  "autoServerhop", function(on)
	setStatus("Auto Serverhop: " .. (on and "ON - watching drops" or "OFF"))
end)

do
	local hopBtn = Instance.new("TextButton")
	hopBtn.Size             = UDim2.new(1, 0, 0, 36)
	hopBtn.BackgroundColor3 = Color3.fromRGB(239, 79, 29)
	hopBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
	hopBtn.TextScaled       = false
	hopBtn.TextSize         = 13
	hopBtn.Font             = Enum.Font.GothamBold
	hopBtn.Text             = "Serverhop Now"
	hopBtn.BorderSizePixel  = 0
	hopBtn.Parent           = scrollFrame
	Instance.new("UICorner", hopBtn).CornerRadius = UDim.new(0, 8)
	hopBtn.MouseButton1Click:Connect(doServerhop)
end

makeSection("Movement")
local speedRef = makeToggle("Speed Hack", "speedHack", nil, "F1")
local flyRef   = makeToggle("Fly Hack",   "flyHack", function(on)
	if on then enableFly() else disableFly() end
end, "F2")
makeToggle("Noclip", "noclip", function(on)
	if not on then
		local character = player.Character
		if character then
			for _, part in ipairs(character:GetDescendants()) do
				if part:IsA("BasePart") then part.CanCollide = true end
			end
		end
	end
end)
makeSlider("Fly Speed", 10, 1000, 60, "flySpeed")

makeSection("Config")

do
	local inputCard = Instance.new("Frame")
	inputCard.Size             = UDim2.new(1, 0, 0, 44)
	inputCard.BackgroundColor3 = BG_CARD
	inputCard.BorderSizePixel  = 0
	inputCard.Parent           = scrollFrame
	Instance.new("UICorner", inputCard).CornerRadius = UDim.new(0, 8)

	local inputLbl = Instance.new("TextLabel")
	inputLbl.Size               = UDim2.new(1, -12, 0, 18)
	inputLbl.Position           = UDim2.new(0, 12, 0, 4)
	inputLbl.BackgroundTransparency = 1
	inputLbl.TextColor3         = TEXT_MUTED
	inputLbl.TextScaled         = false
	inputLbl.TextSize           = 11
	inputLbl.Font               = Enum.Font.GothamBold
	inputLbl.Text               = "CONFIG NAME"
	inputLbl.TextXAlignment     = Enum.TextXAlignment.Left
	inputLbl.Parent             = inputCard

	local inputBox = Instance.new("TextBox")
	inputBox.Size               = UDim2.new(1, -24, 0, 18)
	inputBox.Position           = UDim2.new(0, 12, 0, 22)
	inputBox.BackgroundTransparency = 1
	inputBox.TextColor3         = TEXT_PRIMARY
	inputBox.PlaceholderColor3  = TEXT_MUTED
	inputBox.PlaceholderText    = "e.g. default"
	inputBox.TextScaled         = false
	inputBox.TextSize           = 13
	inputBox.Font               = Enum.Font.Gotham
	inputBox.Text               = "default"
	inputBox.TextXAlignment     = Enum.TextXAlignment.Left
	inputBox.ClearTextOnFocus   = false
	inputBox.Parent             = inputCard

	local currentConfigName = "default"
	inputBox:GetPropertyChangedSignal("Text"):Connect(function()
		currentConfigName = inputBox.Text
	end)

	local btnRow = Instance.new("Frame")
	btnRow.Size             = UDim2.new(1, 0, 0, 34)
	btnRow.BackgroundTransparency = 1
	btnRow.Parent           = scrollFrame
	local btnLayout = Instance.new("UIListLayout")
	btnLayout.FillDirection = Enum.FillDirection.Horizontal
	btnLayout.Padding       = UDim.new(0, 4)
	btnLayout.Parent        = btnRow

	local saveBtn = Instance.new("TextButton")
	saveBtn.Size             = UDim2.new(0.5, -2, 1, 0)
	saveBtn.BackgroundColor3 = ACCENT_COLOR
	saveBtn.TextColor3       = BG_DEEP
	saveBtn.TextScaled       = false
	saveBtn.TextSize         = 12
	saveBtn.Font             = Enum.Font.GothamBold
	saveBtn.Text             = "Save"
	saveBtn.BorderSizePixel  = 0
	saveBtn.Parent           = btnRow
	Instance.new("UICorner", saveBtn).CornerRadius = UDim.new(0, 8)
	saveBtn.MouseButton1Click:Connect(function()
		if currentConfigName ~= "" then
			local ok, msg = saveConfig(currentConfigName)
			setStatus(msg)
		end
	end)

	local loadBtn = Instance.new("TextButton")
	loadBtn.Size             = UDim2.new(0.5, -2, 1, 0)
	loadBtn.BackgroundColor3 = BG_CARD
	loadBtn.TextColor3       = TEXT_PRIMARY
	loadBtn.TextScaled       = false
	loadBtn.TextSize         = 12
	loadBtn.Font             = Enum.Font.GothamBold
	loadBtn.Text             = "Load"
	loadBtn.BorderSizePixel  = 0
	loadBtn.Parent           = btnRow
	Instance.new("UICorner", loadBtn).CornerRadius = UDim.new(0, 8)
	loadBtn.MouseButton1Click:Connect(function()
		if currentConfigName ~= "" then
			local t, err = readConfig(currentConfigName)
			if t then
				applyConfig(t)
				refreshAllUI()
				setStatus("Config loaded: " .. currentConfigName)
			else
				setStatus(err or "Load failed")
			end
		end
	end)

	local autoRow = Instance.new("Frame")
	autoRow.Size             = UDim2.new(1, 0, 0, 34)
	autoRow.BackgroundTransparency = 1
	autoRow.Parent           = scrollFrame
	local autoRowLayout = Instance.new("UIListLayout")
	autoRowLayout.FillDirection = Enum.FillDirection.Horizontal
	autoRowLayout.Padding       = UDim.new(0, 4)
	autoRowLayout.Parent        = autoRow

	local setAutoBtn = Instance.new("TextButton")
	setAutoBtn.Size             = UDim2.new(0.5, -2, 1, 0)
	setAutoBtn.BackgroundColor3 = BG_CARD
	setAutoBtn.TextColor3       = TEXT_MUTED
	setAutoBtn.TextScaled       = false
	setAutoBtn.TextSize         = 11
	setAutoBtn.Font             = Enum.Font.Gotham
	setAutoBtn.Text             = "Set Autoload"
	setAutoBtn.BorderSizePixel  = 0
	setAutoBtn.Parent           = autoRow
	Instance.new("UICorner", setAutoBtn).CornerRadius = UDim.new(0, 8)
	setAutoBtn.MouseButton1Click:Connect(function()
		if currentConfigName ~= "" then
			saveConfig(currentConfigName)
			local ok = setAutoload(currentConfigName)
			setStatus(ok and ("Autoload set: " .. currentConfigName) or "Autoload write failed")
		end
	end)

	local clearAutoBtn = Instance.new("TextButton")
	clearAutoBtn.Size             = UDim2.new(0.5, -2, 1, 0)
	clearAutoBtn.BackgroundColor3 = BG_CARD
	clearAutoBtn.TextColor3       = TEXT_MUTED
	clearAutoBtn.TextScaled       = false
	clearAutoBtn.TextSize         = 11
	clearAutoBtn.Font             = Enum.Font.Gotham
	clearAutoBtn.Text             = "Clear Autoload"
	clearAutoBtn.BorderSizePixel  = 0
	clearAutoBtn.Parent           = autoRow
	Instance.new("UICorner", clearAutoBtn).CornerRadius = UDim.new(0, 8)
	clearAutoBtn.MouseButton1Click:Connect(function()
		clearAutoload(); setStatus("Autoload cleared")
	end)

	local listCard = Instance.new("Frame")
	listCard.Size             = UDim2.new(1, 0, 0, 100)
	listCard.BackgroundColor3 = BG_CARD
	listCard.BorderSizePixel  = 0
	listCard.Parent           = scrollFrame
	Instance.new("UICorner", listCard).CornerRadius = UDim.new(0, 8)

	local listLbl = Instance.new("TextLabel")
	listLbl.Size               = UDim2.new(1, -12, 0, 18)
	listLbl.Position           = UDim2.new(0, 12, 0, 4)
	listLbl.BackgroundTransparency = 1
	listLbl.TextColor3         = TEXT_MUTED
	listLbl.TextScaled         = false
	listLbl.TextSize           = 11
	listLbl.Font               = Enum.Font.GothamBold
	listLbl.Text               = "SAVED CONFIGS"
	listLbl.TextXAlignment     = Enum.TextXAlignment.Left
	listLbl.Parent             = listCard

	local configScroll = Instance.new("ScrollingFrame")
	configScroll.Size                = UDim2.new(1, -12, 1, -26)
	configScroll.Position            = UDim2.new(0, 6, 0, 22)
	configScroll.BackgroundTransparency = 1
	configScroll.BorderSizePixel     = 0
	configScroll.ScrollBarThickness  = 2
	configScroll.ScrollBarImageColor3 = ACCENT_COLOR
	configScroll.CanvasSize          = UDim2.new(0, 0, 0, 0)
	configScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	configScroll.Parent              = listCard
	Instance.new("UIListLayout", configScroll).Padding = UDim.new(0, 3)

	local configBtns = {}

	local function refreshConfigList()
		for _, b in ipairs(configBtns) do b:Destroy() end
		configBtns = {}
		local autoName = getAutoload()
		local names = listConfigs()
		if #names == 0 then
			local empty = Instance.new("TextLabel")
			empty.Size               = UDim2.new(1, 0, 0, 22)
			empty.BackgroundTransparency = 1
			empty.TextColor3         = TEXT_MUTED
			empty.TextScaled         = false
			empty.TextSize           = 11
			empty.Font               = Enum.Font.Gotham
			empty.Text               = "No configs saved yet"
			empty.Parent             = configScroll
			table.insert(configBtns, empty)
		else
			for _, name in ipairs(names) do
				local isAuto = name == autoName
				local chip = Instance.new("TextButton")
				chip.Size             = UDim2.new(1, 0, 0, 24)
				chip.BackgroundColor3 = isAuto and ACCENT_COLOR or BG_ELEMENT
				chip.TextColor3       = isAuto and BG_DEEP or TEXT_MUTED
				chip.TextScaled       = false
				chip.TextSize         = 11
				chip.Font             = isAuto and Enum.Font.GothamBold or Enum.Font.Gotham
				chip.Text             = (isAuto and "[auto] " or "") .. name
				chip.BorderSizePixel  = 0
				chip.Parent           = configScroll
				Instance.new("UICorner", chip).CornerRadius = UDim.new(0, 5)
				chip.MouseButton1Click:Connect(function()
					inputBox.Text     = name
					currentConfigName = name
					local t, err = readConfig(name)
					if t then
						applyConfig(t)
						refreshAllUI()
						setStatus("Config loaded: " .. name)
					else
						setStatus(err or "Load failed")
					end
					refreshConfigList()
				end)
				table.insert(configBtns, chip)
			end
		end
	end

	local refreshCfgBtn = Instance.new("TextButton")
	refreshCfgBtn.Size             = UDim2.new(1, 0, 0, 28)
	refreshCfgBtn.BackgroundColor3 = BG_CARD
	refreshCfgBtn.TextColor3       = TEXT_MUTED
	refreshCfgBtn.TextScaled       = false
	refreshCfgBtn.TextSize         = 11
	refreshCfgBtn.Font             = Enum.Font.Gotham
	refreshCfgBtn.Text             = "Refresh Config List"
	refreshCfgBtn.BorderSizePixel  = 0
	refreshCfgBtn.Parent           = scrollFrame
	Instance.new("UICorner", refreshCfgBtn).CornerRadius = UDim.new(0, 8)
	refreshCfgBtn.MouseButton1Click:Connect(refreshConfigList)

	refreshConfigList()
end

-- ============================================================
-- AUTOLOAD
-- ============================================================
do
	local autoName = getAutoload()
	if autoName and autoName ~= "" then
		local t, err = readConfig(autoName)
		if t then
			applyConfig(t)
			refreshAllUI()
			setStatus("Autoloaded: " .. autoName)
		else
			setStatus("Autoload failed: " .. (err or "unknown error"))
		end
	end
end

-- ============================================================
-- KEYBINDS
-- ============================================================
UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.RightAlt then
		state.guiVisible  = not state.guiVisible
		shadow.BackgroundTransparency = state.guiVisible and 0 or 1
		mainFrame.Visible = state.guiVisible
	elseif input.KeyCode == Enum.KeyCode.F1 then
		state.speedHack = not state.speedHack
		speedRef.refresh()
		setStatus("Speed Hack: " .. (state.speedHack and "ON" or "OFF"))
	elseif input.KeyCode == Enum.KeyCode.F2 then
		state.flyHack = not state.flyHack
		if state.flyHack then enableFly() else disableFly() end
		flyRef.refresh()
		setStatus("Fly Hack: " .. (state.flyHack and "ON" or "OFF"))
	end
end)

-- ============================================================
-- MAIN LOOP
-- ============================================================
local autoFarmTimer   = 0
local dropsEmptyTimer = 0

RunService.Heartbeat:Connect(function(dt)
	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChildWhichIsA("Humanoid")
	local root     = character:FindFirstChild("HumanoidRootPart")
	if not root or not humanoid then return end

	if state.noStun then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.StrafingNoPhysics, false)
		humanoid:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding,  false)
		if humanoid:GetState() == Enum.HumanoidStateType.PlatformStanding then
			humanoid:ChangeState(Enum.HumanoidStateType.Running)
		end
		if root.AssemblyLinearVelocity.Magnitude > 100 then
			root.AssemblyLinearVelocity = Vector3.zero
		end
	end

	if not state.flyHack then
		humanoid.WalkSpeed = state.speedHack and HACK_SPEED or DEFAULT_SPEED
	end

	if state.noclip then
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then part.CanCollide = false end
		end
	end

	if state.flyHack and flyBodyVelocity then
		flyBodyVelocity.Velocity = getFlyDirection() * state.flySpeed
		if flyBodyGyro then flyBodyGyro.CFrame = workspace.CurrentCamera.CFrame end
	end

	if state.mobESP then
		for mob, d in pairs(espData) do updateESP(mob, d, root) end
	end

	if state.autoFarm then
		autoFarmTimer += dt
		local target = getTargetMob()
		if target then
			root.CFrame = CFrame.new(target.Position + Vector3.new(0, state.farmDistance, 0), target.Position)
			if autoFarmTimer >= state.attackRate then
				autoFarmTimer = 0
				local tool = character:FindFirstChildWhichIsA("Tool")
				if tool then
					local event = tool:FindFirstChildWhichIsA("RemoteEvent")
					if event then event:FireServer() end
					tool.Activated:Fire()
				end
			end
		end
	elseif state.autoCollect then
		for _, drop in ipairs(DROP_FOLDER:GetChildren()) do
			if drop:IsA("Model") and drop.Name == "CursedFinger" then
				local x, y, z = drop:FindFirstChild("x"), drop:FindFirstChild("y"), drop:FindFirstChild("z")
				if x and y and z then
					root.CFrame = CFrame.new(Vector3.new(x.Value, y.Value, z.Value))
					break
				end
			end
		end
	end

	if state.autoServerhop then
		local curseCount = 0
		for _, drop in ipairs(DROP_FOLDER:GetChildren()) do
			if drop.Name == "CursedFinger" then curseCount += 1 end
		end
		if curseCount > 0 then
			dropsEmptyTimer = 0
			setStatus("Drops: " .. curseCount .. " remaining")
		else
			dropsEmptyTimer += dt
			local remaining = math.ceil(3 - dropsEmptyTimer)
			if dropsEmptyTimer < 3 then
				setStatus("No cursed fingers - hopping in " .. remaining .. "s")
			else
				doServerhop()
			end
		end
	else
		dropsEmptyTimer = 0
	end
end)

print("Sharmoodie Hub loaded! Press RAlt to toggle GUI.")
setStatus("Sharmoodie ready")
