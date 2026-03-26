-- All-in-One Hack GUI v2
-- Place in a LocalScript inside StarterPlayerScripts

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local MOB_FOLDER = workspace.Mobs
local DROP_FOLDER = workspace.Drops

-- ============================================================
-- STATE
-- ============================================================
local state = {
	guiVisible = true,
	mobESP = false,
	autoFarm = false,
	autoCollect = false,
	noclip = false,
	speedHack = false,
	flyHack = false,
	selectedMob = nil,
	farmDistance = 5,
}

local DEFAULT_SPEED = 16
local DEFAULT_JUMP = 50
local HACK_SPEED = 400
local flyBodyVelocity = nil
local flyBodyGyro = nil

-- ============================================================
-- GUI SETUP
-- ============================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HackGUI"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.Parent = player.PlayerGui

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 240, 0, 540)
mainFrame.Position = UDim2.new(0, 10, 0.5, -270)
mainFrame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui
Instance.new("UICorner", mainFrame).CornerRadius = UDim.new(0, 10)

-- Accent bar at top
local accentBar = Instance.new("Frame")
accentBar.Size = UDim2.new(1, 0, 0, 3)
accentBar.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
accentBar.BorderSizePixel = 0
accentBar.ZIndex = 2
accentBar.Parent = mainFrame
Instance.new("UICorner", accentBar).CornerRadius = UDim.new(0, 10)

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, 0, 0, 40)
titleLabel.Position = UDim2.new(0, 0, 0, 3)
titleLabel.BackgroundTransparency = 1
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextScaled = true
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Text = "⚔  HACK MENU  [RShift]"
titleLabel.Parent = mainFrame

local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size = UDim2.new(1, -10, 1, -50)
scrollFrame.Position = UDim2.new(0, 5, 0, 46)
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarThickness = 3
scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(255, 80, 80)
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollFrame.Parent = mainFrame

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 5)
listLayout.Parent = scrollFrame

local listPadding = Instance.new("UIPadding")
listPadding.PaddingLeft = UDim.new(0, 4)
listPadding.PaddingRight = UDim.new(0, 4)
listPadding.PaddingTop = UDim.new(0, 4)
listPadding.Parent = scrollFrame

-- ============================================================
-- HELPER: SECTION LABEL
-- ============================================================
local function makeSection(text)
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 0, 22)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3 = Color3.fromRGB(255, 80, 80)
	lbl.TextScaled = true
	lbl.Font = Enum.Font.GothamBold
	lbl.Text = "— " .. text .. " —"
	lbl.Parent = scrollFrame
	return lbl
end

-- ============================================================
-- HELPER: TOGGLE BUTTON
-- ============================================================
local function makeToggle(label, stateKey, onToggle)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 34)
	btn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
	btn.TextColor3 = Color3.fromRGB(180, 180, 180)
	btn.TextScaled = true
	btn.Font = Enum.Font.Gotham
	btn.Text = "⬜  " .. label
	btn.BorderSizePixel = 0
	btn.Parent = scrollFrame
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

	local function refresh()
		if state[stateKey] then
			btn.BackgroundColor3 = Color3.fromRGB(0, 160, 70)
			btn.TextColor3 = Color3.fromRGB(255, 255, 255)
			btn.Text = "✅  " .. label
		else
			btn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
			btn.TextColor3 = Color3.fromRGB(180, 180, 180)
			btn.Text = "⬜  " .. label
		end
	end

	btn.MouseButton1Click:Connect(function()
		state[stateKey] = not state[stateKey]
		refresh()
		if onToggle then onToggle(state[stateKey]) end
	end)

	return { refresh = refresh }
end

-- ============================================================
-- HELPER: KEYBIND BUTTON (display only)
-- ============================================================
local function makeKeybindButton(label, key, stateKey, onToggle)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 34)
	btn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
	btn.TextColor3 = Color3.fromRGB(180, 180, 180)
	btn.TextScaled = true
	btn.Font = Enum.Font.Gotham
	btn.Text = "⬜  " .. label .. "  [" .. key .. "]"
	btn.BorderSizePixel = 0
	btn.Parent = scrollFrame
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

	local function refresh()
		if state[stateKey] then
			btn.BackgroundColor3 = Color3.fromRGB(0, 160, 70)
			btn.TextColor3 = Color3.fromRGB(255, 255, 255)
			btn.Text = "✅  " .. label .. "  [" .. key .. "]"
		else
			btn.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
			btn.TextColor3 = Color3.fromRGB(180, 180, 180)
			btn.Text = "⬜  " .. label .. "  [" .. key .. "]"
		end
	end

	btn.MouseButton1Click:Connect(function()
		state[stateKey] = not state[stateKey]
		refresh()
		if onToggle then onToggle(state[stateKey]) end
	end)

	return { refresh = refresh }
end

-- ============================================================
-- SLIDER: FARM DISTANCE
-- ============================================================
local function makeSlider(labelText, minVal, maxVal, defaultVal, onChange)
	local container = Instance.new("Frame")
	container.Size = UDim2.new(1, 0, 0, 52)
	container.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
	container.BorderSizePixel = 0
	container.Parent = scrollFrame
	Instance.new("UICorner", container).CornerRadius = UDim.new(0, 6)

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -10, 0, 22)
	lbl.Position = UDim2.new(0, 8, 0, 2)
	lbl.BackgroundTransparency = 1
	lbl.TextColor3 = Color3.fromRGB(200, 200, 200)
	lbl.TextScaled = true
	lbl.Font = Enum.Font.Gotham
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Text = labelText .. ": " .. defaultVal
	lbl.Parent = container

	local track = Instance.new("Frame")
	track.Size = UDim2.new(1, -16, 0, 8)
	track.Position = UDim2.new(0, 8, 0, 30)
	track.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
	track.BorderSizePixel = 0
	track.Parent = container
	Instance.new("UICorner", track).CornerRadius = UDim.new(0, 4)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new((defaultVal - minVal) / (maxVal - minVal), 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
	fill.BorderSizePixel = 0
	fill.Parent = track
	Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 4)

	local knob = Instance.new("TextButton")
	knob.Size = UDim2.new(0, 16, 0, 16)
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.new((defaultVal - minVal) / (maxVal - minVal), 0, 0.5, 0)
	knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	knob.Text = ""
	knob.BorderSizePixel = 0
	knob.Parent = track
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

	local dragging = false
	knob.MouseButton1Down:Connect(function() dragging = true end)
	UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
	end)

	RunService.RenderStepped:Connect(function()
		if dragging then
			local mouse = player:GetMouse()
			local trackPos = track.AbsolutePosition.X
			local trackSize = track.AbsoluteSize.X
			local relX = math.clamp((mouse.X - trackPos) / trackSize, 0, 1)
			local val = math.floor(minVal + relX * (maxVal - minVal))
			fill.Size = UDim2.new(relX, 0, 1, 0)
			knob.Position = UDim2.new(relX, 0, 0.5, 0)
			lbl.Text = labelText .. ": " .. val
			if onChange then onChange(val) end
		end
	end)
end

-- ============================================================
-- MOB LIST FOR AUTO FARM
-- ============================================================
local function makeMobList()
	local container = Instance.new("Frame")
	container.Size = UDim2.new(1, 0, 0, 130)
	container.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
	container.BorderSizePixel = 0
	container.Parent = scrollFrame
	Instance.new("UICorner", container).CornerRadius = UDim.new(0, 6)

	local listTitle = Instance.new("TextLabel")
	listTitle.Size = UDim2.new(1, 0, 0, 22)
	listTitle.BackgroundTransparency = 1
	listTitle.TextColor3 = Color3.fromRGB(200, 200, 200)
	listTitle.TextScaled = true
	listTitle.Font = Enum.Font.GothamBold
	listTitle.Text = "Select Mob Target:"
	listTitle.Parent = container

	local scroll = Instance.new("ScrollingFrame")
	scroll.Size = UDim2.new(1, -8, 1, -26)
	scroll.Position = UDim2.new(0, 4, 0, 24)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 3
	scroll.ScrollBarImageColor3 = Color3.fromRGB(255, 80, 80)
	scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.Parent = container

	local innerLayout = Instance.new("UIListLayout")
	innerLayout.Padding = UDim.new(0, 3)
	innerLayout.Parent = scroll

	local mobButtons = {}
	local seen = {}

	local function refreshList()
		-- Clear old buttons
		for _, b in ipairs(mobButtons) do b:Destroy() end
		mobButtons = {}
		seen = {}

		for _, mob in ipairs(MOB_FOLDER:GetChildren()) do
			if mob:IsA("Model") and not seen[mob.Name] then
				seen[mob.Name] = true
				local btn = Instance.new("TextButton")
				btn.Size = UDim2.new(1, 0, 0, 26)
				btn.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
				btn.TextColor3 = Color3.fromRGB(180, 180, 180)
				btn.TextScaled = true
				btn.Font = Enum.Font.Gotham
				btn.Text = mob.Name
				btn.BorderSizePixel = 0
				btn.Parent = scroll
				Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
				table.insert(mobButtons, btn)

				btn.MouseButton1Click:Connect(function()
					state.selectedMob = mob.Name
					-- Highlight selected
					for _, b in ipairs(mobButtons) do
						b.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
						b.TextColor3 = Color3.fromRGB(180, 180, 180)
					end
					btn.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
					btn.TextColor3 = Color3.fromRGB(255, 255, 255)
				end)
			end
		end
	end

	-- Refresh button
	local refreshBtn = Instance.new("TextButton")
	refreshBtn.Size = UDim2.new(1, 0, 0, 22)
	refreshBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
	refreshBtn.TextColor3 = Color3.fromRGB(200, 200, 255)
	refreshBtn.TextScaled = true
	refreshBtn.Font = Enum.Font.Gotham
	refreshBtn.Text = "🔄 Refresh List"
	refreshBtn.BorderSizePixel = 0
	refreshBtn.Parent = scrollFrame
	Instance.new("UICorner", refreshBtn).CornerRadius = UDim.new(0, 6)
	refreshBtn.MouseButton1Click:Connect(refreshList)

	-- Auto refresh when mobs change
	MOB_FOLDER.ChildAdded:Connect(function() task.wait(0.5) refreshList() end)
	MOB_FOLDER.ChildRemoved:Connect(function() task.wait(0.5) refreshList() end)

	refreshList()
end

-- ============================================================
-- BUILD GUI SECTIONS
-- ============================================================
makeSection("COMBAT")
makeToggle("Mob ESP", "mobESP", nil)
makeToggle("Auto Farm", "autoFarm", nil)
makeMobList()
makeSlider("Farm Distance", 2, 30, 5, function(val) state.farmDistance = val end)

makeSection("DROPS")
makeToggle("Auto Collect", "autoCollect", nil)

makeSection("MOVEMENT")
makeKeybindButton("Speed Hack", "F1", "speedHack", nil)
makeKeybindButton("Fly Hack", "F2", "flyHack", function(on)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildWhichIsA("Humanoid")
	if not root then return end
	if on then
		humanoid.PlatformStand = true
		flyBodyVelocity = Instance.new("BodyVelocity")
		flyBodyVelocity.Velocity = Vector3.zero
		flyBodyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
		flyBodyVelocity.Parent = root
		flyBodyGyro = Instance.new("BodyGyro")
		flyBodyGyro.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
		flyBodyGyro.D = 50
		flyBodyGyro.Parent = root
	else
		humanoid.PlatformStand = false
		if flyBodyVelocity then flyBodyVelocity:Destroy() flyBodyVelocity = nil end
		if flyBodyGyro then flyBodyGyro:Destroy() flyBodyGyro = nil end
	end
end)
makeToggle("Noclip", "noclip", nil)

-- ============================================================
-- KEYBINDS
-- ============================================================
-- Store toggle refs for F1/F2
local speedRef = nil
local flyRef = nil

-- Rebuild keybind refs by finding buttons (simpler: just handle in InputBegan)
UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end

	-- RShift: toggle GUI
	if input.KeyCode == Enum.KeyCode.RightShift then
		state.guiVisible = not state.guiVisible
		mainFrame.Visible = state.guiVisible
	end

	-- F1: Speed Hack
	if input.KeyCode == Enum.KeyCode.F1 then
		state.speedHack = not state.speedHack
		-- Refresh button visuals
		for _, obj in ipairs(scrollFrame:GetDescendants()) do
			if obj:IsA("TextButton") and obj.Text:find("Speed Hack") then
				if state.speedHack then
					obj.BackgroundColor3 = Color3.fromRGB(0, 160, 70)
					obj.TextColor3 = Color3.fromRGB(255, 255, 255)
					obj.Text = "✅  Speed Hack  [F1]"
				else
					obj.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
					obj.TextColor3 = Color3.fromRGB(180, 180, 180)
					obj.Text = "⬜  Speed Hack  [F1]"
				end
			end
		end
	end

	-- F2: Fly Hack
	if input.KeyCode == Enum.KeyCode.F2 then
		state.flyHack = not state.flyHack
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildWhichIsA("Humanoid")
		if root and humanoid then
			if state.flyHack then
				humanoid.PlatformStand = true
				flyBodyVelocity = Instance.new("BodyVelocity")
				flyBodyVelocity.Velocity = Vector3.zero
				flyBodyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
				flyBodyVelocity.Parent = root
				flyBodyGyro = Instance.new("BodyGyro")
				flyBodyGyro.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
				flyBodyGyro.D = 50
				flyBodyGyro.Parent = root
			else
				humanoid.PlatformStand = false
				if flyBodyVelocity then flyBodyVelocity:Destroy() flyBodyVelocity = nil end
				if flyBodyGyro then flyBodyGyro:Destroy() flyBodyGyro = nil end
			end
		end
		-- Refresh button visuals
		for _, obj in ipairs(scrollFrame:GetDescendants()) do
			if obj:IsA("TextButton") and obj.Text:find("Fly Hack") then
				if state.flyHack then
					obj.BackgroundColor3 = Color3.fromRGB(0, 160, 70)
					obj.TextColor3 = Color3.fromRGB(255, 255, 255)
					obj.Text = "✅  Fly Hack  [F2]"
				else
					obj.BackgroundColor3 = Color3.fromRGB(35, 35, 45)
					obj.TextColor3 = Color3.fromRGB(180, 180, 180)
					obj.Text = "⬜  Fly Hack  [F2]"
				end
			end
		end
	end
end)

-- ============================================================
-- MOB ESP
-- ============================================================
local highlights = {}

local function addESP(mob)
	if highlights[mob] then return end
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.fromRGB(255, 50, 50)
	highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
	highlight.FillTransparency = 0.5
	highlight.Adornee = mob
	highlight.Parent = mob

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 120, 0, 45)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = mob

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0.5, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.TextColor3 = Color3.fromRGB(255, 220, 220)
	nameLabel.TextScaled = true
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.Text = mob.Name
	nameLabel.Parent = billboard

	local hpLabel = Instance.new("TextLabel")
	hpLabel.Size = UDim2.new(1, 0, 0.5, 0)
	hpLabel.Position = UDim2.new(0, 0, 0.5, 0)
	hpLabel.BackgroundTransparency = 1
	hpLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
	hpLabel.TextScaled = true
	hpLabel.Font = Enum.Font.Gotham
	hpLabel.Text = "100%"
	hpLabel.Parent = billboard

	highlights[mob] = { highlight = highlight, billboard = billboard, hpLabel = hpLabel }
end

local function removeESP(mob)
	local data = highlights[mob]
	if data then
		data.highlight:Destroy()
		data.billboard:Destroy()
		highlights[mob] = nil
	end
end

MOB_FOLDER.ChildRemoved:Connect(removeESP)

-- ============================================================
-- AUTO FARM: GET TARGET MOB
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
					if dist < shortestDist then
						shortestDist = dist
						nearest = mobRoot
					end
				end
			end
		end
	end
	return nearest
end

-- ============================================================
-- AUTO COLLECT: GET NEAREST DROP
-- ============================================================
local function getNearestDrop()
	local character = player.Character
	if not character then return nil end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end

	local nearest, shortestDist = nil, math.huge
	for _, drop in ipairs(DROP_FOLDER:GetChildren()) do
		if drop:IsA("Model") then
			local x = drop:FindFirstChild("x")
			local y = drop:FindFirstChild("y")
			local z = drop:FindFirstChild("z")
			if x and y and z then
				local pos = Vector3.new(x.Value, y.Value, z.Value)
				local dist = (root.Position - pos).Magnitude
				if dist < shortestDist then
					shortestDist = dist
					nearest = pos
				end
			end
		end
	end
	return nearest
end

DROP_FOLDER.ChildAdded:Connect(function(drop)
	if not state.autoCollect then return end
	task.wait(0.5)
	local x = drop:FindFirstChild("x")
	local y = drop:FindFirstChild("y")
	local z = drop:FindFirstChild("z")
	if x and y and z then
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			root.CFrame = CFrame.new(Vector3.new(x.Value, y.Value + 3, z.Value))
		end
	end
end)

-- ============================================================
-- FLY HACK MOVEMENT
-- ============================================================
local FLY_SPEED = 60
local function getFlyDirection()
	local camera = workspace.CurrentCamera
	local moveDir = Vector3.zero
	if UserInputService:IsKeyDown(Enum.KeyCode.W) then moveDir = moveDir + camera.CFrame.LookVector end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) then moveDir = moveDir - camera.CFrame.LookVector end
	if UserInputService:IsKeyDown(Enum.KeyCode.A) then moveDir = moveDir - camera.CFrame.RightVector end
	if UserInputService:IsKeyDown(Enum.KeyCode.D) then moveDir = moveDir + camera.CFrame.RightVector end
	if UserInputService:IsKeyDown(Enum.KeyCode.Space) then moveDir = moveDir + Vector3.new(0, 1, 0) end
	if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then moveDir = moveDir - Vector3.new(0, 1, 0) end
	if moveDir.Magnitude > 0 then moveDir = moveDir.Unit end
	return moveDir
end

-- ============================================================
-- MAIN LOOP
-- ============================================================
local autoFarmTimer = 0

RunService.Heartbeat:Connect(function(dt)
	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChildWhichIsA("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not humanoid then return end

	-- Speed hack
	if not state.flyHack then
		humanoid.WalkSpeed = state.speedHack and HACK_SPEED or DEFAULT_SPEED
	end

	-- Noclip
	if state.noclip then
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") then part.CanCollide = false end
		end
	end

	-- Fly hack
	if state.flyHack and flyBodyVelocity then
		local dir = getFlyDirection()
		flyBodyVelocity.Velocity = dir * FLY_SPEED
		if flyBodyGyro then
			flyBodyGyro.CFrame = workspace.CurrentCamera.CFrame
		end
	end

	-- Mob ESP
	for _, mob in ipairs(MOB_FOLDER:GetChildren()) do
		if mob:IsA("Model") then
			if state.mobESP and not highlights[mob] then addESP(mob)
			elseif not state.mobESP and highlights[mob] then removeESP(mob) end
		end
	end

	-- Update ESP labels
	if state.mobESP then
		for mob, data in pairs(highlights) do
			local mobRoot = mob:FindFirstChild("HumanoidRootPart") or mob:FindFirstChildWhichIsA("BasePart")
			if mobRoot then
				local dist = math.floor((root.Position - mobRoot.Position).Magnitude)
				local nameLabel = data.billboard:FindFirstChildWhichIsA("TextLabel")
				if nameLabel then nameLabel.Text = mob.Name .. "\n" .. dist .. " studs" end
			end
			local hum = mob:FindFirstChildWhichIsA("Humanoid")
			if hum and data.hpLabel then
				local ratio = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
				data.hpLabel.Text = math.floor(ratio * 100) .. "%"
				local r, g
				if ratio >= 0.5 then r = math.floor(255 * (1 - ratio) * 2) g = 255
				else r = 255 g = math.floor(255 * ratio * 2) end
				data.hpLabel.TextColor3 = Color3.fromRGB(r, g, 0)
			end
		end
	end

	-- Auto farm
if state.autoFarm then
    autoFarmTimer = autoFarmTimer + dt
    local target = getTargetMob()
    if target then
        -- Hover above mob at farmDistance studs, looking straight down
        local targetPos = target.Position + Vector3.new(0, state.farmDistance, 0)
        root.CFrame = CFrame.new(targetPos, target.Position)
			-- Attack every 0.3s
			if autoFarmTimer >= 0.3 then
				autoFarmTimer = 0
				local tool = character:FindFirstChildWhichIsA("Tool")
				if tool then
					local event = tool:FindFirstChildWhichIsA("RemoteEvent")
					if event then event:FireServer() end
					tool.Activated:Fire()
				end
			end
		end
	end

	-- Auto collect
	if state.autoCollect then
		local dropPos = getNearestDrop()
		if dropPos then
			root.CFrame = CFrame.new(dropPos + Vector3.new(0, 3, 0))
		end
	end
end)

print("✅ Hack Menu v2 loaded! Press RShift to toggle GUI.")