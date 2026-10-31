--[[
    Keyless Hub v2
    - Rewritten UI (sidebar tabs, switches, sliders, keybind, toasts)
    - Aimlock: FOV circle, smoothing, hold-to-aim, team check, wall check, target part
    - ESP: highlight, name, distance, team check, proper cleanup
    - Unload button cleans up every connection and instance
]]

--------------------------------------------------------------------------------
-- SERVICES
--------------------------------------------------------------------------------
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

--------------------------------------------------------------------------------
-- CONFIG / THEME
--------------------------------------------------------------------------------
local Config = {
	ToggleKey = Enum.KeyCode.RightShift,
	Aimlock = {
		Enabled = false,
		HoldToAim = true, -- hold right mouse button
		Smoothness = 35, -- 0 = instant snap, 95 = very slow
		FOV = 180,
		ShowFOV = true,
		TeamCheck = true,
		WallCheck = false,
		TargetPart = "Head", -- Head / Torso / Root
	},
	ESP = {
		Enabled = false,
		Highlight = true,
		Names = true,
		Distance = true,
		TeamCheck = false,
		Color = Color3.fromRGB(120, 80, 240),
	},
}

local Theme = {
	Bg = Color3.fromRGB(18, 18, 22),
	Surface = Color3.fromRGB(28, 28, 34),
	Surface2 = Color3.fromRGB(38, 38, 46),
	Border = Color3.fromRGB(52, 52, 62),
	Accent = Color3.fromRGB(88, 101, 242),
	Off = Color3.fromRGB(62, 62, 72),
	Text = Color3.fromRGB(235, 235, 240),
	SubText = Color3.fromRGB(150, 150, 165),
	Danger = Color3.fromRGB(220, 70, 70),
	Gold = Color3.fromRGB(240, 190, 70),
}

local PART_NAMES = {
	Head = { "Head" },
	Torso = { "UpperTorso", "Torso" },
	Root = { "HumanoidRootPart" },
}

--------------------------------------------------------------------------------
-- UTILITIES
--------------------------------------------------------------------------------
local connections = {}
local function track(conn)
	table.insert(connections, conn)
	return conn
end

local function create(class, props, children)
	local inst = Instance.new(class)
	local parent
	for k, v in pairs(props or {}) do
		if k == "Parent" then
			parent = v
		else
			inst[k] = v
		end
	end
	for _, child in ipairs(children or {}) do
		child.Parent = inst
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function round(radius)
	return create("UICorner", { CornerRadius = UDim.new(0, radius) })
end

local function stroke(color, thickness)
	return create("UIStroke", {
		Color = color or Theme.Border,
		Thickness = thickness or 1,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function tween(inst, props, time)
	TweenService:Create(inst, TweenInfo.new(time or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

local function isTeammate(player, enabled)
	return enabled and player.Team ~= nil and player.Team == LocalPlayer.Team
end

--------------------------------------------------------------------------------
-- SCREEN GUI
--------------------------------------------------------------------------------
local old = PlayerGui:FindFirstChild("KeylessHubGui")
if old then
	old:Destroy()
end

local ScreenGui = create("ScreenGui", {
	Name = "KeylessHubGui",
	ResetOnSpawn = false,
	IgnoreGuiInset = true,
	DisplayOrder = 100,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = PlayerGui,
})

-- Toast notifications
local NotifHolder = create("Frame", {
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -16, 1, -16),
	Size = UDim2.fromOffset(240, 300),
	BackgroundTransparency = 1,
	Parent = ScreenGui,
}, {
	create("UIListLayout", {
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 6),
	}),
})

local function notify(text)
	local toast = create("Frame", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = Theme.Surface,
		BorderSizePixel = 0,
		Parent = NotifHolder,
	}, { round(8), stroke(Theme.Accent) })

	create("TextLabel", {
		Size = UDim2.new(1, -16, 1, 0),
		Position = UDim2.fromOffset(8, 0),
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = Theme.Text,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = toast,
	})

	task.delay(2.5, function()
		if toast then
			toast:Destroy()
		end
	end)
end

--------------------------------------------------------------------------------
-- MAIN WINDOW
--------------------------------------------------------------------------------
local FULL_SIZE = UDim2.fromOffset(560, 380)
local MINI_SIZE = UDim2.fromOffset(560, 42)

local Main = create("Frame", {
	Name = "Main",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = FULL_SIZE,
	BackgroundColor3 = Theme.Bg,
	BorderSizePixel = 0,
	Parent = ScreenGui,
}, { round(10), stroke(Theme.Border) })

local TopBar = create("Frame", {
	Name = "TopBar",
	Size = UDim2.new(1, 0, 0, 42),
	BackgroundTransparency = 1,
	Parent = Main,
})

create("TextLabel", {
	Position = UDim2.fromOffset(16, 0),
	Size = UDim2.new(0, 120, 1, 0),
	BackgroundTransparency = 1,
	Text = "Keyless Hub",
	TextColor3 = Theme.Text,
	Font = Enum.Font.GothamBold,
	TextSize = 16,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = TopBar,
})

create("TextLabel", {
	Position = UDim2.fromOffset(122, 2),
	Size = UDim2.new(0, 60, 1, 0),
	BackgroundTransparency = 1,
	Text = "v2.0",
	TextColor3 = Theme.Accent,
	Font = Enum.Font.GothamMedium,
	TextSize = 12,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = TopBar,
})

local function topButton(text, offsetX)
	return create("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, offsetX, 0.5, 0),
		Size = UDim2.fromOffset(28, 28),
		BackgroundColor3 = Theme.Surface,
		BorderSizePixel = 0,
		Text = text,
		TextColor3 = Theme.SubText,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		AutoButtonColor = false,
		Parent = TopBar,
	}, { round(6) })
end

local MinimizeBtn = topButton("–", -48)
local CloseBtn = topButton("✕", -12)

create("Frame", {
	Position = UDim2.fromOffset(0, 41),
	Size = UDim2.new(1, 0, 0, 1),
	BackgroundColor3 = Theme.Border,
	BorderSizePixel = 0,
	Parent = Main,
})

local Body = create("Frame", {
	Name = "Body",
	Position = UDim2.fromOffset(0, 42),
	Size = UDim2.new(1, 0, 1, -42),
	BackgroundTransparency = 1,
	Parent = Main,
})

local Sidebar = create("Frame", {
	Size = UDim2.new(0, 130, 1, 0),
	BackgroundTransparency = 1,
	Parent = Body,
}, {
	create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }),
	create("UIPadding", { PaddingTop = UDim.new(0, 10), PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }),
})

local Content = create("Frame", {
	Position = UDim2.fromOffset(138, 8),
	Size = UDim2.new(1, -148, 1, -16),
	BackgroundTransparency = 1,
	Parent = Body,
})

local Footer = create("TextLabel", {
	AnchorPoint = Vector2.new(0, 1),
	Position = UDim2.new(0, 14, 1, -8),
	Size = UDim2.fromOffset(110, 28),
	BackgroundTransparency = 1,
	Text = "Toggle: " .. Config.ToggleKey.Name,
	TextColor3 = Theme.SubText,
	Font = Enum.Font.Gotham,
	TextSize = 11,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = Body,
})

-- Dragging
do
	local dragging, dragStart, startPos
	TopBar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = Main.Position
		end
	end)
	track(UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
		end
	end))
	track(UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end))
end

-- Minimize
do
	local minimized = false
	MinimizeBtn.MouseButton1Click:Connect(function()
		minimized = not minimized
		if minimized then
			Body.Visible = false
			tween(Main, { Size = MINI_SIZE }, 0.2)
		else
			tween(Main, { Size = FULL_SIZE }, 0.2)
			task.delay(0.15, function()
				Body.Visible = true
			end)
		end
	end)
end

--------------------------------------------------------------------------------
-- TABS
--------------------------------------------------------------------------------
local tabs = {}

local function selectTab(name)
	for tabName, tab in pairs(tabs) do
		local active = tabName == name
		tab.Page.Visible = active
		tween(tab.Button, { BackgroundColor3 = active and Theme.Surface2 or Theme.Bg }, 0.12)
		tab.Button.TextColor3 = active and Theme.Text or Theme.SubText
		tab.Bar.Visible = active
	end
end

local function addTab(name, order)
	local button = create("TextButton", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = Theme.Bg,
		BorderSizePixel = 0,
		Text = "   " .. name,
		TextColor3 = Theme.SubText,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		AutoButtonColor = false,
		LayoutOrder = order,
		Parent = Sidebar,
	}, { round(6) })

	local bar = create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 0, 0.5, 0),
		Size = UDim2.fromOffset(3, 16),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		Visible = false,
		Parent = button,
	}, { round(2) })

	local page = create("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = Theme.Border,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Visible = false,
		Parent = Content,
	}, {
		create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
		create("UIPadding", { PaddingRight = UDim.new(0, 6) }),
	})

	button.MouseButton1Click:Connect(function()
		selectTab(name)
	end)

	tabs[name] = { Button = button, Page = page, Bar = bar }
	return page
end

local CombatPage = addTab("Combat", 1)
local VisualsPage = addTab("Visuals", 2)
local MiscPage = addTab("Misc", 3)
local SettingsPage = addTab("Settings", 4)

--------------------------------------------------------------------------------
-- UI COMPONENTS
--------------------------------------------------------------------------------
local function addSection(page, text)
	create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		Text = string.upper(text),
		TextColor3 = Theme.SubText,
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = page,
	})
end

local function makeRow(page, text, height)
	local row = create("Frame", {
		Size = UDim2.new(1, 0, 0, height or 38),
		BackgroundColor3 = Theme.Surface,
		BorderSizePixel = 0,
		Parent = page,
	}, { round(8) })

	local label = create("TextLabel", {
		Position = UDim2.fromOffset(12, height and 6 or 0),
		Size = UDim2.new(1, -90, 0, height and 18 or 38),
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = Theme.Text,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = row,
	})
	return row, label
end

local function addToggle(page, text, default, callback)
	local state = default
	local row = makeRow(page, text)

	local trackFrame = create("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(38, 20),
		BackgroundColor3 = state and Theme.Accent or Theme.Off,
		BorderSizePixel = 0,
		Parent = row,
	}, { round(10) })

	local knob = create("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = state and UDim2.new(1, -17, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
		Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = trackFrame,
	}, { round(7) })

	local function set(value, silent)
		state = value
		tween(trackFrame, { BackgroundColor3 = state and Theme.Accent or Theme.Off })
		tween(knob, { Position = state and UDim2.new(1, -17, 0.5, 0) or UDim2.new(0, 3, 0.5, 0) })
		if not silent then
			callback(state)
		end
	end

	create("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		Parent = row,
	}).MouseButton1Click:Connect(function()
		set(not state)
	end)

	return set
end

local function addSlider(page, text, min, max, default, suffix, callback)
	local value = default
	local row, _ = makeRow(page, text, 52)

	local valueLabel = create("TextLabel", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 6),
		Size = UDim2.fromOffset(70, 18),
		BackgroundTransparency = 1,
		Text = tostring(default) .. suffix,
		TextColor3 = Theme.Accent,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = row,
	})

	local bar = create("TextButton", {
		Position = UDim2.new(0, 12, 0, 34),
		Size = UDim2.new(1, -24, 0, 6),
		BackgroundColor3 = Theme.Off,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Parent = row,
	}, { round(3) })

	local fill = create("Frame", {
		Size = UDim2.new((default - min) / (max - min), 0, 1, 0),
		BackgroundColor3 = Theme.Accent,
		BorderSizePixel = 0,
		Parent = bar,
	}, { round(3) })

	local sliding = false
	local function update(x)
		local rel = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
		value = math.floor(min + (max - min) * rel + 0.5)
		fill.Size = UDim2.new(rel, 0, 1, 0)
		valueLabel.Text = tostring(value) .. suffix
		callback(value)
	end

	bar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			sliding = true
			update(input.Position.X)
		end
	end)
	track(UserInputService.InputChanged:Connect(function(input)
		if sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			update(input.Position.X)
		end
	end))
	track(UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			sliding = false
		end
	end))
end

local function addChoice(page, text, options, default, callback)
	local index = table.find(options, default) or 1
	local row = makeRow(page, text)

	local btn = create("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(90, 24),
		BackgroundColor3 = Theme.Surface2,
		BorderSizePixel = 0,
		Text = options[index],
		TextColor3 = Theme.Text,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		AutoButtonColor = false,
		Parent = row,
	}, { round(6) })

	btn.MouseButton1Click:Connect(function()
		index = index % #options + 1
		btn.Text = options[index]
		callback(options[index])
	end)
end

local rebinding = false
local function addKeybind(page, text, default, callback)
	local current = default
	local row = makeRow(page, text)

	local btn = create("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromOffset(90, 24),
		BackgroundColor3 = Theme.Surface2,
		BorderSizePixel = 0,
		Text = default.Name,
		TextColor3 = Theme.Text,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		AutoButtonColor = false,
		Parent = row,
	}, { round(6) })

	btn.MouseButton1Click:Connect(function()
		if rebinding then
			return
		end
		rebinding = true
		btn.Text = "..."
		local conn
		conn = UserInputService.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Keyboard then
				conn:Disconnect()
				if input.KeyCode ~= Enum.KeyCode.Escape then
					current = input.KeyCode
					callback(current)
				end
				btn.Text = current.Name
				task.defer(function()
					rebinding = false
				end)
			end
		end)
	end)
end

local function addButton(page, text, color, callback)
	local btn = create("TextButton", {
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundColor3 = color or Theme.Surface2,
		BorderSizePixel = 0,
		Text = text,
		TextColor3 = Theme.Text,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		AutoButtonColor = true,
		Parent = page,
	}, { round(8) })
	btn.MouseButton1Click:Connect(callback)
	return btn
end

--------------------------------------------------------------------------------
-- PREMIUM POP-UP
--------------------------------------------------------------------------------
local PopUp = create("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.45,
	Visible = false,
	Active = true,
	ZIndex = 50,
	Parent = ScreenGui,
})

local PopUpBox = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(300, 150),
	BackgroundColor3 = Theme.Surface,
	BorderSizePixel = 0,
	Parent = PopUp,
}, { round(10), stroke(Theme.Gold, 1.5) })

create("TextLabel", {
	Position = UDim2.fromOffset(16, 14),
	Size = UDim2.new(1, -32, 0, 22),
	BackgroundTransparency = 1,
	Text = "Premium Feature",
	TextColor3 = Theme.Gold,
	Font = Enum.Font.GothamBold,
	TextSize = 16,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = PopUpBox,
})

create("TextLabel", {
	Position = UDim2.fromOffset(16, 42),
	Size = UDim2.new(1, -32, 0, 44),
	BackgroundTransparency = 1,
	Text = "This is Keyless Hub Paid Access.",
	TextColor3 = Theme.Text,
	Font = Enum.Font.GothamMedium,
	TextSize = 13,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	Parent = PopUpBox,
})

create("TextButton", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -14),
	Size = UDim2.new(1, -32, 0, 32),
	BackgroundColor3 = Theme.Surface2,
	BorderSizePixel = 0,
	Text = "Close",
	TextColor3 = Theme.Text,
	Font = Enum.Font.GothamBold,
	TextSize = 13,
	Parent = PopUpBox,
}, { round(6) }).MouseButton1Click:Connect(function()
	PopUp.Visible = false
end)

--------------------------------------------------------------------------------
-- AIMLOCK
--------------------------------------------------------------------------------
local aim = Config.Aimlock

local FovCircle = create("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Size = UDim2.fromOffset(aim.FOV * 2, aim.FOV * 2),
	BackgroundTransparency = 1,
	Visible = false,
	Parent = ScreenGui,
}, {
	create("UICorner", { CornerRadius = UDim.new(1, 0) }),
	stroke(Color3.new(1, 1, 1), 1),
})

local function getAimPart(char)
	for _, name in ipairs(PART_NAMES[aim.TargetPart] or PART_NAMES.Head) do
		local part = char:FindFirstChild(name)
		if part then
			return part
		end
	end
	return char:FindFirstChild("HumanoidRootPart")
end

local function isVisible(part, camera)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { LocalPlayer.Character }
	local origin = camera.CFrame.Position
	local result = workspace:Raycast(origin, part.Position - origin, params)
	return result == nil or result.Instance:IsDescendantOf(part.Parent)
end

local function getTarget(camera, mousePos)
	local bestPart, bestDist = nil, aim.FOV

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and not isTeammate(player, aim.TeamCheck) then
			local char = player.Character
			local humanoid = char and char:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				local part = getAimPart(char)
				if part then
					local screenPos, onScreen = camera:WorldToViewportPoint(part.Position)
					if onScreen then
						local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
						if dist < bestDist and (not aim.WallCheck or isVisible(part, camera)) then
							bestDist = dist
							bestPart = part
						end
					end
				end
			end
		end
	end

	return bestPart
end

track(RunService.RenderStepped:Connect(function()
	local mousePos = UserInputService:GetMouseLocation()

	FovCircle.Visible = aim.Enabled and aim.ShowFOV
	if FovCircle.Visible then
		FovCircle.Position = UDim2.fromOffset(mousePos.X, mousePos.Y)
		FovCircle.Size = UDim2.fromOffset(aim.FOV * 2, aim.FOV * 2)
	end

	if not aim.Enabled then
		return
	end
	if aim.HoldToAim and not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
		return
	end

	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	local target = getTarget(camera, mousePos)
	if target then
		local goal = CFrame.new(camera.CFrame.Position, target.Position)
		local alpha = 1 - math.clamp(aim.Smoothness, 0, 95) / 100
		camera.CFrame = camera.CFrame:Lerp(goal, alpha)
	end
end))

--------------------------------------------------------------------------------
-- ESP
--------------------------------------------------------------------------------
local esp = Config.ESP
local espData = {} -- [player] = { conns = {}, highlight, billboard, label }

local function labelText(player)
	local text = ""
	if esp.Names then
		text = player.DisplayName
	end
	if esp.Distance then
		local char = player.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		local myChar = LocalPlayer.Character
		local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
		if root and myRoot then
			local studs = math.floor((root.Position - myRoot.Position).Magnitude)
			text = text .. (text ~= "" and "\n" or "") .. "[" .. studs .. "m]"
		end
	end
	return text
end

local function destroyEspObjects(data)
	if data.highlight then
		data.highlight:Destroy()
		data.highlight = nil
	end
	if data.billboard then
		data.billboard:Destroy()
		data.billboard = nil
		data.label = nil
	end
end

local function buildEsp(player)
	local data = espData[player]
	if not data then
		return
	end
	destroyEspObjects(data)

	local char = player.Character
	if not (esp.Enabled and char) or isTeammate(player, esp.TeamCheck) then
		return
	end

	if esp.Highlight then
		data.highlight = create("Highlight", {
			Name = "ESPHighlight",
			FillColor = esp.Color,
			FillTransparency = 0.5,
			OutlineColor = Color3.new(1, 1, 1),
			OutlineTransparency = 0,
			Adornee = char,
			Parent = char,
		})
	end

	if esp.Names or esp.Distance then
		task.spawn(function()
			local head = char:WaitForChild("Head", 5)
			if not head or espData[player] ~= data or player.Character ~= char then
				return
			end
			if data.billboard then
				data.billboard:Destroy()
			end
			data.billboard = create("BillboardGui", {
				Name = "ESPNameTag",
				Adornee = head,
				Size = UDim2.fromOffset(120, 36),
				StudsOffset = Vector3.new(0, 2.5, 0),
				AlwaysOnTop = true,
				Parent = head,
			})
			data.label = create("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = labelText(player),
				TextColor3 = Color3.new(1, 1, 1),
				TextStrokeTransparency = 0.3,
				Font = Enum.Font.GothamBold,
				TextSize = 12,
				Parent = data.billboard,
			})
		end)
	end
end

local function clearEsp(player)
	local data = espData[player]
	if not data then
		return
	end
	for _, conn in ipairs(data.conns) do
		conn:Disconnect()
	end
	destroyEspObjects(data)
	espData[player] = nil
end

local function hookEsp(player)
	if player == LocalPlayer or espData[player] then
		return
	end
	local data = { conns = {} }
	espData[player] = data
	table.insert(data.conns, player.CharacterAdded:Connect(function()
		buildEsp(player)
	end))
	table.insert(data.conns, player:GetPropertyChangedSignal("Team"):Connect(function()
		buildEsp(player)
	end))
	buildEsp(player)
end

local function rebuildAllEsp()
	for player in pairs(espData) do
		buildEsp(player)
	end
end

local function setEsp(enabled)
	esp.Enabled = enabled
	if enabled then
		for _, player in ipairs(Players:GetPlayers()) do
			hookEsp(player)
		end
	else
		for player in pairs(espData) do
			clearEsp(player)
		end
	end
end

track(Players.PlayerAdded:Connect(function(player)
	if esp.Enabled then
		hookEsp(player)
	end
end))
track(Players.PlayerRemoving:Connect(clearEsp))
track(LocalPlayer:GetPropertyChangedSignal("Team"):Connect(rebuildAllEsp))

-- Refresh distance text a few times per second
do
	local elapsed = 0
	track(RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.2 then
			return
		end
		elapsed = 0
		if not esp.Enabled then
			return
		end
		for player, data in pairs(espData) do
			if data.label then
				data.label.Text = labelText(player)
			end
		end
	end))
end

--------------------------------------------------------------------------------
-- UNLOAD
--------------------------------------------------------------------------------
local function unload()
	aim.Enabled = false
	for player in pairs(espData) do
		clearEsp(player)
	end
	for _, conn in ipairs(connections) do
		conn:Disconnect()
	end
	table.clear(connections)
	ScreenGui:Destroy()
end

CloseBtn.MouseButton1Click:Connect(unload)

--------------------------------------------------------------------------------
-- BUILD PAGES
--------------------------------------------------------------------------------
-- Combat
addSection(CombatPage, "Aimlock")
addToggle(CombatPage, "Enable Aimlock", aim.Enabled, function(v)
	aim.Enabled = v
	notify("Aimlock " .. (v and "enabled" or "disabled"))
end)
addToggle(CombatPage, "Hold Right Mouse to Aim", aim.HoldToAim, function(v)
	aim.HoldToAim = v
end)
addSlider(CombatPage, "Smoothness", 0, 95, aim.Smoothness, "%", function(v)
	aim.Smoothness = v
end)
addSlider(CombatPage, "FOV Radius", 50, 500, aim.FOV, "px", function(v)
	aim.FOV = v
end)
addToggle(CombatPage, "Show FOV Circle", aim.ShowFOV, function(v)
	aim.ShowFOV = v
end)
addChoice(CombatPage, "Target Part", { "Head", "Torso", "Root" }, aim.TargetPart, function(v)
	aim.TargetPart = v
end)
addToggle(CombatPage, "Team Check", aim.TeamCheck, function(v)
	aim.TeamCheck = v
end)
addToggle(CombatPage, "Wall Check", aim.WallCheck, function(v)
	aim.WallCheck = v
end)

-- Visuals
addSection(VisualsPage, "ESP")
addToggle(VisualsPage, "Enable ESP", esp.Enabled, function(v)
	setEsp(v)
	notify("ESP " .. (v and "enabled" or "disabled"))
end)
addToggle(VisualsPage, "Highlight", esp.Highlight, function(v)
	esp.Highlight = v
	rebuildAllEsp()
end)
addToggle(VisualsPage, "Names", esp.Names, function(v)
	esp.Names = v
	rebuildAllEsp()
end)
addToggle(VisualsPage, "Distance", esp.Distance, function(v)
	esp.Distance = v
	rebuildAllEsp()
end)
addToggle(VisualsPage, "Team Check (hide teammates)", esp.TeamCheck, function(v)
	esp.TeamCheck = v
	rebuildAllEsp()
end)

-- Misc
addSection(MiscPage, "Premium")
do
	local row = makeRow(MiscPage, "Autofarm")
	create("TextLabel", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(80, 20),
		BackgroundColor3 = Theme.Gold,
		BackgroundTransparency = 0.8,
		Text = "PREMIUM",
		TextColor3 = Theme.Gold,
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		Parent = row,
	}, { round(5) })
	create("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Text = "",
		Parent = row,
	}).MouseButton1Click:Connect(function()
		PopUp.Visible = true
	end)
end

-- Settings
addSection(SettingsPage, "Interface")
addKeybind(SettingsPage, "Toggle Menu Key", Config.ToggleKey, function(key)
	Config.ToggleKey = key
	Footer.Text = "Toggle: " .. key.Name
	notify("Menu key set to " .. key.Name)
end)
addSection(SettingsPage, "Script")
addButton(SettingsPage, "Unload Script", Theme.Danger, unload)

--------------------------------------------------------------------------------
-- MENU TOGGLE KEY
--------------------------------------------------------------------------------
track(UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or rebinding then
		return
	end
	if input.KeyCode == Config.ToggleKey then
		Main.Visible = not Main.Visible
	end
end))

--------------------------------------------------------------------------------
-- START
--------------------------------------------------------------------------------
selectTab("Combat")
notify("Keyless Hub loaded - press " .. Config.ToggleKey.Name .. " to toggle")
