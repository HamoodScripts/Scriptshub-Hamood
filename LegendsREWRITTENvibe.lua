-- All-in-One Hack GUI v3
-- Place in a LocalScript inside StarterPlayerScripts

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player      = Players.LocalPlayer
local MOB_FOLDER  = workspace.Mobs
local DROP_FOLDER = workspace.Drops
local Camera      = workspace.CurrentCamera

-- ============================================================
-- CONSTANTS
-- ============================================================
local DEFAULT_SPEED = 16
local HACK_SPEED    = 120
local ACCENT_COLOR  = Color3.fromRGB(255, 80, 80)
local ON_COLOR      = Color3.fromRGB(0, 160, 70)
local OFF_COLOR     = Color3.fromRGB(35, 35, 45)

local ESP_TEXT_COLOR = Color3.fromRGB(255, 220, 220)
local ESP_DIST_COLOR = Color3.fromRGB(200, 200, 255)
local ESP_TEXT_SIZE  = 13
local ESP_BOX_THICK  = 1

-- ============================================================
-- STATE
-- ============================================================
local state = {
	guiVisible   = true,
	mobESP       = false,
	autoFarm     = false,
	autoCollect  = false,
	noclip       = false,
	speedHack    = false,
	flyHack      = false,
	selectedMob  = nil,
	farmDistance = 5,
	flySpeed     = 60,
	attackRate   = 0.3,
	espMaxDist   = 300,
	noStun       = false,
}

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
-- MOB ESP  (Drawing API — proper screen-space scaling)
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

	local boxColor = Color3.fromRGB(255, 50, 50)

	local hbOutline = Drawing.new("Square")
	hbOutline.Visible      = false
	hbOutline.Color        = Color3.fromRGB(0, 0, 0)
	hbOutline.Filled       = true
	hbOutline.Transparency = 0.5

	local hbFill = Drawing.new("Square")
	hbFill.Visible = false
	hbFill.Filled  = true
	hbFill.Color   = Color3.fromRGB(0, 255, 0)

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

	

	espData[mob] = {
		box       = makeCornerBox(boxColor),
		hbOutline = hbOutline,
		hbFill    = hbFill,
		nameText  = nameText,
		distText  = distText,
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
	espData[mob] = nil
end

local function hideESP(d)
	for _, ln in pairs(d.box) do ln.Visible = false end
	d.hbOutline.Visible = false
	d.hbFill.Visible    = false
	d.nameText.Visible  = false
	d.distText.Visible  = false
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

local function updateESP(mob, d, playerRoot)
	local mobRoot = mob:FindFirstChild("HumanoidRootPart")
		or mob:FindFirstChildWhichIsA("BasePart")
	if not mobRoot then hideESP(d); return end

	local cf   = mobRoot.CFrame
	local size = mob:GetExtentsSize()

	local topScreen,    topVis    = Camera:WorldToViewportPoint(cf.Position + Vector3.new(0,  size.Y / 2, 0))
	local bottomScreen, bottomVis = Camera:WorldToViewportPoint(cf.Position + Vector3.new(0, -size.Y / 2, 0))
	local centreScreen            = Camera:WorldToViewportPoint(cf.Position)

	if not topVis or not bottomVis or topScreen.Z <= 0 then hideESP(d); return end

	local screenH = bottomScreen.Y - topScreen.Y
	if screenH <= 2 then hideESP(d); return end

	local screenW = screenH * 0.65
	local bPos    = Vector2.new(topScreen.X - screenW / 2, topScreen.Y)
	local bSize   = Vector2.new(screenW, screenH)

	local dist = math.floor((playerRoot.Position - mobRoot.Position).Magnitude)

	-- ESP distance filter
	if dist > state.espMaxDist then hideESP(d); return end

	local boxColor
	if dist < 30     then boxColor = Color3.fromRGB(50, 255, 80)
	elseif dist < 80 then boxColor = Color3.fromRGB(255, 220, 50)
	else                  boxColor = Color3.fromRGB(255, 50, 50)
	end

	updateCornerBox(d.box, bPos, bSize, boxColor)

	local hum   = mob:FindFirstChildWhichIsA("Humanoid")
	local ratio = hum and math.clamp(hum.Health / hum.MaxHealth, 0, 1) or 1
	local barW  = math.max(3, screenW * 0.08)
	local barH  = screenH

	d.hbOutline.Size     = Vector2.new(barW, barH)
	d.hbOutline.Position = Vector2.new(bPos.X - barW - 2, bPos.Y)
	d.hbOutline.Visible  = true

	d.hbFill.Color    = healthColor(ratio)
	d.hbFill.Size     = Vector2.new(barW - 2, math.max(1, (barH - 2) * ratio))
	d.hbFill.Position = Vector2.new(bPos.X - barW - 1, bPos.Y + 1 + (barH - 2) * (1 - ratio))
	d.hbFill.Visible  = true

	d.nameText.Text     = mob.Name
	d.nameText.Position = Vector2.new(bPos.X + screenW / 2, bPos.Y - ESP_TEXT_SIZE - 2)
	d.nameText.Visible  = true

	d.distText.Text     = dist .. " studs"
	d.distText.Position = Vector2.new(bPos.X + screenW / 2, bPos.Y + screenH + 2)
	d.distText.Visible  = true

end

MOB_FOLDER.ChildAdded:Connect(function(mob)
	if state.mobESP and mob:IsA("Model") then addESP(mob) end
end)
MOB_FOLDER.ChildRemoved:Connect(removeESP)

-- ============================================================
-- TARGETING HELPERS
-- ============================================================
local function getTargetMob()
	local character = player.Character
	if not character then return nil end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	local nearest, shortestDist = nil, math.huge
	for _, mob in ipairs(MOB_FOLDER:GetChildren()) do
		if mob:IsA("Model") then
			local nameMatch = state.selectedMob == nil or mob.Name == state.selectedMob
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

local function getNearestDrop()
	local character = player.Character
	if not character then return nil end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	local nearest, shortestDist = nil, math.huge
	for _, drop in ipairs(DROP_FOLDER:GetChildren()) do
		if drop:IsA("Model") then
			local x, y, z = drop:FindFirstChild("x"), drop:FindFirstChild("y"), drop:FindFirstChild("z")
			if x and y and z then
				local pos  = Vector3.new(x.Value, y.Value, z.Value)
				local dist = (root.Position - pos).Magnitude
				if dist < shortestDist then shortestDist = dist; nearest = pos end
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
		if root then root.CFrame = CFrame.new(Vector3.new(x.Value, y.Value + 3, z.Value)) end
	end
end)

-- ============================================================
-- GUI SETUP
-- ============================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "HackGUI"
screenGui.ResetOnSpawn   = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent         = player.PlayerGui

local mainFrame = Instance.new("Frame")
mainFrame.Size             = UDim2.new(0, 250, 0, 560)
mainFrame.Position         = UDim2.new(0, 10, 0.5, -280)
mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
mainFrame.BorderSizePixel  = 0
mainFrame.Active           = true
mainFrame.Draggable        = true
mainFrame.Parent           = screenGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10)

local accentBar = Instance.new("Frame")
accentBar.Size             = UDim2.new(1, 0, 0, 3)
accentBar.BackgroundColor3 = ACCENT_COLOR
accentBar.BorderSizePixel  = 0
accentBar.ZIndex           = 2
accentBar.Parent           = mainFrame
Instance.new("UICorner", accentBar).CornerRadius = UDim.new(0, 10)

local titleLabel = Instance.new("TextLabel")
titleLabel.Size               = UDim2.new(1, 0, 0, 40)
titleLabel.Position           = UDim2.new(0, 0, 0, 3)
titleLabel.BackgroundTransparency = 1
titleLabel.TextColor3         = Color3.fromRGB(255, 255, 255)
titleLabel.TextScaled         = true
titleLabel.Font               = Enum.Font.GothamBold
titleLabel.Text               = "⚔  HACK MENU  [RShift]"
titleLabel.Parent             = mainFrame

local statusLabel = Instance.new("TextLabel")
statusLabel.Size               = UDim2.new(1, -10, 0, 18)
statusLabel.Position           = UDim2.new(0, 5, 1, -20)
statusLabel.BackgroundTransparency = 1
statusLabel.TextColor3         = Color3.fromRGB(130, 130, 160)
statusLabel.TextScaled         = true
statusLabel.Font               = Enum.Font.Gotham
statusLabel.Text               = "v3 loaded"
statusLabel.Parent             = mainFrame

local function setStatus(msg)
	statusLabel.Text = msg
	task.delay(3, function()
		if statusLabel.Text == msg then statusLabel.Text = "ready" end
	end)
end

local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size                = UDim2.new(1, -10, 1, -68)
scrollFrame.Position            = UDim2.new(0, 5, 0, 46)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel     = 0
scrollFrame.ScrollBarThickness  = 3
scrollFrame.ScrollBarImageColor3 = ACCENT_COLOR
scrollFrame.CanvasSize          = UDim2.new(0, 0, 0, 0)
scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollFrame.Parent              = mainFrame

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 5)
listLayout.Parent  = scrollFrame

local listPadding = Instance.new("UIPadding")
listPadding.PaddingLeft  = UDim.new(0, 4)
listPadding.PaddingRight = UDim.new(0, 4)
listPadding.PaddingTop   = UDim.new(0, 4)
listPadding.Parent       = scrollFrame

-- ============================================================
-- GUI HELPERS
-- ============================================================
local function makeSection(text)
	local lbl = Instance.new("TextLabel")
	lbl.Size               = UDim2.new(1, 0, 0, 22)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3         = ACCENT_COLOR
	lbl.TextScaled         = true
	lbl.Font               = Enum.Font.GothamBold
	lbl.Text               = "— " .. text .. " —"
	lbl.Parent             = scrollFrame
	return lbl
end

local function makeToggle(label, stateKey, onToggle, keySuffix)
	local displayLabel = keySuffix and (label .. "  [" .. keySuffix .. "]") or label
	local btn = Instance.new("TextButton")
	btn.Size             = UDim2.new(1, 0, 0, 34)
	btn.BackgroundColor3 = OFF_COLOR
	btn.TextColor3       = Color3.fromRGB(180, 180, 180)
	btn.TextScaled       = true
	btn.Font             = Enum.Font.Gotham
	btn.Text             = "⬜  " .. displayLabel
	btn.BorderSizePixel  = 0
	btn.Parent           = scrollFrame
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

	local function refresh()
		if state[stateKey] then
			btn.BackgroundColor3 = ON_COLOR
			btn.TextColor3       = Color3.fromRGB(255, 255, 255)
			btn.Text             = "✅  " .. displayLabel
		else
			btn.BackgroundColor3 = OFF_COLOR
			btn.TextColor3       = Color3.fromRGB(180, 180, 180)
			btn.Text             = "⬜  " .. displayLabel
		end
	end

	btn.MouseButton1Click:Connect(function()
		state[stateKey] = not state[stateKey]
		refresh()
		if onToggle then onToggle(state[stateKey]) end
		setStatus(displayLabel .. (state[stateKey] and ": ON" or ": OFF"))
	end)

	return { refresh = refresh }
end

local function makeSlider(labelText, minVal, maxVal, defaultVal, onChange)
	local container = Instance.new("Frame")
	container.Size             = UDim2.new(1, 0, 0, 52)
	container.BackgroundColor3 = OFF_COLOR
	container.BorderSizePixel  = 0
	container.Parent           = scrollFrame
	Instance.new("UICorner", container).CornerRadius = UDim.new(0, 6)

	local lbl = Instance.new("TextLabel")
	lbl.Size               = UDim2.new(1, -10, 0, 22)
	lbl.Position           = UDim2.new(0, 8, 0, 2)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3         = Color3.fromRGB(200, 200, 200)
	lbl.TextScaled         = true
	lbl.Font               = Enum.Font.Gotham
	lbl.TextXAlignment     = Enum.TextXAlignment.Left
	lbl.Text               = labelText .. ": " .. defaultVal
	lbl.Parent             = container

	local track = Instance.new("Frame")
	track.Size             = UDim2.new(1, -16, 0, 8)
	track.Position         = UDim2.new(0, 8, 0, 32)
	track.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
	track.BorderSizePixel  = 0
	track.Parent           = container
	Instance.new("UICorner", track).CornerRadius = UDim.new(0, 4)

	local fill = Instance.new("Frame")
	fill.Size             = UDim2.new((defaultVal - minVal) / (maxVal - minVal), 0, 1, 0)
	fill.BackgroundColor3 = ACCENT_COLOR
	fill.BorderSizePixel  = 0
	fill.Parent           = track
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 4)

	local knob = Instance.new("TextButton")
	knob.Size             = UDim2.new(0, 16, 0, 16)
	knob.AnchorPoint      = Vector2.new(0.5, 0.5)
	knob.Position         = UDim2.new((defaultVal - minVal) / (maxVal - minVal), 0, 0.5, 0)
	knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	knob.Text             = ""
	knob.BorderSizePixel  = 0
	knob.Parent           = track
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

	local dragging = false
	knob.MouseButton1Down:Connect(function() dragging = true end)
	UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
	end)
	RunService.RenderStepped:Connect(function()
		if not dragging then return end
		local mouse   = player:GetMouse()
		local relX    = math.clamp((mouse.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		local val     = math.floor(minVal + relX * (maxVal - minVal))
		fill.Size     = UDim2.new(relX, 0, 1, 0)
		knob.Position = UDim2.new(relX, 0, 0.5, 0)
		lbl.Text      = labelText .. ": " .. val
		if onChange then onChange(val) end
	end)
end

local function makeMobList()
	local container = Instance.new("Frame")
	container.Size             = UDim2.new(1, 0, 0, 130)
	container.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	container.BorderSizePixel  = 0
	container.Parent           = scrollFrame
	Instance.new("UICorner", container).CornerRadius = UDim.new(0, 6)

	local listTitle = Instance.new("TextLabel")
	listTitle.Size               = UDim2.new(1, 0, 0, 22)
	listTitle.BackgroundTransparency = 1
	listTitle.TextColor3         = Color3.fromRGB(200, 200, 200)
	listTitle.TextScaled         = true
	listTitle.Font               = Enum.Font.GothamBold
	listTitle.Text               = "Select Mob Target:"
	listTitle.Parent             = container

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size                = UDim2.new(1, -8, 1, -26)
	scroll.Position            = UDim2.new(0, 4, 0, 24)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel     = 0
	scroll.ScrollBarThickness  = 3
	scroll.ScrollBarImageColor3 = ACCENT_COLOR
	scroll.CanvasSize          = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent              = container
	Instance.new("UIListLayout", scroll).Padding = UDim.new(0, 3)

	local mobButtons = {}
	local seen = {}

	local function refreshList()
		for _, b in ipairs(mobButtons) do b:Destroy() end
		mobButtons = {}; seen = {}

		local anyBtn = Instance.new("TextButton")
		anyBtn.Size             = UDim2.new(1, 0, 0, 26)
		anyBtn.BackgroundColor3 = state.selectedMob == nil and ACCENT_COLOR or Color3.fromRGB(40, 40, 55)
		anyBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
		anyBtn.TextScaled       = true
		anyBtn.Font             = Enum.Font.GothamBold
		anyBtn.Text             = "⚡ Any / Nearest"
		anyBtn.BorderSizePixel  = 0
		anyBtn.Parent           = scroll
		Instance.new("UICorner", anyBtn).CornerRadius = UDim.new(0, 4)
		table.insert(mobButtons, anyBtn)
		anyBtn.MouseButton1Click:Connect(function()
			state.selectedMob = nil
			for _, b in ipairs(mobButtons) do b.BackgroundColor3 = Color3.fromRGB(40, 40, 55); b.TextColor3 = Color3.fromRGB(180, 180, 180) end
			anyBtn.BackgroundColor3 = ACCENT_COLOR; anyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			setStatus("Target: Any")
		end)

		for _, mob in ipairs(MOB_FOLDER:GetChildren()) do
			if mob:IsA("Model") and not seen[mob.Name] then
				seen[mob.Name] = true
				local btn = Instance.new("TextButton")
				btn.Size             = UDim2.new(1, 0, 0, 26)
				btn.BackgroundColor3 = (state.selectedMob == mob.Name) and ACCENT_COLOR or Color3.fromRGB(40, 40, 55)
				btn.TextColor3       = Color3.fromRGB(180, 180, 180)
				btn.TextScaled       = true
				btn.Font             = Enum.Font.Gotham
				btn.Text             = mob.Name
				btn.BorderSizePixel  = 0
				btn.Parent           = scroll
				Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
				table.insert(mobButtons, btn)
				btn.MouseButton1Click:Connect(function()
					state.selectedMob = mob.Name
					for _, b in ipairs(mobButtons) do b.BackgroundColor3 = Color3.fromRGB(40, 40, 55); b.TextColor3 = Color3.fromRGB(180, 180, 180) end
					btn.BackgroundColor3 = ACCENT_COLOR; btn.TextColor3 = Color3.fromRGB(255, 255, 255)
					setStatus("Target: " .. mob.Name)
				end)
			end
		end
	end

	local refreshBtn = Instance.new("TextButton")
	refreshBtn.Size             = UDim2.new(1, 0, 0, 22)
	refreshBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
	refreshBtn.TextColor3       = Color3.fromRGB(200, 200, 255)
	refreshBtn.TextScaled       = true
	refreshBtn.Font             = Enum.Font.Gotham
	refreshBtn.Text             = "🔄 Refresh List"
	refreshBtn.BorderSizePixel  = 0
	refreshBtn.Parent           = scrollFrame
	Instance.new("UICorner", refreshBtn).CornerRadius = UDim.new(0, 6)
	refreshBtn.MouseButton1Click:Connect(function() refreshList(); setStatus("Mob list refreshed") end)

	MOB_FOLDER.ChildAdded:Connect(function()   task.wait(0.5); refreshList() end)
	MOB_FOLDER.ChildRemoved:Connect(function() task.wait(0.5); refreshList() end)
	refreshList()
end

-- ============================================================
-- BUILD GUI
-- ============================================================
makeSection("COMBAT")
makeToggle("Mob ESP", "mobESP", function(on)
	if on then
		for _, mob in ipairs(MOB_FOLDER:GetChildren()) do
			if mob:IsA("Model") then addESP(mob) end
		end
	else
		for mob in pairs(espData) do removeESP(mob) end
	end
end)
makeSlider("ESP Distance", 20, 1000, 300, function(v) state.espMaxDist = v end)
makeToggle("Auto Farm", "autoFarm", nil)
makeToggle("No Stun", "noStun", function(on)
	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChildWhichIsA("Humanoid")
	if not humanoid then return end
	humanoid:SetStateEnabled(Enum.HumanoidStateType.StrafingNoPhysics, not on)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.PlatformStanding,  not on)
	setStatus("No Stun: " .. (on and "ON" or "OFF"))
end)
makeMobList()
makeSlider("Farm Distance",     2,  30,  5, function(v) state.farmDistance = v end)
makeSlider("Attack Rate (×10)", 1,  20,  3, function(v) state.attackRate   = v / 10 end)

makeSection("DROPS")
makeToggle("Auto Collect", "autoCollect", nil)

makeSection("MOVEMENT")
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
makeSlider("Fly Speed", 10, 1000, 60, function(v) state.flySpeed = v end)

-- ============================================================
-- KEYBINDS
-- ============================================================
UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.RightShift then
		state.guiVisible  = not state.guiVisible
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
local autoFarmTimer = 0

RunService.Heartbeat:Connect(function(dt)
	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChildWhichIsA("Humanoid")
	local root     = character:FindFirstChild("HumanoidRootPart")
	if not root or not humanoid then return end

	if state.noStun and humanoid then
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
		for mob, d in pairs(espData) do
			updateESP(mob, d, root)
		end
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
		local dropPos = getNearestDrop()
		if dropPos then
			root.CFrame = CFrame.new(dropPos + Vector3.new(0, 3, 0))
		end
	end
end)

print("✅ Hack Menu v3 loaded! Press RShift to toggle GUI.")
setStatus("v3 ready ✔")
