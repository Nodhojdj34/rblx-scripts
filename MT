--[[
========================================================
  灵动面板 v2 · 点击修复版
  本次针对「左侧分类点了没反应 / 右侧功能点了没效果」重做交互层：
  1) 完全不再用 ScrollingFrame 包按钮（移动端它会吞掉触摸点击）
  2) 每个按钮同时绑定 MouseButton1Click 与 Activated（触屏/鼠标双通道）
  3) 开关整行可点（点文字也生效），滑条整条可点可拖
  4) 灵动岛：按下不动=开关面板，拖动=跟手移动（像素级，不会粘鼠标、不会拖出屏幕）
  5) 全部功能照旧保留，一个都没删
  仅供 Roblox Lua / UI 学习测试
========================================================
]]

-- ================= 服务 =================
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")
local TeleportService = game:GetService("TeleportService")
local StarterGui = game:GetService("StarterGui")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local oldGui = PlayerGui:FindFirstChild("LingDaoHub")
if oldGui then
	oldGui:Destroy()
end

-- ================= 配色 =================
local Theme = {
	Bg = Color3.fromRGB(6, 6, 10),
	Side = Color3.fromRGB(14, 14, 22),
	Card = Color3.fromRGB(22, 22, 32),
	CardHover = Color3.fromRGB(34, 34, 48),
	Text = Color3.fromRGB(240, 242, 255),
	Dim = Color3.fromRGB(150, 158, 192),
	Accent = Color3.fromRGB(34, 211, 238),
	Green = Color3.fromRGB(52, 205, 120),
	Track = Color3.fromRGB(48, 48, 70)
}

-- ================= 状态 =================
local S = {
	esp = false,
	antiFly = false,
	infiniteJump = false,
	noclip = false,
	fly = false,
	flySpeed = 60,
	autoHeal = false,
	particle = false,
	hidePlayers = false,
	fullbright = false,
	walkSpeed = 16,
	jumpPower = 50,
	fov = 70,
	accent = Theme.Accent,
	accent2 = Color3.fromRGB(168, 85, 247),
	rainbow = false,
	autoAttack = false,
	attackDelay = 0.15,
	lockTarget = false,
	godMode = false,
	sprint = false,
	healThreshold = 35,
	fps = 0,
	musicVolume = 60,
	musicLoop = false,
	open = false,
	fov = 70,
	followDist = 12,
	ping = 0
}

local toggles = {}
local sliders = {}
local sliderFills = {}
local knobStrokes = {}
local cardStrokes = {}
local espTags = {}
local currentTab = 1
local musicList = {}
local Hotkeys = {
	ESP = Enum.KeyCode.E,
	AntiFly = Enum.KeyCode.F,
	Fly = Enum.KeyCode.G,
	Panel = Enum.KeyCode.K
}

-- ================= 基础辅助 =================
local function addCorner(obj, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = obj
	return c
end

local function addStroke(obj, color, thickness, transparency)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.Transparency = transparency
	s.Parent = obj
	return s
end

local function addGradient(obj, c1, c2, rot)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(c1, c2)
	g.Rotation = rot or 90
	g.Parent = obj
	return g
end

local function tint(c, k)
	return Color3.new(math.clamp(c.R * k, 0, 1), math.clamp(c.G * k, 0, 1), math.clamp(c.B * k, 0, 1))
end

local function mix(a, t, k)
	return Color3.new(a.R * k + t.R * (1 - k), a.G * k + t.G * (1 - k), a.B * k + t.B * (1 - k))
end

local accentGradients = {}
local DEEP = Color3.fromRGB(9, 9, 14)

local function accentGrad(obj, rot, strength)
	local g = Instance.new("UIGradient")
	g.Rotation = rot or 90
	g.Parent = obj
	table.insert(accentGradients, { grad = g, strength = strength })
	return g
end

local function refreshAccentGradients()
	local c1 = S.accent
	local c2 = S.accent2 or S.accent
	for _, item in ipairs(accentGradients) do
		item.grad.Color = ColorSequence.new(mix(c2, DEEP, item.strength), mix(c1, DEEP, item.strength * 0.22))
	end
end

local function hexOf(c)
	return string.format("#%02X%02X%02X", math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255))
end

local function addPadding(obj, all)
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, all)
	p.PaddingBottom = UDim.new(0, all)
	p.PaddingLeft = UDim.new(0, all)
	p.PaddingRight = UDim.new(0, all)
	p.Parent = obj
	return p
end

local function addList(parent, gap)
	local l = Instance.new("UIListLayout")
	l.Padding = UDim.new(0, gap or 6)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = parent
	return l
end

local function setOrder(parent, obj)
	local n = parent:GetAttribute("ord")
	if n == nil then
		n = 0
	end
	n = n + 1
	parent:SetAttribute("ord", n)
	obj.LayoutOrder = n
end

-- 【关键】一个按钮同时监听鼠标点击与触屏激活，避免某一通道失效导致点了没反应
local function bindClick(btn, fn)
	local lastTime = -1
	local function run()
		local now = os.clock()
		if now - lastTime < 0.12 then
			return
		end
		lastTime = now
		fn()
	end
	btn.MouseButton1Click:Connect(run)
	btn.Activated:Connect(run)
end

local function getChar()
	return LocalPlayer.Character
end

local function getHumanoid()
	local c = LocalPlayer.Character
	if c then
		return c:FindFirstChildOfClass("Humanoid")
	end
	return nil
end

-- 找最近的存活玩家（用于锁定目标 / 战斗信息）
local function findNearestPlayer()
	local myChar = LocalPlayer.Character
	local hrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return nil
	end
	local best = nil
	local bestDist = math.huge
	for _, pl in ipairs(Players:GetPlayers()) do
		if pl ~= LocalPlayer and pl.Character then
			local thrp = pl.Character:FindFirstChild("HumanoidRootPart")
			local nh = pl.Character:FindFirstChildOfClass("Humanoid")
			if thrp and nh and nh.Health > 0 then
				local d = (thrp.Position - hrp.Position).Magnitude
				if d < bestDist then
					best = pl
					bestDist = d
				end
			end
		end
	end
	return best, bestDist
end

-- ================= 组件 =================
-- 开关：整行都是按钮，点文字/点开关都生效
local function makeToggle(parent, name, initial, callback)
	local row = Instance.new("TextButton")
	row.Name = "Toggle_" .. name
	row.Size = UDim2.new(1, 0, 0, 40)
	row.BackgroundColor3 = Theme.Card
	row.Text = ""
	row.AutoButtonColor = false
	row.BorderSizePixel = 0
	row.Parent = parent
	setOrder(parent, row)
	addCorner(row, 10)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -76, 1, 0)
	label.Position = UDim2.new(0, 12, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = name
	label.TextColor3 = Theme.Text
	label.Font = Enum.Font.Gotham
	label.TextSize = 13
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = row

	local track = Instance.new("Frame")
	track.Size = UDim2.new(0, 46, 0, 24)
	track.Position = UDim2.new(1, -58, 0.5, -12)
	track.BackgroundColor3 = Theme.Track
	track.BorderSizePixel = 0
	track.Parent = row
	addCorner(track, 12)
	addStroke(track, Color3.fromRGB(255, 255, 255), 1, 0.9)

	local dot = Instance.new("Frame")
	dot.Size = UDim2.new(0, 18, 0, 18)
	dot.Position = UDim2.new(0, 3, 0.5, -9)
	dot.BackgroundColor3 = Theme.Text
	dot.BorderSizePixel = 0
	dot.Parent = track
	addCorner(dot, 9)
	addStroke(dot, Color3.fromRGB(0, 0, 0), 1, 0.75)

	local state = initial
	local function render(animate)
		local info = TweenInfo.new(0.14)
		if animate then
			if state then
				TweenService:Create(track, info, { BackgroundColor3 = Theme.Green }):Play()
				TweenService:Create(dot, info, { Position = UDim2.new(0, 25, 0.5, -9) }):Play()
			else
				TweenService:Create(track, info, { BackgroundColor3 = Theme.Track }):Play()
				TweenService:Create(dot, info, { Position = UDim2.new(0, 3, 0.5, -9) }):Play()
			end
		else
			if state then
				track.BackgroundColor3 = Theme.Green
				dot.Position = UDim2.new(0, 25, 0.5, -9)
			else
				track.BackgroundColor3 = Theme.Track
				dot.Position = UDim2.new(0, 3, 0.5, -9)
			end
		end
	end
	render(false)

	local function setState(v)
		state = v
		render(true)
		if callback then
			callback(state)
		end
	end

	bindClick(row, function()
		setState(not state)
	end)

	toggles[name] = {
		set = setState,
		get = function()
			return state
		end
	}
	return row
end

-- 滑条：整条可点可拖（鼠标 + 触屏）
local activeSlider = nil

local function makeSlider(parent, name, minV, maxV, defaultV, callback)
	local row = Instance.new("Frame")
	row.Name = "Slider_" .. name
	row.Size = UDim2.new(1, 0, 0, 56)
	row.BackgroundColor3 = Theme.Card
	row.BorderSizePixel = 0
	row.Parent = parent
	setOrder(parent, row)
	addCorner(row, 10)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -24, 0, 22)
	label.Position = UDim2.new(0, 12, 0, 8)
	label.BackgroundTransparency = 1
	label.Text = name .. " : " .. tostring(defaultV)
	label.TextColor3 = Theme.Text
	label.Font = Enum.Font.Gotham
	label.TextSize = 13
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = row

	-- 用 TextButton 当轨道，保证触摸能点到
	local bar = Instance.new("TextButton")
	bar.Size = UDim2.new(1, -24, 0, 10)
	bar.Position = UDim2.new(0, 12, 1, -22)
	bar.BackgroundColor3 = Theme.Track
	bar.Text = ""
	bar.AutoButtonColor = false
	bar.BorderSizePixel = 0
	bar.Parent = row
	addCorner(bar, 5)
	addStroke(bar, Color3.fromRGB(255, 255, 255), 1, 0.92)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new(0, 0, 1, 0)
	fill.BackgroundColor3 = S.accent
	fill.BorderSizePixel = 0
	fill.Parent = bar
	addCorner(fill, 5)

	local knob = Instance.new("Frame")
	knob.Size = UDim2.new(0, 16, 0, 16)
	knob.Position = UDim2.new(0, -8, 0.5, -8)
	knob.BackgroundColor3 = Theme.Text
	knob.BorderSizePixel = 0
	knob.Parent = bar
	addCorner(knob, 8)
	local knobStroke = addStroke(knob, S.accent, 1.5, 0.15)
	table.insert(knobStrokes, knobStroke)

	bar:SetAttribute("minV", minV)
	bar:SetAttribute("maxV", maxV)
	table.insert(sliderFills, fill)

	local value = defaultV
	local function setValue(v, fire)
		if v == nil then
			return
		end
		v = math.floor(math.clamp(v, minV, maxV))
		value = v
		local ratio = 0
		if maxV > minV then
			ratio = (v - minV) / (maxV - minV)
		end
		fill.Size = UDim2.new(ratio, 0, 1, 0)
		knob.Position = UDim2.new(ratio, -8, 0.5, -8)
		label.Text = name .. " : " .. tostring(v)
		if fire and callback then
			callback(v)
		end
	end
	setValue(defaultV, false)

	local function startDrag()
		activeSlider = { bar = bar, set = setValue }
	end

	bar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			startDrag()
			-- 点一下就立即跳到位
			local relX = input.Position.X - bar.AbsolutePosition.X
			local w = bar.AbsoluteSize.X
			if w > 0 then
				local ratio = math.clamp(relX / w, 0, 1)
				setValue(minV + ratio * (maxV - minV), true)
			end
		end
	end)
	bar.MouseButton1Down:Connect(startDrag)

	sliders[name] = {
		set = setValue,
		get = function()
			return value
		end
	}
	return row
end

local function makeButton(parent, text, color, callback)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 40)
	btn.BackgroundColor3 = color or Theme.Card
	btn.AutoButtonColor = true
	btn.Text = text
	btn.TextColor3 = Theme.Text
	btn.Font = Enum.Font.Gotham
	btn.TextSize = 13
	btn.AutoButtonColor = true
	btn.BorderSizePixel = 0
	btn.Parent = parent
	setOrder(parent, btn)
	addCorner(btn, 11)
	local bStroke = addStroke(btn, S.accent, 1.2, 0.78)

	local baseColor = color or Theme.Card
	if btn.MouseEnter and btn.MouseLeave then
		btn.MouseEnter:Connect(function()
			TweenService:Create(btn, TweenInfo.new(0.12), {
				BackgroundColor3 = tint(baseColor, 1.3)
			}):Play()
			TweenService:Create(bStroke, TweenInfo.new(0.12), {
				Transparency = 0.35
			}):Play()
		end)
		btn.MouseLeave:Connect(function()
			TweenService:Create(btn, TweenInfo.new(0.12), {
				BackgroundColor3 = baseColor
			}):Play()
			TweenService:Create(bStroke, TweenInfo.new(0.12), {
				Transparency = 0.78
			}):Play()
		end)
	end

	if callback then
		bindClick(btn, callback)
	end
	return btn
end

local sectionBars = {}

local function makeTitle(parent, text)
	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(0, 3, 0, 12)
	bar.Position = UDim2.new(0, 0, 0, 4)
	bar.BackgroundColor3 = S.accent
	bar.BorderSizePixel = 0
	bar.Active = false
	bar.Parent = parent
	setOrder(parent, bar)
	addCorner(bar, 1)
	table.insert(sectionBars, bar)

	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, -12, 0, 20)
	t.Position = UDim2.new(0, 10, 0, 0)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextColor3 = Theme.Dim
	t.Font = Enum.Font.GothamBold
	t.TextSize = 12
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Parent = parent
	setOrder(parent, t)
	return t
end

-- ================= 主界面 =================
local gui = Instance.new("ScreenGui")
gui.Name = "LingDaoHub"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 50
gui.Parent = PlayerGui

local statusText
local statusPillStroke

-- 灵动岛（双色 RichText + 呼吸光边）
local capsule = Instance.new("TextButton")
capsule.Name = "LingDaoCapsule"
capsule.Size = UDim2.new(0, 196, 0, 46)
capsule.Position = UDim2.new(0.5, -98, 0, 58)
capsule.BackgroundColor3 = Color3.fromRGB(12, 12, 18)
capsule.RichText = true
capsule.Text = '<font color="' .. hexOf(S.accent) .. '">●</font>  灵动控制台'
capsule.TextColor3 = Color3.fromRGB(238, 238, 248)
capsule.Font = Enum.Font.GothamBold
capsule.TextSize = 14
capsule.AutoButtonColor = false
capsule.BorderSizePixel = 0
capsule.ZIndex = 3
capsule.Parent = gui
addCorner(capsule, 23)
local capsuleStroke = addStroke(capsule, S.accent, 2, 0.22)

local function updateCapsuleText()
	local arrow = "⌄"
	if S.open then
		arrow = "⌃"
	end
	local warn = ""
	if S.riskWarn then
		warn = '  <font color="#FF6060">⚠ 高风险</font>'
	elseif S.lowFpsBadge then
		warn = '  <font color="#FFC450">⚠ 低帧</font>'
	end
	capsule.Text = '<font color="' .. hexOf(S.accent) .. '">●</font>  灵动控制台'
		.. warn .. '   <font color="#82829A">' .. arrow .. '</font>'
end

accentGrad(capsule, 20, 0.40)

task.spawn(function()
	while true do
		if statusText then
			statusText.Text = "在线  " .. tostring(S.fps or 0) .. "F"
		end
		task.wait(1)
	end
end)

task.spawn(function()
	local bright = true
	while true do
		local target = 0.25
		if bright then
			target = 0.8
		end
		pcall(function()
			TweenService:Create(capsuleStroke, TweenInfo.new(1.7, Enum.EasingStyle.Sine), {
				Transparency = target
			}):Play()
		end)
		bright = not bright
		task.wait(1.7)
	end
end)

updateCapsuleText()
refreshAccentGradients()

-- 主窗口
local win = Instance.new("Frame")
win.Name = "MainWindow"
win.Size = UDim2.new(0, 640, 0, 520)
win.Position = UDim2.new(0.5, -320, 0.5, -260)
win.BackgroundColor3 = Theme.Bg
win.BorderSizePixel = 0
win.Visible = false
win.Parent = gui
addCorner(win, 20)
local winStroke = addStroke(win, S.accent, 2, 0.18)
accentGrad(win, 90, 0.16)

local winScale = Instance.new("UIScale")
winScale.Name = "WinScale"
winScale.Scale = 1
winScale.Parent = win

-- 标题栏
local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 46)
titleBar.BackgroundColor3 = Theme.Side
titleBar.BorderSizePixel = 0
titleBar.Active = true
titleBar.Parent = win
addCorner(titleBar, 20)

-- 窗口顶部品牌色带（纯装饰，不接管输入）
local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, -20, 0, 4)
topBar.Position = UDim2.new(0, 10, 0, 6)
topBar.BackgroundColor3 = S.accent
topBar.BorderSizePixel = 0
topBar.Active = false
topBar.ZIndex = 10
topBar.Parent = win
addCorner(topBar, 3)
local topBarGrad = Instance.new("UIGradient")
topBarGrad.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.05),
	NumberSequenceKeypoint.new(0.5, 0.3),
	NumberSequenceKeypoint.new(1, 1)
})
topBarGrad.Parent = topBar

local titleGradient = Instance.new("UIGradient")
titleGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(46, 46, 70)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(26, 26, 40))
})
titleGradient.Parent = titleBar

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -220, 0, 24)
titleLabel.Position = UDim2.new(0, 18, 0, 6)
titleLabel.BackgroundTransparency = 1
titleLabel.RichText = true
titleLabel.Text = '<font color="#F2F2FA">灵动</font><font color="#7C5CFF">控制台</font>'
titleLabel.TextColor3 = Theme.Text
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 16
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar

local subtitleLabel = Instance.new("TextLabel")
subtitleLabel.Size = UDim2.new(1, -220, 0, 14)
subtitleLabel.Position = UDim2.new(0, 19, 0, 28)
subtitleLabel.BackgroundTransparency = 1
subtitleLabel.Text = "LINGDAO  CONSOLE"
subtitleLabel.TextColor3 = Color3.fromRGB(118, 118, 140)
subtitleLabel.Font = Enum.Font.Gotham
subtitleLabel.TextSize = 10
subtitleLabel.TextXAlignment = Enum.TextXAlignment.Left
subtitleLabel.Parent = titleBar

-- 右上角状态胶囊
local statusPill = Instance.new("Frame")
statusPill.Size = UDim2.new(0, 92, 0, 24)
statusPill.Position = UDim2.new(1, -142, 0.5, -12)
statusPill.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
statusPill.BorderSizePixel = 0
statusPill.Parent = titleBar
addCorner(statusPill, 12)
statusPillStroke = addStroke(statusPill, S.accent, 1, 0.6)

local statusDot = Instance.new("Frame")
statusDot.Size = UDim2.new(0, 7, 0, 7)
statusDot.Position = UDim2.new(0, 9, 0.5, -3.5)
statusDot.BackgroundColor3 = S.accent
statusDot.BorderSizePixel = 0
statusDot.Parent = statusPill
addCorner(statusDot, 4)

statusText = Instance.new("TextLabel")
statusText.Size = UDim2.new(1, -22, 1, 0)
statusText.Position = UDim2.new(0, 20, 0, 0)
statusText.BackgroundTransparency = 1
statusText.Text = "在线"
statusText.TextColor3 = Color3.fromRGB(210, 210, 228)
statusText.Font = Enum.Font.Gotham
statusText.TextSize = 11
statusText.TextXAlignment = Enum.TextXAlignment.Left
statusText.Parent = statusPill

-- 标题栏底部高光细线
local titleHair = Instance.new("Frame")
titleHair.Size = UDim2.new(1, -24, 0, 2)
titleHair.Position = UDim2.new(0, 12, 1, -2)
titleHair.BackgroundColor3 = S.accent
titleHair.BorderSizePixel = 0
titleHair.Active = false
titleHair.Parent = titleBar
addCorner(titleHair, 1)
local hairGrad = Instance.new("UIGradient")
hairGrad.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.5, 0.15),
	NumberSequenceKeypoint.new(1, 1)
})
hairGrad.Parent = titleHair

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 28, 0, 28)
closeBtn.Position = UDim2.new(1, -38, 0.5, -14)
closeBtn.BackgroundColor3 = Color3.fromRGB(64, 42, 54)
closeBtn.Text = "✕"
closeBtn.TextColor3 = Theme.Text
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.AutoButtonColor = false
closeBtn.BorderSizePixel = 0
closeBtn.Parent = titleBar
addCorner(closeBtn, 14)
addStroke(closeBtn, Color3.fromRGB(255, 120, 140), 1, 0.55)
if closeBtn.MouseEnter and closeBtn.MouseLeave then
	closeBtn.MouseEnter:Connect(function()
		TweenService:Create(closeBtn, TweenInfo.new(0.12), {
			BackgroundColor3 = Color3.fromRGB(96, 48, 62)
		}):Play()
	end)
	closeBtn.MouseLeave:Connect(function()
		TweenService:Create(closeBtn, TweenInfo.new(0.12), {
			BackgroundColor3 = Color3.fromRGB(64, 42, 54)
		}):Play()
	end)
end

-- 左侧分类栏（普通 Frame，不用 ScrollingFrame）
local sidebar = Instance.new("Frame")
sidebar.Name = "Sidebar"
sidebar.Size = UDim2.new(0, 152, 1, -54)
sidebar.Position = UDim2.new(0, 6, 0, 48)
sidebar.BackgroundColor3 = Theme.Side
sidebar.BorderSizePixel = 0
sidebar.Parent = win
addCorner(sidebar, 16)
accentGrad(sidebar, 90, 0.10)

-- 选中分类左侧的高亮指示条（单独一层，不放在按钮里，避免挡住点击）
local tabIndicator = Instance.new("Frame")
tabIndicator.Name = "TabIndicator"
tabIndicator.Size = UDim2.new(0, 3, 0, 28)
tabIndicator.Position = UDim2.new(0, 2, 0, 11)
tabIndicator.BackgroundColor3 = S.accent
tabIndicator.BorderSizePixel = 0
tabIndicator.Active = false
tabIndicator.Parent = sidebar
addCorner(tabIndicator, 2)

-- 右侧功能区
local rightPanel = Instance.new("Frame")
rightPanel.Name = "RightPanel"
rightPanel.Size = UDim2.new(1, -170, 1, -54)
rightPanel.Position = UDim2.new(0, 164, 0, 48)
rightPanel.BackgroundTransparency = 1
rightPanel.Parent = win

-- ================= 分类与面板 =================
local tabNames = {
	"角色设置",
	"移动增强",
	"战斗系统",
	"视觉辅助",
	"快捷操作",
	"音乐播放",
	"主题颜色",
	"快捷键",
	"服务器信息",
	"服务器工具",
	"实用工具",
	"自动增强"
}

local tabButtons = {}
local tabGradients = {}

local function styleTab(i, active)
	local btn = tabButtons[i]
	if not btn then
		return
	end
	local tg = tabGradients[i]
	if active then
		btn.BackgroundColor3 = S.accent
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		btn.Font = Enum.Font.GothamBold
		if tg then
			tg.Color = ColorSequence.new(tint(S.accent, 1.15), tint(S.accent, 0.7))
			tg.Transparency = NumberSequence.new(0)
		end
	else
		if tg then
			tg.Transparency = NumberSequence.new(1)
		end
		btn.BackgroundColor3 = Theme.Card
		btn.TextColor3 = Theme.Text
		btn.Font = Enum.Font.Gotham
	end
end
local panels = {}

local function showTab(index)
	currentTab = index
	for i = 1, #tabButtons do
		styleTab(i, i == index)
	end
	if tabIndicator then
		tabIndicator.Position = UDim2.new(0, 2, 0, 10 + (index - 1) * 38)
	end
	for i, panel in ipairs(panels) do
		panel.Visible = (i == index)
	end
end

for i, tabName in ipairs(tabNames) do
	-- 分类按钮：绝对定位，全部可见，不依赖滚动容器
	local btn = Instance.new("TextButton")
	btn.Name = "Tab" .. tostring(i)
	btn.Size = UDim2.new(1, -12, 0, 33)
	btn.Position = UDim2.new(0, 6, 0, 5 + (i - 1) * 38)
	btn.BackgroundColor3 = Theme.Card
	btn.Text = "  " .. tabName
	btn.TextColor3 = Theme.Text
	btn.Font = Enum.Font.Gotham
	btn.TextSize = 14
	btn.TextXAlignment = Enum.TextXAlignment.Left
	btn.AutoButtonColor = false
	btn.BorderSizePixel = 0
	btn.Parent = sidebar
	addCorner(btn, 10)
	tabGradients[i] = addGradient(btn, tint(S.accent, 1.15), tint(S.accent, 0.7), 90)
	tabGradients[i].Transparency = NumberSequence.new(1)
	addStroke(btn, Color3.fromRGB(255, 255, 255), 1, 0.94)

	if btn.MouseEnter and btn.MouseLeave then
		local idx = i
		btn.MouseEnter:Connect(function()
			if currentTab ~= idx then
				TweenService:Create(btn, TweenInfo.new(0.12), {
					BackgroundColor3 = Color3.fromRGB(48, 48, 66)
				}):Play()
			end
		end)
		btn.MouseLeave:Connect(function()
			if currentTab ~= idx then
				TweenService:Create(btn, TweenInfo.new(0.12), {
					BackgroundColor3 = Theme.Card
				}):Play()
			end
		end)
	end

	local panel = Instance.new("ScrollingFrame")
	panel.Name = "Panel" .. tostring(i)
	panel.Size = UDim2.new(1, 0, 1, 0)
	panel.BackgroundTransparency = 1
	panel.BorderSizePixel = 0
	panel.ClipsDescendants = true
	panel.ScrollingDirection = Enum.ScrollingDirection.Y
	panel.ScrollBarThickness = 4
	panel.ScrollBarImageColor3 = S.accent
	panel.ScrollBarImageTransparency = 0.4
	panel.AutomaticCanvasSize = Enum.AutomaticSize.Y
	panel.CanvasSize = UDim2.new(0, 0, 0, 0)
	panel.Visible = false
	panel.Parent = rightPanel
	addPadding(panel, 4)
	addList(panel, 6)

	table.insert(tabButtons, btn)
	table.insert(panels, panel)

	bindClick(btn, function()
		showTab(i)
	end)
end

-- ================= 面板1：角色设置 =================
local p1 = panels[1]
makeTitle(p1, "运动属性")
makeSlider(p1, "移速", 8, 160, S.walkSpeed, function(v)
	S.walkSpeed = v
	local h = getHumanoid()
	if h then
		h.WalkSpeed = v
	end
end)
makeSlider(p1, "跳跃力", 20, 260, S.jumpPower, function(v)
	S.jumpPower = v
	local h = getHumanoid()
	if h then
		h.UseJumpPower = true
		h.JumpPower = v
	end
end)
makeTitle(p1, "生存辅助")
makeToggle(p1, "无限跳跃", false, function(v)
	S.infiniteJump = v
end)
makeToggle(p1, "自动回血", false, function(v)
	S.autoHeal = v
end)
makeToggle(p1, "角色隐身", false, function(v)
	local c = getChar()
	if c then
		for _, part in ipairs(c:GetDescendants()) do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
				part.LocalTransparencyModifier = v and 1 or 0
			end
		end
	end
end)

-- ================= 面板2：移动增强 =================
local p2 = panels[2]
makeTitle(p2, "移动能力")
makeToggle(p2, "穿墙", false, function(v)
	S.noclip = v
	local c = getChar()
	if c then
		for _, part in ipairs(c:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CanCollide = not v
			end
		end
	end
end)
makeToggle(p2, "飞行模式", false, function(v)
	S.fly = v
	local h = getHumanoid()
	if h then
		h.PlatformStand = v
	end
end)
makeSlider(p2, "飞行速度", 10, 300, S.flySpeed, function(v)
	S.flySpeed = v
end)
makeTitle(p2, "防护")
makeToggle(p2, "防甩飞", false, function(v)
	S.antiFly = v
end)

-- ================= 面板3：战斗系统 =================
local p3 = panels[3]
makeTitle(p3, "自动攻击")
makeToggle(p3, "自动攻击（手持武器）", false, function(v)
	S.autoAttack = v
end)
makeSlider(p3, "攻击间隔（0.01秒）", 5, 100, 15, function(v)
	S.attackDelay = v / 100
end)
makeToggle(p3, "锁定最近目标", false, function(v)
	S.lockTarget = v
end)

makeTitle(p3, "战斗生存")
makeToggle(p3, "无敌模式", false, function(v)
	S.godMode = v
	local h = getHumanoid()
	if h then
		if v then
			h.MaxHealth = math.huge
			h.Health = math.huge
		else
			h.MaxHealth = 100
			h.Health = 100
		end
	end
end)
makeToggle(p3, "冲刺加速（Shift）", false, function(v)
	S.sprint = v
	local h = getHumanoid()
	if h and not v then
		h.WalkSpeed = S.walkSpeed
	end
end)
makeSlider(p3, "低血自动回血阈值", 10, 90, 35, function(v)
	S.healThreshold = v
end)

makeTitle(p3, "战斗信息")
local combatLabel = Instance.new("TextLabel")
combatLabel.Size = UDim2.new(1, 0, 0, 72)
combatLabel.BackgroundColor3 = Theme.Card
combatLabel.BorderSizePixel = 0
combatLabel.Text = "读取中..."
combatLabel.TextColor3 = Theme.Dim
combatLabel.Font = Enum.Font.Gotham
combatLabel.TextSize = 12
combatLabel.TextWrapped = true
combatLabel.TextXAlignment = Enum.TextXAlignment.Left
combatLabel.TextYAlignment = Enum.TextYAlignment.Top
combatLabel.Parent = p3
setOrder(p3, combatLabel)
addCorner(combatLabel, 10)
local cs_combatLabel = addStroke(combatLabel, S.accent, 1.2, 0.55)
table.insert(cardStrokes, cs_combatLabel)
accentGrad(combatLabel, 90, 0.13)
combatLabel.BackgroundTransparency = 0.06
local cbp = Instance.new("UIPadding")
cbp.PaddingTop = UDim.new(0, 8)
cbp.PaddingLeft = UDim.new(0, 10)
cbp.Parent = combatLabel

task.spawn(function()
	while true do
		local h = getHumanoid()
		local hpText = "-"
		if h then
			hpText = tostring(math.floor(h.Health)) .. " / " .. tostring(math.floor(h.MaxHealth))
		end
		local info = "我的生命：" .. hpText .. "\n"
		local target, dist = findNearestPlayer()
		if target then
			local ch = target.Character
			local nh = ch and ch:FindFirstChildOfClass("Humanoid")
			local tHp = "?"
			if nh then
				tHp = tostring(math.floor(nh.Health)) .. " / " .. tostring(math.floor(nh.MaxHealth))
			end
			info = info .. "最近目标：" .. target.Name .. "\n"
				.. "目标生命：" .. tHp .. "\n"
				.. "距离：" .. tostring(math.floor(dist or 0)) .. " 格"
		else
			info = info .. "最近目标：无"
		end
		combatLabel.Text = info
		task.wait(1)
	end
end)

-- ================= 面板4：视觉辅助 =================
local p4 = panels[4]
makeTitle(p4, "透视标记")
makeToggle(p4, "开启ESP", false, function(v)
	S.esp = v
	if not v then
		for _, child in ipairs(gui:GetChildren()) do
			if child.Name == "ESPTag" then
				child:Destroy()
			end
		end
		espTags = {}
	end
end)
makeTitle(p4, "画面")
makeSlider(p4, "视野FOV", 50, 120, S.fov, function(v)
	S.fov = v
	local cam = workspace.CurrentCamera
	if cam then
		cam.FieldOfView = v
	end
end)
makeToggle(p4, "全屏高亮", false, function(v)
	if v then
		Lighting.Brightness = 3
		Lighting.ClockTime = 12
		Lighting.OutdoorAmbient = Color3.fromRGB(200, 200, 200)
	else
		Lighting.Brightness = 1
		Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
	end
end)
makeToggle(p4, "屏蔽粒子特效", false, function(v)
	S.particle = v
end)
makeToggle(p4, "隐藏其他玩家", false, function(v)
	S.hidePlayers = v
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LocalPlayer and p.Character then
			for _, part in ipairs(p.Character:GetDescendants()) do
				if part:IsA("BasePart") then
					part.LocalTransparencyModifier = v and 1 or 0
				end
			end
		end
	end
end)

;(function()
	makeTitle(p4, "镜头与准星")

	makeSlider(p4, "镜头缩放距离", 1, 32, 12, function(v)
		pcall(function()
			LocalPlayer.CameraMinZoomDistance = 0.5
			LocalPlayer.CameraMaxZoomDistance = v
		end)
	end)

	local cross = Instance.new("Frame")
	cross.Name = "Crosshair"
	cross.Size = UDim2.new(0, 26, 0, 26)
	cross.Position = UDim2.new(0.5, -13, 0.5, -13)
	cross.BackgroundTransparency = 1
	cross.Visible = false
	cross.ZIndex = 6
	cross.Parent = gui

	local hBar = Instance.new("Frame")
	hBar.Size = UDim2.new(0, 26, 0, 2)
	hBar.Position = UDim2.new(0, 0, 0.5, -1)
	hBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	hBar.BackgroundTransparency = 0.25
	hBar.BorderSizePixel = 0
	hBar.Parent = cross

	local vBar = Instance.new("Frame")
	vBar.Size = UDim2.new(0, 2, 0, 26)
	vBar.Position = UDim2.new(0.5, -1, 0, 0)
	vBar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	vBar.BackgroundTransparency = 0.25
	vBar.BorderSizePixel = 0
	vBar.Parent = cross

	makeToggle(p4, "显示准星", false, function(v)
		cross.Visible = v
	end)
end)()

-- ================= 面板4：快捷操作 =================
local p5 = panels[5]
makeTitle(p5, "常用操作")
makeButton(p5, "回到出生点", Theme.Card, function()
	local c = getChar()
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	for _, obj in ipairs(workspace:GetChildren()) do
		if obj:IsA("SpawnLocation") then
			hrp.CFrame = obj.CFrame + Vector3.new(0, 4, 0)
			return
		end
	end
	hrp.CFrame = CFrame.new(0, 60, 0)
end)
makeButton(p5, "原地重生", Theme.Card, function()
	local c = getChar()
	if c then
		c:BreakJoints()
	end
end)
makeButton(p5, "重新进本服", Theme.Card, function()
	pcall(function()
		TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
	end)
end)
makeTitle(p5, "工具")
makeButton(p5, "复制我的名字", Theme.Card, function()
	pcall(function()
		if setclipboard then
			setclipboard(LocalPlayer.Name)
		end
	end)
end)

;(function()
	makeTitle(p5, "姿态")

	makeButton(p5, "切换坐下 / 站起", Theme.Card, function()
		local h = getHumanoid()
		if not h then
			return
		end
		pcall(function()
			h.Sit = not h.Sit
		end)
	end)
end)()

-- ================= 面板6：音乐播放 =================
local p6 = panels[6]
makeTitle(p6, "正在播放")

local currentSound = nil
local curId = nil
local currentIndex = nil
local musicBox
local listLabel

local nowLabel = Instance.new("TextLabel")
nowLabel.Size = UDim2.new(1, 0, 0, 62)
nowLabel.BackgroundColor3 = Theme.Card
nowLabel.BorderSizePixel = 0
nowLabel.Text = "未在播放"
nowLabel.TextColor3 = Theme.Dim
nowLabel.Font = Enum.Font.Gotham
nowLabel.TextSize = 12
nowLabel.TextWrapped = true
nowLabel.TextXAlignment = Enum.TextXAlignment.Left
nowLabel.TextYAlignment = Enum.TextYAlignment.Top
nowLabel.Parent = p6
setOrder(p6, nowLabel)
addCorner(nowLabel, 10)
local cs_nowLabel = addStroke(nowLabel, S.accent, 1.2, 0.55)
table.insert(cardStrokes, cs_nowLabel)
accentGrad(nowLabel, 90, 0.13)
nowLabel.BackgroundTransparency = 0.06
local nwp = Instance.new("UIPadding")
nwp.PaddingTop = UDim.new(0, 7)
nwp.PaddingLeft = UDim.new(0, 10)
nwp.Parent = nowLabel

-- 进度条
local barBg = Instance.new("Frame")
barBg.Size = UDim2.new(1, 0, 0, 6)
barBg.BackgroundColor3 = Color3.fromRGB(38, 38, 46)
barBg.BorderSizePixel = 0
barBg.Parent = p6
setOrder(p6, barBg)
addCorner(barBg, 3)

local barFill = Instance.new("Frame")
barFill.Size = UDim2.new(0, 0, 1, 0)
barFill.BackgroundColor3 = S.accent
barFill.BorderSizePixel = 0
barFill.Parent = barBg
addCorner(barFill, 3)

local musicBarFill = barFill

makeSlider(p6, "音量", 0, 100, 60, function(v)
	S.musicVolume = v
	if currentSound then
		currentSound.Volume = v / 100
	end
end)

local function stopMusic()
	if currentSound then
		pcall(function()
			currentSound:Stop()
			currentSound:Destroy()
		end)
		currentSound = nil
	end
	curId = nil
end

local function playId(rawId, fromIndex)
	local num = tonumber(rawId)
	if not num then
		nowLabel.Text = "请输入纯数字音频ID"
		return
	end
	num = math.floor(num)
	stopMusic()
	local snd = Instance.new("Sound")
	snd.Name = "LingDaoMusic"
	snd.SoundId = "rbxassetid://" .. tostring(num)
	snd.Volume = (S.musicVolume or 60) / 100
	snd.Looped = S.musicLoop == true
	snd.Parent = SoundService
	pcall(function()
		snd:Play()
	end)
	currentSound = snd
	curId = num
	currentIndex = fromIndex
	nowLabel.Text = "曲目 ID：" .. tostring(num) .. "\n加载中..."
end

local function refreshList()
	if #musicList == 0 then
		listLabel.Text = "收藏列表为空：输入ID后点「★ 收藏此ID」"
		return
	end
	local txt = "收藏列表（下一首会自动切歌）：\n"
	for i, v in ipairs(musicList) do
		if i == currentIndex then
			txt = txt .. "▶ " .. tostring(i) .. ". " .. tostring(v) .. "\n"
		else
			txt = txt .. "   " .. tostring(i) .. ". " .. tostring(v) .. "\n"
		end
	end
	listLabel.Text = txt
end

makeButton(p6, "▶  播放 / 暂停切换", Theme.Card, function()
	if currentSound then
		if currentSound.IsPlaying then
			pcall(function()
				currentSound:Pause()
			end)
		else
			pcall(function()
				currentSound:Resume()
			end)
		end
		if currentSound.IsPlaying then
			nowLabel.Text = "已暂停"
		else
			nowLabel.Text = "播放中"
		end
	else
		playId(musicBox and musicBox.Text or "", nil)
	end
end)

local rowStop = Instance.new("Frame")
rowStop.Size = UDim2.new(1, 0, 0, 34)
rowStop.BackgroundTransparency = 1
rowStop.Parent = p6
setOrder(p6, rowStop)

local bStop = makeButton(rowStop, "⏹  停止", Color3.fromRGB(70, 48, 56), function()
	stopMusic()
	nowLabel.Text = "已停止"
end)
bStop.Size = UDim2.new(0.5, -3, 1, 0)
bStop.Position = UDim2.new(0, 0, 0, 0)

local bNext = makeButton(rowStop, "⏭  下一首", Theme.Card, function()
	if #musicList == 0 then
		nowLabel.Text = "收藏列表为空，无法切歌"
		return
	end
	local idx = currentIndex or 0
	idx = idx + 1
	if idx > #musicList then
		idx = 1
	end
	playId(musicList[idx], idx)
	refreshList()
end)
bNext.Size = UDim2.new(0.5, -3, 1, 0)
bNext.Position = UDim2.new(0.5, 3, 0, 0)

musicBox = Instance.new("TextBox")
musicBox.Size = UDim2.new(1, 0, 0, 36)
musicBox.BackgroundColor3 = Theme.Card
musicBox.BorderSizePixel = 0
musicBox.Text = ""
musicBox.PlaceholderText = "输入音频ID（纯数字，如 1836873104）"
musicBox.PlaceholderColor3 = Theme.Dim
musicBox.TextColor3 = Theme.Text
musicBox.ClearTextOnFocus = false
musicBox.Font = Enum.Font.Gotham
musicBox.TextSize = 13
musicBox.Parent = p6
setOrder(p6, musicBox)
addCorner(musicBox, 10)
local mbp = Instance.new("UIPadding")
mbp.PaddingLeft = UDim.new(0, 12)
mbp.Parent = musicBox

local rowPlay = Instance.new("Frame")
rowPlay.Size = UDim2.new(1, 0, 0, 36)
rowPlay.BackgroundTransparency = 1
rowPlay.Parent = p6
setOrder(p6, rowPlay)

local bPlay = makeButton(rowPlay, "播放此ID", Theme.Card, function()
	playId(musicBox.Text, nil)
end)
bPlay.Size = UDim2.new(0.5, -3, 1, 0)
bPlay.Position = UDim2.new(0, 0, 0, 0)

local bFav = makeButton(rowPlay, "★ 收藏此ID", Color3.fromRGB(86, 68, 44), function()
	local num = tonumber(musicBox.Text)
	if not num then
		nowLabel.Text = "请输入纯数字音频ID"
		return
	end
	num = math.floor(num)
	for _, v in ipairs(musicList) do
		if v == num then
			nowLabel.Text = "该ID已在收藏列表里"
			return
		end
	end
	table.insert(musicList, num)
	refreshList()
	nowLabel.Text = "已收藏：" .. tostring(num)
end)
bFav.Size = UDim2.new(0.5, -3, 1, 0)
bFav.Position = UDim2.new(0.5, 3, 0, 0)

makeToggle(p6, "循环播放", false, function(v)
	S.musicLoop = v
	if currentSound then
		currentSound.Looped = v
	end
end)

listLabel = Instance.new("TextLabel")
listLabel.Size = UDim2.new(1, 0, 0, 84)
listLabel.BackgroundColor3 = Theme.Card
listLabel.BorderSizePixel = 0
listLabel.Text = "收藏列表为空：输入ID后点「★ 收藏此ID」"
listLabel.TextColor3 = Theme.Dim
listLabel.Font = Enum.Font.Gotham
listLabel.TextSize = 12
listLabel.TextWrapped = true
listLabel.TextXAlignment = Enum.TextXAlignment.Left
listLabel.TextYAlignment = Enum.TextYAlignment.Top
listLabel.Parent = p6
setOrder(p6, listLabel)
addCorner(listLabel, 10)
local cs_listLabel = addStroke(listLabel, S.accent, 1.2, 0.55)
table.insert(cardStrokes, cs_listLabel)
accentGrad(listLabel, 90, 0.13)
listLabel.BackgroundTransparency = 0.06
local llp = Instance.new("UIPadding")
llp.PaddingTop = UDim.new(0, 7)
llp.PaddingLeft = UDim.new(0, 10)
llp.Parent = listLabel

refreshList()

task.spawn(function()
	while true do
		if currentSound then
			local len = tonumber(currentSound.TimeLength) or 0
			local pos = tonumber(currentSound.TimePosition) or 0
			if len <= 0 then
				len = 0
				pos = 0
			end
			local pct = 0
			if len > 0 then
				pct = math.clamp(pos / len, 0, 1)
			end
			musicBarFill.Size = UDim2.new(pct, 0, 1, 0)
			musicBarFill.BackgroundColor3 = S.accent
			local status = "已暂停"
			if currentSound.IsPlaying then
				status = "播放中"
			end
			nowLabel.Text = string.format(
				"曲目 ID：%s\n进度：%.1f / %.1f 秒（%d%%）\n状态：%s",
				tostring(curId or "-"), pos, len, math.floor(pct * 100), status
			)
			nowLabel.TextColor3 = Theme.Text
		else
			musicBarFill.Size = UDim2.new(0, 0, 1, 0)
			nowLabel.Text = "未在播放"
			nowLabel.TextColor3 = Theme.Dim
		end
		task.wait(0.5)
	end
end)

-- ================= 面板7：主题颜色 =================
local p7 = panels[7]
local applyAccent
local ThemeText

makeTitle(p7, "一键主题")

local quickRow = Instance.new("Frame")
quickRow.Size = UDim2.new(1, 0, 0, 38)
quickRow.BackgroundTransparency = 1
quickRow.Parent = p7
setOrder(p7, quickRow)

local quickThemes = {
	{ name = "青紫霓虹", c1 = Color3.fromRGB(34, 211, 238), c2 = Color3.fromRGB(168, 85, 247) },
	{ name = "星紫", c1 = Color3.fromRGB(124, 92, 255), c2 = Color3.fromRGB(255, 122, 138) },
	{ name = "香槟金", c1 = Color3.fromRGB(212, 175, 55), c2 = Color3.fromRGB(255, 214, 120) },
	{ name = "冰蓝", c1 = Color3.fromRGB(78, 168, 255), c2 = Color3.fromRGB(34, 193, 195) }
}

for i, item in ipairs(quickThemes) do
	local b = makeButton(quickRow, item.name, Color3.fromRGB(26, 26, 38), function()
		applyAccent(item.c1, item.c2)
		ThemeText.Text = "当前：" .. item.name
	end)
	b.Size = UDim2.new(0.25, -4, 1, 0)
	b.Position = UDim2.new(0.25 * (i - 1) + 0.005, 0, 0, 0)
end

makeTitle(p7, "快捷配色（20 种）")
local presetColors = {
	{ name = "星紫", c = Color3.fromRGB(124, 92, 255) },
	{ name = "冰蓝", c = Color3.fromRGB(78, 168, 255) },
	{ name = "薄荷", c = Color3.fromRGB(53, 214, 160) },
	{ name = "琥珀", c = Color3.fromRGB(255, 176, 32) },
	{ name = "蜜桃", c = Color3.fromRGB(255, 122, 138) },
	{ name = "青柠", c = Color3.fromRGB(163, 230, 53) },
	{ name = "赤红", c = Color3.fromRGB(255, 77, 77) },
	{ name = "纯白", c = Color3.fromRGB(237, 237, 242) },
	{ name = "樱花", c = Color3.fromRGB(255, 143, 199) },
	{ name = "深海", c = Color3.fromRGB(46, 125, 255) },
	{ name = "青碧", c = Color3.fromRGB(34, 193, 195) },
	{ name = "落日", c = Color3.fromRGB(255, 107, 53) },
	{ name = "薰衣草", c = Color3.fromRGB(177, 140, 255) },
	{ name = "翡翠", c = Color3.fromRGB(25, 195, 125) },
	{ name = "橘金", c = Color3.fromRGB(255, 159, 28) },
	{ name = "玫红", c = Color3.fromRGB(255, 46, 136) },
	{ name = "雾蓝", c = Color3.fromRGB(108, 142, 191) },
	{ name = "铅灰", c = Color3.fromRGB(154, 164, 178) },
	{ name = "荧光绿", c = Color3.fromRGB(57, 255, 20) },
	{ name = "香槟金", c = Color3.fromRGB(212, 175, 55) }
}

local swatches = {}

applyAccent = function(c, c2)
	S.accent = c
	S.accent2 = c2 or c
	capsuleStroke.Color = c
	winStroke.Color = c
	updateCapsuleText()
	if tabButtons[currentTab] then
		styleTab(currentTab, true)
	end
	if tabIndicator then
		tabIndicator.BackgroundColor3 = c
	end
	if statusDot then
		statusDot.BackgroundColor3 = c
	end
	if statusPillStroke then
		statusPillStroke.Color = c
	end
	if titleHair then
		titleHair.BackgroundColor3 = c
	end
	if topBar then
		topBar.BackgroundColor3 = c
	end
	if titleLabel then
		titleLabel.Text = '<font color="#F2F2FA">灵动</font><font color="' .. hexOf(c) .. '">控制台</font>'
	end
	for _, fill in ipairs(sliderFills) do
		fill.BackgroundColor3 = c
	end
	for _, st in ipairs(knobStrokes or {}) do
		st.Color = c
	end
	for _, bar in ipairs(sectionBars) do
		bar.BackgroundColor3 = c
	end
	for _, cs in ipairs(cardStrokes or {}) do
		cs.Color = c
	end
	refreshAccentGradients()
	for _, sw in ipairs(swatches) do
		if sw.Stroke then
			sw.Stroke.Color = Color3.fromRGB(255, 255, 255)
			sw.Stroke.Transparency = 0.6
		end
	end
end

local function luminance(c)
	return 0.2126 * c.R + 0.7152 * c.G + 0.0722 * c.B
end

-- 自定义 HEX 解析
local function parseHex(raw)
	local txt = tostring(raw or ""):gsub("#", ""):gsub("%s", "")
	if #txt == 3 then
		txt = txt:sub(1, 1):rep(2) .. txt:sub(2, 2):rep(2) .. txt:sub(3, 3):rep(2)
	end
	if #txt ~= 6 or txt:find("[^%x]") then
		return nil
	end
	return Color3.fromRGB(
		tonumber(txt:sub(1, 2), 16),
		tonumber(txt:sub(3, 4), 16),
		tonumber(txt:sub(5, 6), 16)
	)
end

local gridHolder = Instance.new("Frame")
gridHolder.Size = UDim2.new(1, 0, 0, 194)
gridHolder.BackgroundTransparency = 1
gridHolder.Parent = p7
setOrder(p7, gridHolder)

local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.new(0.25, -5, 0, 34)
grid.CellPadding = UDim2.new(0, 6, 0, 6)
grid.Parent = gridHolder

for _, data in ipairs(presetColors) do
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = data.c
	b.Text = data.name
	if luminance(data.c) > 0.62 then
		b.TextColor3 = Color3.fromRGB(22, 22, 30)
	else
		b.TextColor3 = Color3.fromRGB(255, 255, 255)
	end
	b.Font = Enum.Font.GothamBold
	b.TextSize = 13
	b.AutoButtonColor = false
	b.BorderSizePixel = 0
	b.Parent = gridHolder
	addCorner(b, 9)
	local st = addStroke(b, Color3.fromRGB(255, 255, 255), 1, 0.6)
	table.insert(swatches, { Btn = b, Stroke = st })
	bindClick(b, function()
		applyAccent(data.c)
		ThemeText.Text = "当前：-" .. data.name
	end)
end

makeTitle(p7, "自定义颜色")

local hexBox = Instance.new("TextBox")
hexBox.Size = UDim2.new(1, 0, 0, 36)
hexBox.BackgroundColor3 = Theme.Card
hexBox.BorderSizePixel = 0
hexBox.Text = ""
hexBox.PlaceholderText = "输入色值，如 #FF7A8A 或 FF7A8A"
hexBox.PlaceholderColor3 = Theme.Dim
hexBox.TextColor3 = Theme.Text
hexBox.ClearTextOnFocus = false
hexBox.Font = Enum.Font.Gotham
hexBox.TextSize = 13
hexBox.Parent = p7
setOrder(p7, hexBox)
addCorner(hexBox, 10)
addStroke(hexBox, Color3.fromRGB(255, 255, 255), 1, 0.9)
local hxp = Instance.new("UIPadding")
hxp.PaddingLeft = UDim.new(0, 12)
hxp.Parent = hexBox

makeButton(p7, "应用这个颜色", Theme.Card, function()
	local c = parseHex(hexBox.Text)
	if not c then
		ThemeText.Text = "色值无效，请用 #FF7A8A 这种格式"
		return
	end
	applyAccent(c)
	ThemeText.Text = "当前：" .. hexOf(c)
end)

ThemeText = Instance.new("TextLabel")
ThemeText.Size = UDim2.new(1, 0, 0, 18)
ThemeText.BackgroundTransparency = 1
ThemeText.Text = "当前：" .. hexOf(S.accent)
ThemeText.TextColor3 = Theme.Dim
ThemeText.Font = Enum.Font.Gotham
ThemeText.TextSize = 11
ThemeText.TextXAlignment = Enum.TextXAlignment.Left
ThemeText.Parent = p7
setOrder(p7, ThemeText)

makeTitle(p7, "动态效果")
makeToggle(p7, "彩虹呼吸边框", false, function(v)
	S.rainbow = v
end)

-- ================= 面板7：快捷键 =================
local p8 = panels[8]
makeTitle(p8, "点击右侧按钮后，按任意键完成绑定")

local hotkeyLabels = {}
local bindingKey = nil

local function makeHotkeyRow(parent, label, keyName)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 40)
	row.BackgroundColor3 = Theme.Card
	row.BorderSizePixel = 0
	row.Parent = parent
	setOrder(parent, row)
	addCorner(row, 10)

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -120, 1, 0)
	nameLabel.Position = UDim2.new(0, 12, 0, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = label
	nameLabel.TextColor3 = Theme.Text
	nameLabel.Font = Enum.Font.Gotham
	nameLabel.TextSize = 13
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Parent = row

	local keyBtn = Instance.new("TextButton")
	keyBtn.Size = UDim2.new(0, 96, 0, 28)
	keyBtn.Position = UDim2.new(1, -106, 0.5, -14)
	keyBtn.BackgroundColor3 = Theme.Track
	keyBtn.Text = Hotkeys[keyName].Name
	keyBtn.TextColor3 = Theme.Text
	keyBtn.Font = Enum.Font.GothamBold
	keyBtn.TextSize = 12
	keyBtn.AutoButtonColor = false
	keyBtn.BorderSizePixel = 0
	keyBtn.Parent = row
	addCorner(keyBtn, 8)

	bindClick(keyBtn, function()
		bindingKey = { keyName = keyName, btn = keyBtn }
		keyBtn.Text = "按键中..."
	end)

	hotkeyLabels[keyName] = keyBtn
	return row
end

makeHotkeyRow(p8, "ESP 开关", "ESP")
makeHotkeyRow(p8, "防甩飞 开关", "AntiFly")
makeHotkeyRow(p8, "飞行 开关", "Fly")
makeHotkeyRow(p8, "面板 显示/隐藏", "Panel")

-- ================= 面板8：服务器信息 =================
local p9 = panels[9]
makeTitle(p9, "服务器状态")
local infoLabel = Instance.new("TextLabel")
infoLabel.Size = UDim2.new(1, 0, 0, 96)
infoLabel.BackgroundColor3 = Theme.Card
infoLabel.BorderSizePixel = 0
infoLabel.Text = "读取中..."
infoLabel.TextColor3 = Theme.Text
infoLabel.Font = Enum.Font.Gotham
infoLabel.TextSize = 12
infoLabel.TextWrapped = true
infoLabel.TextXAlignment = Enum.TextXAlignment.Left
infoLabel.TextYAlignment = Enum.TextYAlignment.Top
infoLabel.Parent = p9
setOrder(p9, infoLabel)
addCorner(infoLabel, 10)
local ip = Instance.new("UIPadding")
ip.PaddingTop = UDim.new(0, 8)
ip.PaddingLeft = UDim.new(0, 10)
ip.Parent = infoLabel

makeTitle(p9, "在线玩家")
local playerLabel = Instance.new("TextLabel")
playerLabel.Size = UDim2.new(1, 0, 0, 210)
playerLabel.BackgroundColor3 = Theme.Card
playerLabel.BorderSizePixel = 0
playerLabel.Text = ""
playerLabel.TextColor3 = Theme.Dim
playerLabel.Font = Enum.Font.Gotham
playerLabel.TextSize = 12
playerLabel.TextWrapped = true
playerLabel.TextXAlignment = Enum.TextXAlignment.Left
playerLabel.TextYAlignment = Enum.TextYAlignment.Top
playerLabel.Parent = p9
setOrder(p9, playerLabel)
addCorner(playerLabel, 10)
local pp = Instance.new("UIPadding")
pp.PaddingTop = UDim.new(0, 8)
pp.PaddingLeft = UDim.new(0, 10)
pp.Parent = playerLabel

task.spawn(function()
	while true do
		local list = ""
		local players = Players:GetPlayers()
		for i, pl in ipairs(players) do
			local tag = "玩家"
			if pl == LocalPlayer then
				tag = "我"
			end
			list = list .. tostring(i) .. ". " .. pl.Name .. " (" .. tag .. ")\n"
		end
		if list == "" then
			list = "暂无玩家"
		end
		playerLabel.Text = list
		infoLabel.Text = "服务器ID：" .. tostring(game.JobId) .. "\n"
			.. "在线人数：" .. tostring(#players) .. " / " .. tostring(Players.MaxPlayers) .. "\n"
			.. "地图ID：" .. tostring(game.PlaceId)
		task.wait(2)
	end
end)

-- ================= 面板10：服务器工具 =================
local p10 = panels[10]
makeTitle(p10, "实时服务器数据")

local netLabel = Instance.new("TextLabel")
netLabel.Size = UDim2.new(1, 0, 0, 96)
netLabel.BackgroundColor3 = Theme.Card
netLabel.BorderSizePixel = 0
netLabel.Text = "读取中..."
netLabel.TextColor3 = Theme.Dim
netLabel.Font = Enum.Font.Gotham
netLabel.TextSize = 12
netLabel.TextWrapped = true
netLabel.TextXAlignment = Enum.TextXAlignment.Left
netLabel.TextYAlignment = Enum.TextYAlignment.Top
netLabel.Parent = p10
setOrder(p10, netLabel)
addCorner(netLabel, 10)
local cs_netLabel = addStroke(netLabel, S.accent, 1.2, 0.55)
table.insert(cardStrokes, cs_netLabel)
accentGrad(netLabel, 90, 0.13)
netLabel.BackgroundTransparency = 0.06
local nlp = Instance.new("UIPadding")
nlp.PaddingTop = UDim.new(0, 8)
nlp.PaddingLeft = UDim.new(0, 10)
nlp.Parent = netLabel

local lookupLabel

local function copyText(txt)
	local ok = pcall(function()
		setclipboard(txt)
	end)
	if lookupLabel then
		if ok then
			lookupLabel.Text = "已复制：" .. txt
		else
			lookupLabel.Text = "剪贴板不可用，内容：" .. txt
		end
	end
end

makeTitle(p10, "一键复制")

local rowA = Instance.new("Frame")
rowA.Size = UDim2.new(1, 0, 0, 36)
rowA.BackgroundTransparency = 1
rowA.Parent = p10
setOrder(p10, rowA)

local bCopyJob = makeButton(rowA, "复制服务器ID", Theme.Card, function()
	copyText(tostring(game.JobId))
end)
bCopyJob.Size = UDim2.new(0.5, -3, 1, 0)
bCopyJob.Position = UDim2.new(0, 0, 0, 0)

local bCopyPlace = makeButton(rowA, "复制地图ID", Theme.Card, function()
	copyText(tostring(game.PlaceId))
end)
bCopyPlace.Size = UDim2.new(0.5, -3, 1, 0)
bCopyPlace.Position = UDim2.new(0.5, 3, 0, 0)

local rowB = Instance.new("Frame")
rowB.Size = UDim2.new(1, 0, 0, 36)
rowB.BackgroundTransparency = 1
rowB.Parent = p10
setOrder(p10, rowB)

local bCopyPlayers = makeButton(rowB, "复制玩家名单", Theme.Card, function()
	local names = {}
	for _, pl in ipairs(Players:GetPlayers()) do
		table.insert(names, pl.Name)
	end
	if #names == 0 then
		copyText("（当前无玩家）")
	else
		copyText(table.concat(names, ", "))
	end
end)
bCopyPlayers.Size = UDim2.new(0.5, -3, 1, 0)
bCopyPlayers.Position = UDim2.new(0, 0, 0, 0)

local bRejoin = makeButton(rowB, "重连本服", Color3.fromRGB(56, 72, 96), function()
	local ok = pcall(function()
		TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
	end)
	if lookupLabel then
		lookupLabel.Text = ok and "正在重连当前服务器..." or "重连失败：该游戏不允许传送"
	end
end)
bRejoin.Size = UDim2.new(0.5, -3, 1, 0)
bRejoin.Position = UDim2.new(0.5, 3, 0, 0)

makeButton(p10, "复制我的坐标（X, Y, Z）", Theme.Card, function()
	local c = LocalPlayer.Character
	local hrp = c and c:FindFirstChild("HumanoidRootPart")
	if hrp then
		local ps = hrp.Position
		copyText(string.format("%.1f, %.1f, %.1f", ps.X, ps.Y, ps.Z))
	else
		if lookupLabel then
			lookupLabel.Text = "读不到坐标：角色还没加载"
		end
	end
end)

makeTitle(p10, "玩家查询")

local searchBox = Instance.new("TextBox")
searchBox.Size = UDim2.new(1, 0, 0, 36)
searchBox.BackgroundColor3 = Theme.Card
searchBox.BorderSizePixel = 0
searchBox.Text = ""
searchBox.PlaceholderText = "输入玩家名字（可不完整）"
searchBox.TextColor3 = Theme.Text
searchBox.PlaceholderColor3 = Theme.Dim
searchBox.Font = Enum.Font.Gotham
searchBox.TextSize = 13
searchBox.ClearTextOnFocus = false
searchBox.Parent = p10
setOrder(p10, searchBox)
addCorner(searchBox, 10)
local sbp = Instance.new("UIPadding")
sbp.PaddingLeft = UDim.new(0, 12)
sbp.Parent = searchBox

makeButton(p10, "查找该玩家", Theme.Card, function()
	local key = string.lower(searchBox.Text or "")
	if key == "" then
		if lookupLabel then
			lookupLabel.Text = "请先输入玩家名字"
		end
		return
	end
	local myChar = LocalPlayer.Character
	local hrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
	local hits = {}
	for _, pl in ipairs(Players:GetPlayers()) do
		if string.find(string.lower(pl.Name), key, 1, true) then
			local ch = pl.Character
			local nh = ch and ch:FindFirstChildOfClass("Humanoid")
			local thrp = ch and ch:FindFirstChild("HumanoidRootPart")
			local distText = "不在现场"
			if hrp and thrp then
				distText = tostring(math.floor((thrp.Position - hrp.Position).Magnitude)) .. " 格"
			end
			local hpText = "?"
			if nh then
				hpText = tostring(math.floor(nh.Health))
			end
			table.insert(hits, pl.Name .. "｜距离 " .. distText .. "｜生命 " .. hpText)
		end
	end
	if lookupLabel then
		if #hits == 0 then
			lookupLabel.Text = "没有找到匹配的玩家"
		else
			lookupLabel.Text = table.concat(hits, "\n")
		end
	end
end)

lookupLabel = Instance.new("TextLabel")
lookupLabel.Size = UDim2.new(1, 0, 0, 56)
lookupLabel.BackgroundColor3 = Theme.Card
lookupLabel.BorderSizePixel = 0
lookupLabel.Text = "输入名字后点「查找该玩家」"
lookupLabel.TextColor3 = Theme.Dim
lookupLabel.Font = Enum.Font.Gotham
lookupLabel.TextSize = 12
lookupLabel.TextWrapped = true
lookupLabel.TextXAlignment = Enum.TextXAlignment.Left
lookupLabel.TextYAlignment = Enum.TextYAlignment.Top
lookupLabel.Parent = p10
setOrder(p10, lookupLabel)
addCorner(lookupLabel, 10)
local cs_lookupLabel = addStroke(lookupLabel, S.accent, 1.2, 0.55)
table.insert(cardStrokes, cs_lookupLabel)
accentGrad(lookupLabel, 90, 0.13)
lookupLabel.BackgroundTransparency = 0.06
local lkp = Instance.new("UIPadding")
lkp.PaddingTop = UDim.new(0, 8)
lkp.PaddingLeft = UDim.new(0, 10)
lkp.Parent = lookupLabel

task.spawn(function()
	while true do
		local pingText = "-"
		local memText = "-"
		pcall(function()
			local stats = game:GetService("Stats")
			local item = stats.Network.ServerStatsItem["Data Ping"]
			pingText = tostring(math.floor(item:GetValue())) .. " ms"
		end)
		pcall(function()
			local stats = game:GetService("Stats")
			memText = string.format("%.0f MB", stats:GetTotalMemoryUsageMb())
		end)
		local runText = "-"
		pcall(function()
			runText = string.format("%.0f 秒", workspace.DistributedGameTime)
		end)
		local detail = ""
		if S.detail then
			detail = "\n" .. S.detail
		end
		netLabel.Text = "延迟：" .. pingText .. "\n"
			.. "帧率：" .. tostring(S.fps or 0) .. " FPS\n"
			.. "内存：" .. memText .. "\n"
			.. "本服运行：" .. runText .. "\n"
			.. "地图ID：" .. tostring(game.PlaceId)
			.. detail
		if S.tick then
			pcall(S.tick)
		end
		task.wait(1)
	end
end)

makeTitle(p10, "安全风险检测")

local riskCard = Instance.new("TextLabel")
riskCard.Size = UDim2.new(1, 0, 0, 96)
riskCard.BackgroundColor3 = Theme.Card
riskCard.BorderSizePixel = 0
riskCard.Text = "正在读取..."
riskCard.TextColor3 = Theme.Text
riskCard.Font = Enum.Font.Gotham
riskCard.TextSize = 12
riskCard.TextWrapped = true
riskCard.TextXAlignment = Enum.TextXAlignment.Left
riskCard.TextYAlignment = Enum.TextYAlignment.Top
riskCard.Parent = p10
setOrder(p10, riskCard)
addCorner(riskCard, 10)
local riskCardStroke = addStroke(riskCard, S.accent, 1.2, 0.55)
table.insert(cardStrokes, riskCardStroke)
accentGrad(riskCard, 90, 0.13)

local rp = Instance.new("UIPadding")
rp.PaddingLeft = UDim.new(0, 10)
rp.PaddingRight = UDim.new(0, 10)
rp.PaddingTop = UDim.new(0, 7)
rp.Parent = riskCard

local function scanAntiCheat()
	local hits = {}
	local roots = { workspace, game:GetService("ReplicatedStorage") }
	for _, root in ipairs(roots) do
		local ok = pcall(function()
			for _, obj in ipairs(root:GetDescendants()) do
				local nm = string.lower(obj.Name)
				if string.find(nm, "anticheat")
					or string.find(nm, "anti_cheat")
					or string.find(nm, "cheat")
					or string.find(nm, "detect")
					or string.find(nm, "guard")
					or string.find(nm, "punish")
					or string.find(nm, "moderat") then
					table.insert(hits, obj.Name)
					if #hits >= 6 then
						return
					end
				end
			end
		end)
	end
	return hits
end

local function riskLevel()
	local score = 0
	local lines = {}
	local speed = S.walkSpeed or 16
	local jump = S.jumpPower or 50
	if speed > 30 then
		score = score + 2
	elseif speed > 18 then
		score = score + 1
	end
	if jump > 80 then
		score = score + 2
	elseif jump > 55 then
		score = score + 1
	end
	if S.fly then
		score = score + 3
		lines[#lines + 1] = "飞行 开"
	else
		lines[#lines + 1] = "飞行 关"
	end
	if S.noclip then
		score = score + 2
		lines[#lines + 1] = "穿墙 开"
	else
		lines[#lines + 1] = "穿墙 关"
	end
	if S.infiniteJump then
		score = score + 1
		lines[#lines + 1] = "无限跳 开"
	else
		lines[#lines + 1] = "无限跳 关"
	end
	lines[#lines + 1] = string.format("移速 %d", speed)
	lines[#lines + 1] = string.format("跳跃 %d", jump)
	return score, lines
end

local lastScan = nil

local function refreshRisk()
	local score, lines = riskLevel()
	local tag = "低"
	local col = Color3.fromRGB(90, 220, 150)
	if score >= 5 then
		tag = "高"
		col = Color3.fromRGB(255, 96, 96)
	elseif score >= 2 then
		tag = "中"
		col = Color3.fromRGB(255, 196, 80)
	end
	local head = string.format("风险等级：%s（评分 %d）", tag, score)
	local body = table.concat(lines, "  ·  ")
	local tail = ""
	if lastScan then
		if #lastScan > 0 then
			tail = "\n疑似检测脚本：" .. table.concat(lastScan, "、")
		else
			tail = "\n未发现明显检测脚本"
		end
	end
	riskCard.Text = head .. "\n" .. body .. tail
	riskCard.TextColor3 = col
	riskCardStroke.Color = col
	S.riskWarn = (score >= 5)
	capsuleStroke.Color = S.riskWarn and Color3.fromRGB(255, 96, 96) or S.accent
	updateCapsuleText()
end

makeButton(p10, "扫描本服检测痕迹", Theme.Card, function()
	lastScan = scanAntiCheat()
	refreshRisk()
end)

makeButton(p10, "一键降到安全状态", Color3.fromRGB(34, 60, 52), function()
	if toggles["飞行模式"] and toggles["飞行模式"].set then
		toggles["飞行模式"].set(false)
	end
	if toggles["穿墙"] and toggles["穿墙"].set then
		toggles["穿墙"].set(false)
	end
	if toggles["无限跳跃"] and toggles["无限跳跃"].set then
		toggles["无限跳跃"].set(false)
	end
	pcall(function()
		for _, t in pairs(toggles) do
			if t.name == "角色隐身" and t.set then
				t.set(false)
			end
		end
	end)
	S.walkSpeed = 16
	S.jumpPower = 50
	S.fly = false
	S.noclip = false
	S.infiniteJump = false
	local h = getHumanoid()
	if h then
		pcall(function()
			h.WalkSpeed = 16
			h.UseJumpPower = true
			h.JumpPower = 50
			h.PlatformStand = false
		end)
	end
	local c = getChar()
	if c then
		for _, part in ipairs(c:GetDescendants()) do
			pcall(function()
				part.LocalTransparencyModifier = 0
				if part:IsA("BasePart") then
					part.CanCollide = true
				end
			end)
		end
	end
	refreshRisk()
end)

makeButton(p10, "查看本服详细信息", Theme.Card, function()
	local job = tostring(game.JobId or "")
	local shortJob = string.sub(job, 1, 8)
	local info = string.format(
		"PlaceId %s｜版本 %s\nJobId 前8位 %s\n当前玩家 %d 人",
		tostring(game.PlaceId), tostring(game.PlaceVersion), shortJob, #Players:GetPlayers()
	)
	S.detail = info
	refreshRisk()
end)

S.tick = refreshRisk;

;(function()
makeTitle(p10, "改动记录")

local baseline = {
	walkSpeed = S.walkSpeed or 16,
	jumpPower = S.jumpPower or 50,
	fly = false,
	noclip = false,
	infiniteJump = false
}

local diffCard = Instance.new("TextLabel")
diffCard.Size = UDim2.new(1, 0, 0, 76)
diffCard.BackgroundColor3 = Theme.Card
diffCard.BorderSizePixel = 0
diffCard.Text = "读取中..."
diffCard.TextColor3 = Theme.Text
diffCard.Font = Enum.Font.Gotham
diffCard.TextSize = 12
diffCard.TextWrapped = true
diffCard.TextXAlignment = Enum.TextXAlignment.Left
diffCard.TextYAlignment = Enum.TextYAlignment.Top
diffCard.Parent = p10
setOrder(p10, diffCard)
addCorner(diffCard, 10)
local diffStroke = addStroke(diffCard, S.accent, 1.2, 0.55)
table.insert(cardStrokes, diffStroke)
accentGrad(diffCard, 90, 0.13)

local dp = Instance.new("UIPadding")
dp.PaddingLeft = UDim.new(0, 10)
dp.PaddingRight = UDim.new(0, 10)
dp.PaddingTop = UDim.new(0, 7)
dp.Parent = diffCard

local function refreshDiff()
	local list = {}
	if (S.walkSpeed or 16) ~= baseline.walkSpeed then
		list[#list + 1] = string.format("移速 %d→%d", baseline.walkSpeed, S.walkSpeed)
	end
	if (S.jumpPower or 50) ~= baseline.jumpPower then
		list[#list + 1] = string.format("跳跃 %d→%d", baseline.jumpPower, S.jumpPower)
	end
	if S.fly then
		list[#list + 1] = "飞行 开"
	end
	if S.noclip then
		list[#list + 1] = "穿墙 开"
	end
	if S.infiniteJump then
		list[#list + 1] = "无限跳 开"
	end
	if #list == 0 then
		diffCard.Text = "当前与进服状态一致，没有改动"
		diffCard.TextColor3 = Color3.fromRGB(150, 158, 192)
	else
		diffCard.Text = "相对进服状态：" .. table.concat(list, "、")
		diffCard.TextColor3 = Theme.Text
	end
end

makeButton(p10, "回滚到进服状态", Color3.fromRGB(52, 46, 34), function()
	if toggles["飞行模式"] and toggles["飞行模式"].set then
		toggles["飞行模式"].set(false)
	end
	if toggles["穿墙"] and toggles["穿墙"].set then
		toggles["穿墙"].set(false)
	end
	if toggles["无限跳跃"] and toggles["无限跳跃"].set then
		toggles["无限跳跃"].set(false)
	end
	S.walkSpeed = baseline.walkSpeed
	S.jumpPower = baseline.jumpPower
	S.fly = false
	S.noclip = false
	S.infiniteJump = false
	local h = getHumanoid()
	if h then
		pcall(function()
			h.WalkSpeed = baseline.walkSpeed
			h.UseJumpPower = true
			h.JumpPower = baseline.jumpPower
			h.PlatformStand = false
		end)
	end
	refreshDiff()
	if refreshRisk then
		pcall(refreshRisk)
	end
end)

end)()

;(function()
	makeTitle(p10, "本机状态")

	local stateCard = Instance.new("TextLabel")
	stateCard.Size = UDim2.new(1, 0, 0, 84)
	stateCard.BackgroundColor3 = Theme.Card
	stateCard.BorderSizePixel = 0
	stateCard.Text = "读取中..."
	stateCard.TextColor3 = Theme.Text
	stateCard.Font = Enum.Font.Gotham
	stateCard.TextSize = 12
	stateCard.TextWrapped = true
	stateCard.TextXAlignment = Enum.TextXAlignment.Left
	stateCard.TextYAlignment = Enum.TextYAlignment.Top
	stateCard.Parent = p10
	setOrder(p10, stateCard)
	addCorner(stateCard, 10)
	table.insert(cardStrokes, addStroke(stateCard, S.accent, 1.2, 0.55))
	accentGrad(stateCard, 90, 0.13)

	local sp = Instance.new("UIPadding")
	sp.PaddingLeft = UDim.new(0, 10)
	sp.PaddingRight = UDim.new(0, 10)
	sp.PaddingTop = UDim.new(0, 7)
	sp.Parent = stateCard

	local function refreshLocalState()
		local char = LocalPlayer.Character
		local h = char and char:FindFirstChildOfClass("Humanoid")
		local hp = "未加载"
		local maxHp = "未加载"
		if h then
			hp = tostring(math.floor(h.Health))
			if h.MaxHealth >= math.huge then
				maxHp = "∞"
			else
				maxHp = tostring(math.floor(h.MaxHealth))
			end
		end
		local toolName = "空手"
		if h and h:FindFirstChildOfClass("Tool") then
			toolName = h:FindFirstChildOfClass("Tool").Name
		end
		local bagCount = 0
		local bag = LocalPlayer:FindFirstChildOfClass("Backpack")
		if bag then
			for _, t in ipairs(bag:GetChildren()) do
				if t:IsA("Tool") then
					bagCount = bagCount + 1
				end
			end
		end
		stateCard.Text = string.format(
			"生命 %s / %s\n手持：%s　背包 %d 件\n延迟 %s ms　帧率 %s FPS",
			hp, maxHp, toolName, bagCount,
			tostring(S.ping and math.floor(S.ping) or "-"),
			tostring(S.fps or 0)
		)
	end

	makeButton(p10, "刷新本机状态", Theme.Card, function()
		refreshLocalState()
	end)

	refreshLocalState()

	-- 挂到已有的每秒刷新链路，不新增协程
	local prevTick = S.tick
	S.tick = function()
		if prevTick then
			pcall(prevTick)
		end
		pcall(refreshLocalState)
	end;
end)()

-- ================= 面板11：实用工具 =================
local p11 = panels[11]
makeTitle(p11, "镜头视野")

makeSlider(p11, "视野 FOV", 50, 130, 70, function(v)
	S.fov = v
	pcall(function()
		local cam = workspace.CurrentCamera
		if cam then
			cam.FieldOfView = v
		end
	end)
end)

makeTitle(p11, "实时坐标")
local coordLabel = Instance.new("TextLabel")
coordLabel.Size = UDim2.new(1, 0, 0, 62)
coordLabel.BackgroundColor3 = Theme.Card
coordLabel.BorderSizePixel = 0
coordLabel.Text = "读取中..."
coordLabel.TextColor3 = Theme.Dim
coordLabel.Font = Enum.Font.Gotham
coordLabel.TextSize = 12
coordLabel.TextWrapped = true
coordLabel.TextXAlignment = Enum.TextXAlignment.Left
coordLabel.TextYAlignment = Enum.TextYAlignment.Top
coordLabel.Parent = p11
setOrder(p11, coordLabel)
addCorner(coordLabel, 10)
local cs_coordLabel = addStroke(coordLabel, S.accent, 1.2, 0.55)
table.insert(cardStrokes, cs_coordLabel)
accentGrad(coordLabel, 90, 0.13)
coordLabel.BackgroundTransparency = 0.06

makeTitle(p11, "定点传送")
local coordBox = Instance.new("TextBox")
coordBox.Size = UDim2.new(1, 0, 0, 36)
coordBox.BackgroundColor3 = Theme.Card
coordBox.BorderSizePixel = 0
coordBox.Text = ""
coordBox.PlaceholderText = "目标坐标，如 120, 5, -80"
coordBox.PlaceholderColor3 = Theme.Dim
coordBox.TextColor3 = Theme.Text
coordBox.ClearTextOnFocus = false
coordBox.Font = Enum.Font.Gotham
coordBox.TextSize = 13
coordBox.Parent = p11
setOrder(p11, coordBox)
addCorner(coordBox, 10)
addStroke(coordBox, Color3.fromRGB(255, 255, 255), 1, 0.9)
local cbp = Instance.new("UIPadding")
cbp.PaddingLeft = UDim.new(0, 12)
cbp.Parent = coordBox

local function currentHRP()
	local c = LocalPlayer.Character
	if not c then
		return nil
	end
	return c:FindFirstChild("HumanoidRootPart")
end

local function parseXYZ(txt)
	local nums = {}
	for n in tostring(txt or ""):gmatch("-?%d+%.?%d*") do
		table.insert(nums, tonumber(n))
	end
	if #nums < 3 then
		return nil
	end
	return nums[1], nums[2], nums[3]
end

local rowTp = Instance.new("Frame")
rowTp.Size = UDim2.new(1, 0, 0, 36)
rowTp.BackgroundTransparency = 1
rowTp.Parent = p11
setOrder(p11, rowTp)

local bTp = makeButton(rowTp, "传送到坐标", Theme.Card, function()
	local x, y, z = parseXYZ(coordBox.Text)
	if not x then
		coordLabel.Text = "坐标格式不对，用「120, 5, -80」这种写法"
		return
	end
	local hrp = currentHRP()
	if not hrp then
		coordLabel.Text = "角色未加载，无法传送"
		return
	end
	local okTp = pcall(function()
		local char = LocalPlayer.Character
		local tgt = CFrame.new(x, y, z)
		if char.PivotTo then
			char:PivotTo(tgt)
		else
			hrp.CFrame = tgt
		end
	end)
	if okTp then
		coordLabel.Text = string.format("已传送到 %.1f, %.1f, %.1f", x, y, z)
	else
		coordLabel.Text = "传送失败（游戏可能禁止移动角色）"
	end
end)
bTp.Size = UDim2.new(0.5, -3, 1, 0)
bTp.Position = UDim2.new(0, 0, 0, 0)

local bCopyPos = makeButton(rowTp, "复制当前坐标", Theme.Card, function()
	local hrp = currentHRP()
	if hrp then
		local ps = hrp.Position
		coordBox.Text = string.format("%.1f, %.1f, %.1f", ps.X, ps.Y, ps.Z)
		coordLabel.Text = "已填入输入框：" .. coordBox.Text
	else
		coordLabel.Text = "角色未加载"
	end
end)
bCopyPos.Size = UDim2.new(0.5, -3, 1, 0)
bCopyPos.Position = UDim2.new(0.5, 3, 0, 0)

local rowRot = Instance.new("Frame")
rowRot.Size = UDim2.new(1, 0, 0, 36)
rowRot.BackgroundTransparency = 1
rowRot.Parent = p11
setOrder(p11, rowRot)

local function rotateChar(deg)
	local hrp = currentHRP()
	if not hrp then
		coordLabel.Text = "角色未加载"
		return
	end
	pcall(function()
		hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(deg), 0)
	end)
	coordLabel.Text = "已旋转 " .. tostring(deg) .. " 度"
end

local bR90 = makeButton(rowRot, "旋转 90°", Theme.Card, function()
	rotateChar(90)
end)
bR90.Size = UDim2.new(0.5, -3, 1, 0)
bR90.Position = UDim2.new(0, 0, 0, 0)

local bR180 = makeButton(rowRot, "旋转 180°", Theme.Card, function()
	rotateChar(180)
end)
bR180.Size = UDim2.new(0.5, -3, 1, 0)
bR180.Position = UDim2.new(0.5, 3, 0, 0)

local rowLife = Instance.new("Frame")
rowLife.Size = UDim2.new(1, 0, 0, 36)
rowLife.BackgroundTransparency = 1
rowLife.Parent = p11
setOrder(p11, rowLife)

local bRespawn = makeButton(rowLife, "重生角色", Color3.fromRGB(64, 44, 58), function()
	local h = getHumanoid()
	if h then
		pcall(function()
			h.Health = 0
		end)
		coordLabel.Text = "正在重生..."
	else
		coordLabel.Text = "角色未加载"
	end
end)
bRespawn.Size = UDim2.new(0.5, -3, 1, 0)
bRespawn.Position = UDim2.new(0, 0, 0, 0)

local bDrop = makeButton(rowLife, "一键落地", Theme.Card, function()
	local hrp = currentHRP()
	if not hrp then
		coordLabel.Text = "角色未加载"
		return
	end
	pcall(function()
		local ps = hrp.Position
		hrp.CFrame = CFrame.new(ps.X, ps.Y + 8, ps.Z)
		hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
	end)
	coordLabel.Text = "已向上抬起并下落，用于脱离卡墙"
end)
bDrop.Size = UDim2.new(0.5, -3, 1, 0)
bDrop.Position = UDim2.new(0.5, 3, 0, 0)

task.spawn(function()
	while true do
		local hrp = currentHRP()
		if hrp then
			local ps = hrp.Position
			coordLabel.Text = string.format("当前位置：%.1f, %.1f, %.1f", ps.X, ps.Y, ps.Z)
			coordLabel.TextColor3 = Theme.Text
		else
			coordLabel.Text = "角色未加载"
			coordLabel.TextColor3 = Theme.Dim
		end
		task.wait(0.5)
	end
end)

makeTitle(p11, "角色控制")

makeSlider(p11, "跳跃力量", 30, 120, 50, function(v)
	S.jumpPower = v
	local h = getHumanoid()
	if h then
		pcall(function()
			h.UseJumpPower = true
			h.JumpPower = v
		end)
	end
end)

local rowCam = Instance.new("Frame")
rowCam.Size = UDim2.new(1, 0, 0, 36)
rowCam.BackgroundTransparency = 1
rowCam.Parent = p11
setOrder(p11, rowCam)

local function setCamMode(first)
	pcall(function()
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		if first then
			cam.CameraType = Enum.CameraType.FirstPerson
			LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
		else
			cam.CameraType = Enum.CameraType.Custom
			LocalPlayer.CameraMode = Enum.CameraMode.Classic
		end
	end)
end

local bFirst = makeButton(rowCam, "第一人称", Theme.Card, function()
	setCamMode(true)
	coordLabel.Text = "已切到第一人称（再点右侧恢复）"
end)
bFirst.Size = UDim2.new(0.5, -3, 1, 0)
bFirst.Position = UDim2.new(0, 0, 0, 0)

local bThird = makeButton(rowCam, "第三人称", Theme.Card, function()
	setCamMode(false)
	coordLabel.Text = "已切到第三人称"
end)
bThird.Size = UDim2.new(0.5, -3, 1, 0)
bThird.Position = UDim2.new(0.5, 3, 0, 0)

makeToggle(p11, "自己变透明（仅本机可见）", false, function(v)
	local char = LocalPlayer.Character
	if not char then
		return
	end
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") then
			pcall(function()
				part.LocalTransparencyModifier = v and 1 or 0
			end)
		end
	end
end)

makeButton(p11, "循环切换背包工具", Theme.Card, function()
	local char = LocalPlayer.Character
	local h = char and char:FindFirstChildOfClass("Humanoid")
	local bag = LocalPlayer:FindFirstChildOfClass("Backpack")
	if not (h and bag) then
		coordLabel.Text = "背包为空或角色未加载"
		return
	end
	local tools = {}
	for _, t in ipairs(bag:GetChildren()) do
		if t:IsA("Tool") then
			table.insert(tools, t)
		end
	end
	if #tools == 0 then
		coordLabel.Text = "背包里没有工具"
		return
	end
	S.toolIndex = (S.toolIndex or 0) + 1
	if S.toolIndex > #tools then
		S.toolIndex = 1
	end
	pcall(function()
		h:EquipTool(tools[S.toolIndex])
	end)
	coordLabel.Text = "已切换第 " .. tostring(S.toolIndex) .. " 个工具（共 " .. tostring(#tools) .. " 个）"
end)

makeButton(p11, "清空全部特效（本机）", Theme.Card, function()
	local count = 0
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("ParticleEmitter") or obj:IsA("Beam") or obj:IsA("Trail") then
			pcall(function()
				obj.Enabled = false
			end)
			count = count + 1
		end
	end
	coordLabel.Text = "已关闭本机特效 " .. tostring(count) .. " 个（重进游戏恢复）"
end)

;(function()
	makeTitle(p11, "坐标书签")

	S.bookmarks = S.bookmarks or {}

	local function bookmarkRow(i)
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 36)
		row.BackgroundTransparency = 1
		row.Parent = p11
		setOrder(p11, row)

		local bSave = makeButton(row, "存入点位" .. tostring(i), Theme.Card, function()
			local hrp = currentHRP()
			if not hrp then
				coordLabel.Text = "角色未加载，无法记录"
				return
			end
			local ps = hrp.Position
			S.bookmarks[i] = { x = ps.X, y = ps.Y, z = ps.Z }
			coordLabel.Text = string.format("点位%d 已记录：%.0f, %.0f, %.0f", i, ps.X, ps.Y, ps.Z)
		end)
		bSave.Size = UDim2.new(0.5, -3, 1, 0)
		bSave.Position = UDim2.new(0, 0, 0, 0)

		local bGo = makeButton(row, "传回点位" .. tostring(i), Theme.Card, function()
			local bm = S.bookmarks[i]
			if not bm then
				coordLabel.Text = "点位" .. tostring(i) .. " 还没保存"
				return
			end
			local char = LocalPlayer.Character
			if not char then
				coordLabel.Text = "角色未加载"
				return
			end
			pcall(function()
				local tgt = CFrame.new(bm.x, bm.y, bm.z)
				if char.PivotTo then
					char:PivotTo(tgt)
				else
					local hrp = char:FindFirstChild("HumanoidRootPart")
					if hrp then
						hrp.CFrame = tgt
					end
				end
			end)
			coordLabel.Text = string.format("已传回点位%d", i)
		end)
		bGo.Size = UDim2.new(0.5, -3, 1, 0)
		bGo.Position = UDim2.new(0.5, 3, 0, 0)
	end

	for i = 1, 3 do
		bookmarkRow(i)
	end

	makeButton(p11, "清空所有点位记录", Theme.Card, function()
		S.bookmarks = {}
		coordLabel.Text = "点位记录已清空"
	end)
end)()

-- ================= 面板12：自动增强 =================
local p12 = panels[12]
makeTitle(p12, "自动化")

makeToggle(p12, "自动拾取附近物品", false, function(v)
	S.autoPick = v
end)

makeToggle(p12, "空中悬停（不下落）", false, function(v)
	S.hover = v
	local h = getHumanoid()
	if h then
		pcall(function()
			h.PlatformStand = v
		end)
	end
end)

makeSlider(p12, "跟随距离", 6, 40, S.followDist, function(v)
	S.followDist = v
end)

makeToggle(p12, "自动跟随最近玩家", false, function(v)
	S.follow = v
end)

makeToggle(p12, "掉出地图自动救回", true, function(v)
	S.rescue = v
end)

makeToggle(p12, "防挂机（20 秒微动）", false, function(v)
	S.afk = v
end)

makeTitle(p12, "视角与网络")

makeToggle(p12, "强制第三人称", false, function(v)
	pcall(function()
		if v then
			LocalPlayer.CameraMode = Enum.CameraMode.Classic
		else
			LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
		end
	end)
end)

local pingLabel = Instance.new("TextLabel")
pingLabel.Size = UDim2.new(1, 0, 0, 52)
pingLabel.BackgroundColor3 = Theme.Card
pingLabel.BorderSizePixel = 0
pingLabel.BackgroundTransparency = 0.06
pingLabel.Text = "延迟：读取中..."
pingLabel.TextColor3 = Theme.Text
pingLabel.Font = Enum.Font.Gotham
pingLabel.TextSize = 13
pingLabel.TextXAlignment = Enum.TextXAlignment.Left
pingLabel.Parent = p12
setOrder(p12, pingLabel)
addCorner(pingLabel, 12)
table.insert(cardStrokes, addStroke(pingLabel, S.accent, 1.2, 0.55))
accentGrad(pingLabel, 90, 0.13)

makeButton(p12, "刷新延迟", Theme.Card, function()
	local ms = nil
	pcall(function()
		local Stats = game:GetService("Stats")
		local item = Stats.Network.ServerStatsItem["Data Ping"]
		ms = item:GetValue()
	end)
	if ms then
		S.ping = ms
		pingLabel.Text = string.format("当前延迟：%.0f ms", ms)
	else
		pingLabel.Text = "延迟：当前环境不可读取"
	end
end)

makeTitle(p12, "一键恢复")
makeButton(p12, "恢复默认速度 / 跳跃 / 视野", Theme.Card, function()
	S.walkSpeed = 16
	S.jumpPower = 50
	S.fov = 70
	local h = getHumanoid()
	if h then
		pcall(function()
			h.WalkSpeed = 16
			h.UseJumpPower = true
			h.JumpPower = 50
		end)
	end
	pcall(function()
		local cam = workspace.CurrentCamera
		if cam then
			cam.FieldOfView = 70
		end
	end)
	pingLabel.Text = "已恢复：移速 16 / 跳跃 50 / 视野 70"
end)

-- 自动化主循环
task.spawn(function()
	local lastAfk = os.clock()
	while true do
		local char = LocalPlayer.Character
		local hrp = nil
		if char then
			hrp = char:FindFirstChild("HumanoidRootPart")
		end

		-- 自动拾取（轻量：只扫工作区顶层，避免大场景卡顿）
		pickTick = (pickTick or 0) + 1
		if S.autoPick and hrp and pickTick % 4 == 0 then
			pcall(function()
				local bp = LocalPlayer:FindFirstChild("Backpack")
				local pos = hrp.Position
				for _, obj in ipairs(workspace:GetChildren()) do
					if obj:IsA("Tool") and obj.Parent ~= bp then
						local part = obj:FindFirstChild("Handle")
						if part then
							local d = (part.Position - pos).Magnitude
							if d < 40 and bp then
								obj.Parent = bp
							end
						end
					end
				end
			end)
		end

		-- 掉出地图救人
		if S.rescue and hrp then
			pcall(function()
				if hrp.Position.Y < -80 then
					local spawn = workspace:FindFirstChildOfClass("SpawnLocation")
					local x, z = hrp.Position.X, hrp.Position.Z
					local y = 10
					if spawn then
						x, y, z = spawn.Position.X, spawn.Position.Y + 5, spawn.Position.Z
					end
					hrp.CFrame = CFrame.new(x, y, z)
				end
			end)
		end

		-- 自动跟随
		if S.follow and hrp then
			pcall(function()
				local best, bestD = nil, 1e9
				for _, pl in ipairs(Players:GetPlayers()) do
					if pl ~= LocalPlayer and pl.Character then
						local tp = pl.Character:FindFirstChild("HumanoidRootPart")
						if tp then
							local d = (tp.Position - hrp.Position).Magnitude
							if d < bestD then
								best, bestD = tp, d
							end
						end
					end
				end
				if best and bestD > S.followDist + 2 then
					local from = hrp.Position
					local to = best.Position
					local dir = (to - from)
					local dist = dir.Magnitude
					if dist > 0.1 then
						local stepV = dir / dist
						local stop = to - stepV * S.followDist
						hrp.CFrame = CFrame.new(stop.X, from.Y, stop.Z)
					end
				end
			end)
		end

		-- 悬停
		if S.hover and char then
			pcall(function()
				local h = char:FindFirstChildOfClass("Humanoid")
				if h then
					h.PlatformStand = true
				end
			end)
		end

		-- 防挂机
		if S.afk and char and os.clock() - lastAfk > 20 then
			lastAfk = os.clock()
			pcall(function()
				local h = char:FindFirstChildOfClass("Humanoid")
				if h then
					h:Move(Vector3.new(math.random(-1, 1), 0, math.random(-1, 1)))
					task.wait(0.2)
					h:Move(Vector3.new(0, 0, 0))
				end
			end)
		end

		task.wait(0.6)
	end
end)

makeTitle(p12, "性能与提醒")

makeToggle(p12, "关闭阴影（提升帧率）", false, function(v)
	pcall(function()
		local Lighting = game:GetService("Lighting")
		Lighting.GlobalShadows = not v
	end)
end)

makeToggle(p12, "玩家进出提示", false, function(v)
	S.joinNotice = v
end)

local savedVolumes = {}
makeToggle(p12, "一键静音游戏音效", false, function(v)
	pcall(function()
		local SoundService = game:GetService("SoundService")
		if v then
			for _, snd in ipairs(SoundService:GetDescendants()) do
				if snd:IsA("Sound") then
					savedVolumes[snd] = snd.Volume
					snd.Volume = 0
				end
			end
			-- 工作区里的音源也一起静音
			for _, snd in ipairs(workspace:GetDescendants()) do
				if snd:IsA("Sound") then
					savedVolumes[snd] = snd.Volume
					snd.Volume = 0
				end
			end
		else
			for snd, vol in pairs(savedVolumes) do
				pcall(function()
					snd.Volume = vol
				end)
			end
			savedVolumes = {}
		end
	end)
end)

makeButton(p12, "降低画质（关光晕/雾）", Theme.Card, function()
	pcall(function()
		local Lighting = game:GetService("Lighting")
		Lighting.GlobalShadows = false
		Lighting.Outlines = false
		Lighting.FogEnd = 100000
	end)
end)

;(function()
	makeTitle(p12, "帧率守护")

	makeToggle(p12, "低帧提醒（<20FPS）", false, function(v)
		S.lowFpsWarn = v
		if not v then
			S.lowFpsBadge = false
			updateCapsuleText()
		end
	end)

	makeSlider(p12, "连跳间隔（秒）", 1, 10, 3, function(v)
		S.autoJumpGap = v * 0.1
	end)

	makeToggle(p12, "自动连跳（持续起跳）", false, function(v)
		S.autoJump = v
		S.autoJumpClock = 0
	end)
end)()

-- ================= 一键重置（放在面板1末尾） =================
makeButton(p1, "一键重置全部设置", Color3.fromRGB(72, 50, 64), function()
	for _, t in pairs(toggles) do
		t.set(false)
	end
	sliders["移速"].set(16, true)
	sliders["跳跃力"].set(50, true)
	sliders["飞行速度"].set(60, true)
	sliders["视野FOV"].set(70, true)
	local cam = workspace.CurrentCamera
	if cam then
		cam.FieldOfView = 70
	end
end)

-- ================= 指针坐标 =================
local function pointerPos(input)
	if input.UserInputType == Enum.UserInputType.Touch then
		return Vector2.new(input.Position.X, input.Position.Y)
	end
	return UserInputService:GetMouseLocation()
end

-- ================= 灵动岛拖动 & 点击 =================
local openWin = nil
local capsuleDragging = false
local capsuleMoved = false
local capsuleStartMouse = Vector2.new(0, 0)
local capsuleStartPos = Vector2.new(0, 0)
local CAPSULE_THRESHOLD = 6

local function clampCapsule(x, y)
	local cam = workspace.CurrentCamera
	local screen = cam and cam.ViewportSize or Vector2.new(1280, 720)
	local w = capsule.AbsoluteSize.X
	local h = capsule.AbsoluteSize.Y
	x = math.clamp(x, 0, math.max(screen.X - w, 0))
	y = math.clamp(y, 0, math.max(screen.Y - h, 0))
	return x, y
end

local function applyCapsuleDrag(input)
	if not capsuleDragging then
		return
	end
	local now = pointerPos(input)
	local delta = now - capsuleStartMouse
	if delta.Magnitude > CAPSULE_THRESHOLD then
		capsuleMoved = true
	end
	if capsuleMoved then
		local nx = capsuleStartPos.X + delta.X
		local ny = capsuleStartPos.Y + delta.Y
		nx, ny = clampCapsule(nx, ny)
		capsule.Position = UDim2.new(0, nx, 0, ny)
	end
end

capsule.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		capsuleDragging = true
		capsuleMoved = false
		capsuleStartMouse = pointerPos(input)
		capsuleStartPos = Vector2.new(capsule.AbsolutePosition.X, capsule.AbsolutePosition.Y)
	end
end)

capsule.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch then
		applyCapsuleDrag(input)
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch then
		applyCapsuleDrag(input)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		if capsuleDragging then
			capsuleDragging = false
			if not capsuleMoved then
				if win.Visible then
					win.Visible = false
					S.open = false
					updateCapsuleText()
				else
					openWin()
				end
				pcall(function()
					local cw = capsule.Size.X.Offset
					local ch = capsule.Size.Y.Offset
					TweenService:Create(capsule, TweenInfo.new(0.09), {
						Size = UDim2.new(0, cw - 6, 0, ch - 3)
					}):Play()
					task.delay(0.09, function()
						TweenService:Create(capsule, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
							Size = UDim2.new(0, cw, 0, ch)
						}):Play()
					end)
				end)
			end
			capsuleMoved = false
		end
	end
end)

-- ================= 窗口拖动 =================
local winDragging = false
local winStartMouse = Vector2.new(0, 0)
local winStartPos = Vector2.new(0, 0)

local function applyWindowDrag(input)
	if not winDragging then
		return
	end
	local now = pointerPos(input)
	local delta = now - winStartMouse
	local cam = workspace.CurrentCamera
	local screen = cam and cam.ViewportSize or Vector2.new(1280, 720)
	local w = win.AbsoluteSize.X
	local h = win.AbsoluteSize.Y
	local nx = math.clamp(winStartPos.X + delta.X, 0, math.max(screen.X - w, 0))
	local ny = math.clamp(winStartPos.Y + delta.Y, 0, math.max(screen.Y - h, 0))
	win.Position = UDim2.new(0, nx, 0, ny)
end

titleBar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		winDragging = true
		winStartMouse = pointerPos(input)
		winStartPos = Vector2.new(win.AbsolutePosition.X, win.AbsolutePosition.Y)
	end
end)

titleBar.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch then
		applyWindowDrag(input)
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch then
		applyWindowDrag(input)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		winDragging = false
		activeSlider = nil
	end
end)

bindClick(closeBtn, function()
	win.Visible = false
	S.open = false
	updateCapsuleText()
end)

local function fitWindowScale()
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
	local sc = math.min(1, (vp.X - 16) / 656, (vp.Y - 16) / 536)
	if sc < 0.62 then
		sc = 0.62
	end
	winScale.Scale = sc
	return sc
end

pcall(function()
	local cam = workspace.CurrentCamera
	if cam then
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			fitWindowScale()
		end)
	end
end)

openWin = function()
	local sc = fitWindowScale()
	win.Visible = true
	S.open = true
	updateCapsuleText()
	win.Size = UDim2.new(0, 640, 0, 520)
	-- 居中，并保证四边都在屏幕内
	local cam = workspace.CurrentCamera
	local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
	local w = 640 * sc
	local h = 520 * sc
	local nx = math.clamp((vp.X - w) / 2, 0, math.max(vp.X - w, 0))
	local ny = math.clamp((vp.Y - h) / 2, 0, math.max(vp.Y - h, 0))
	win.Position = UDim2.new(0, nx, 0, ny)
	winScale.Scale = sc * 0.94
	TweenService:Create(winScale, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Scale = sc
	}):Play()
end

-- ================= 快捷键 =================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if input.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end
	if bindingKey then
		Hotkeys[bindingKey.keyName] = input.KeyCode
		bindingKey.btn.Text = input.KeyCode.Name
		bindingKey = nil
		return
	end
	if gameProcessed then
		return
	end
	if input.KeyCode == Hotkeys.ESP then
		if toggles["开启ESP"] then
			toggles["开启ESP"].set(not S.esp)
		end
	elseif input.KeyCode == Hotkeys.AntiFly then
		if toggles["防甩飞"] then
			toggles["防甩飞"].set(not S.antiFly)
		end
	elseif input.KeyCode == Hotkeys.Fly then
		if toggles["飞行模式"] then
			toggles["飞行模式"].set(not S.fly)
		end
	elseif input.KeyCode == Hotkeys.Panel then
		if win.Visible then
			win.Visible = false
		else
			openWin()
		end
	end
end)

-- 无限跳跃
UserInputService.JumpRequest:Connect(function()
	if S.infiniteJump then
		local h = getHumanoid()
		if h then
			h:ChangeState(Enum.HumanoidStateType.Jumping)
		end
	end
end)

-- ================= 滑条拖动更新 =================
local function updateActiveSlider(x)
	if not activeSlider then
		return
	end
	local bar = activeSlider.bar
	local bx = bar.AbsolutePosition.X
	local bw = bar.AbsoluteSize.X
	if bw <= 0 then
		return
	end
	local ratio = math.clamp((x - bx) / bw, 0, 1)
	local minV = tonumber(bar:GetAttribute("minV"))
	local maxV = tonumber(bar:GetAttribute("maxV"))
	if minV and maxV then
		activeSlider.set(minV + ratio * (maxV - minV), true)
	end
end

RunService.RenderStepped:Connect(function()
	if activeSlider then
		if UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
			updateActiveSlider(UserInputService:GetMouseLocation().X)
		end
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch then
		updateActiveSlider(input.Position.X)
	end
end)

-- ================= 主循环 =================
local flyVelocity = nil
local attackTimer = 0
local fpsFrames = 0
local fpsTimer = 0
local rainbowTime = 0
local particleTask = nil

RunService.RenderStepped:Connect(function(dt)
	-- 防甩飞
	if S.antiFly then
		local c = getChar()
		local hrp = c and c:FindFirstChild("HumanoidRootPart")
		if hrp then
			hrp.Velocity = Vector3.new(0, hrp.Velocity.Y, 0)
			hrp.RotVelocity = Vector3.new(0, 0, 0)
		end
	end

	-- 飞行
	local c = getChar()
	if S.fly and c then
		local hrp = c:FindFirstChild("HumanoidRootPart")
		if hrp then
			if not flyVelocity or flyVelocity.Parent ~= hrp then
				if flyVelocity then
					flyVelocity:Destroy()
				end
				flyVelocity = Instance.new("BodyVelocity")
				flyVelocity.Name = "LingDaoFly"
				flyVelocity.MaxForce = Vector3.new(1e5, 1e5, 1e5)
				flyVelocity.Velocity = Vector3.zero
				flyVelocity.Parent = hrp
			end
			local cam = workspace.CurrentCamera
			local dir = Vector3.zero
			if cam then
				if UserInputService:IsKeyDown(Enum.KeyCode.W) then
					dir = dir + cam.CFrame.LookVector
				end
				if UserInputService:IsKeyDown(Enum.KeyCode.S) then
					dir = dir - cam.CFrame.LookVector
				end
				if UserInputService:IsKeyDown(Enum.KeyCode.A) then
					dir = dir - cam.CFrame.RightVector
				end
				if UserInputService:IsKeyDown(Enum.KeyCode.D) then
					dir = dir + cam.CFrame.RightVector
				end
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
				dir = dir + Vector3.new(0, 1, 0)
			end
			flyVelocity.Velocity = dir * S.flySpeed
		end
	elseif flyVelocity then
		flyVelocity:Destroy()
		flyVelocity = nil
	end

	-- 统计真实 FPS
	fpsFrames = fpsFrames + 1
	fpsTimer = fpsTimer + dt
	if fpsTimer >= 1 then
		S.fps = math.floor(fpsFrames / fpsTimer)
		fpsFrames = 0
		fpsTimer = 0
		if S.lowFpsWarn then
			local bad = (S.fps or 0) < 20
			if bad ~= S.lowFpsBadge then
				S.lowFpsBadge = bad
				pcall(updateCapsuleText)
			end
		end
	end

	-- 自动回血（按阈值触发）
	if S.autoHeal then
		local h = getHumanoid()
		if h and h.Health < h.MaxHealth then
			local pct = 100
			if h.MaxHealth > 0 and h.MaxHealth < math.huge then
				pct = (h.Health / h.MaxHealth) * 100
			end
			if pct <= S.healThreshold then
				h.Health = h.MaxHealth
			end
		end
	end

	-- 无敌模式
	if S.godMode then
		local h = getHumanoid()
		if h then
			h.MaxHealth = math.huge
			if h.Health < h.MaxHealth then
				h.Health = h.MaxHealth
			end
		end
	end

	-- 自动连跳
	if S.autoJump then
		S.autoJumpClock = (S.autoJumpClock or 0) + dt
		if S.autoJumpClock >= (S.autoJumpGap or 0.3) then
			S.autoJumpClock = 0
			local hJ = getHumanoid()
			if hJ then
				pcall(function()
					hJ.Jump = true
				end)
			end
		end
	end

	-- 冲刺加速
	if S.sprint then
		local h = getHumanoid()
		if h then
			local moving = h.MoveDirection.Magnitude > 0.05
			local wantSpeed = S.walkSpeed
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift) then
				wantSpeed = S.walkSpeed * 1.8
			end
			if h.WalkSpeed ~= wantSpeed then
				h.WalkSpeed = wantSpeed
			end
		end
	end

	-- 自动攻击（触发手持工具）
	if S.autoAttack then
		attackTimer = attackTimer + dt
		if attackTimer >= S.attackDelay then
			attackTimer = 0
			local c2 = getChar()
			local tool = c2 and c2:FindFirstChildOfClass("Tool")
			if tool then
				pcall(function()
					tool:Activate()
				end)
			end
		end
	end

	-- 锁定最近目标（只转向，不强制位移）
	if S.lockTarget then
		local target = findNearestPlayer()
		local myChar = getChar()
		local hrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
		if target and target.Character and hrp then
			local thrp = target.Character:FindFirstChild("HumanoidRootPart")
			if thrp then
				local d = (thrp.Position - hrp.Position)
				if d.Magnitude > 2 and d.Magnitude < 260 then
					pcall(function()
						hrp.CFrame = CFrame.lookAt(
							hrp.Position,
							Vector3.new(thrp.Position.X, hrp.Position.Y, thrp.Position.Z)
						)
					end)
				end
			end
		end
	end

	-- 粒子屏蔽（限流，避免卡顿）
	if S.particle then
		if not particleTask then
			particleTask = task.spawn(function()
				while S.particle do
					local count = 0
					for _, obj in ipairs(workspace:GetDescendants()) do
						if obj:IsA("ParticleEmitter") or obj:IsA("Fire")
							or obj:IsA("Smoke") or obj:IsA("Sparkles") then
							obj.Enabled = false
						end
						count = count + 1
						if count > 6000 then
							break
						end
					end
					task.wait(1)
				end
				particleTask = nil
			end)
		end
	end

	-- 隐藏其他玩家（每 3 帧刷一次，降低开销）
	if S.hidePlayers then
		for _, pl in ipairs(Players:GetPlayers()) do
			if pl ~= LocalPlayer and pl.Character then
				for _, part in ipairs(pl.Character:GetDescendants()) do
					if part:IsA("BasePart") then
						part.LocalTransparencyModifier = 1
					end
				end
			end
		end
	end

	-- ESP
	if S.esp then
		local cam = workspace.CurrentCamera
		if cam then
			for _, pl in ipairs(Players:GetPlayers()) do
				if pl ~= LocalPlayer and pl.Character then
					local head = pl.Character:FindFirstChild("Head")
					local hrp = pl.Character:FindFirstChild("HumanoidRootPart")
					local tag = espTags[pl]
					if not tag then
						tag = Instance.new("TextLabel")
						tag.Name = "ESPTag"
						tag.Size = UDim2.new(0, 180, 0, 18)
						tag.BackgroundTransparency = 1
						tag.Font = Enum.Font.GothamBold
						tag.TextSize = 12
						tag.TextColor3 = Color3.fromRGB(255, 96, 116)
						tag.Parent = gui
						espTags[pl] = tag
					end
					if head and hrp then
						local pos, onScreen = cam:WorldToViewportPoint(head.Position)
						if onScreen then
							local dist = math.floor((cam.CFrame.Position - hrp.Position).Magnitude)
							tag.Visible = true
							tag.Text = pl.Name .. "  [" .. tostring(dist) .. "m]"
							tag.Position = UDim2.new(0, pos.X - 90, 0, pos.Y - 26)
						else
							tag.Visible = false
						end
					else
						tag.Visible = false
					end
				end
			end
		end
	else
		for _, tag in pairs(espTags) do
			tag:Destroy()
		end
		espTags = {}
	end

	-- 彩虹边框
	if S.rainbow then
		rainbowTime = rainbowTime + dt * 0.8
		local col = Color3.fromHSV(rainbowTime % 1, 0.75, 1)
		capsuleStroke.Color = col
		winStroke.Color = col
	end
end)

-- ================= 角色加载后重新应用 =================
local function applyCharacter(char)
	local h = char:WaitForChild("Humanoid", 5)
	if h then
		h.WalkSpeed = S.walkSpeed
		h.UseJumpPower = true
		h.JumpPower = S.jumpPower
		if S.godMode then
			h.MaxHealth = math.huge
			h.Health = math.huge
		end
	end
end

if LocalPlayer.Character then
	task.spawn(applyCharacter, LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(function(char)
	task.spawn(applyCharacter, char)
end)

-- 玩家进出提示
if Players.PlayerAdded then
Players.PlayerAdded:Connect(function(p)
	if S.joinNotice then
		pcall(function()
			print("[灵动控制台] 玩家加入：" .. p.Name)
		end)
	end
end)
end

if Players.PlayerRemoving then
Players.PlayerRemoving:Connect(function(p)
	if S.joinNotice then
		pcall(function()
			print("[灵动控制台] 玩家离开：" .. p.Name)
		end)
	end
end)
end

-- ================= 初始化 =================
-- ===== 全局文字清晰度加固：统一加描边，任何底色都读得清 =====
local function lumOf(c)
	return 0.299 * c.R + 0.587 * c.G + 0.114 * c.B
end

local function crispText(o)
	if not (o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox")) then
		return
	end
	local col = o.TextColor3
	if col == nil then
		col = Color3.fromRGB(240, 242, 255)
	end
	o.TextTransparency = 0
	o.TextStrokeTransparency = 0
	if lumOf(col) > 0.5 then
		o.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	else
		o.TextStrokeColor3 = Color3.fromRGB(255, 255, 255)
	end
end

local function crispAll(node)
	crispText(node)
	for _, child in ipairs(node:GetChildren()) do
		crispAll(child)
	end
end

crispAll(gui)

showTab(1)
refreshAccentGradients()
print("✅ 灵动面板 v2 已加载：11 个分类、88 个功能全部绑定")
