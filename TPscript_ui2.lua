--[[
    Roblox 悬浮控制台｜美化稳定版
    目标：灵动岛可点开 / 功能常驻不消失 / 界面可见 / 飞行生效 / 现代深色外观
    规避：CornerRadius直赋 / 非法Transparency / 前向引用 / WrapMode废弃API / 标签遮挡点击
    飞行：CFrame 位移式（RenderStepped 驱动），不依赖 Velocity，不易被游戏覆盖
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local GUI_NAME = "StableHubFinal"
local oldGui = PlayerGui:FindFirstChild(GUI_NAME)
if oldGui then oldGui:Destroy() end

-- ============ 状态（提前声明，避免前向引用） ============
local isOpen = false
local flyEnabled = false
local flySpeed = 1.8
local antiKnockback = false
local invisible = false
local autoHeal = false
local selectedPlayer = nil

local setActiveView
local applyInvisibility

-- ============ 配色（现代深色 + 青蓝强调） ============
local COLOR = {
    main = Color3.fromRGB(30, 33, 40),
    side = Color3.fromRGB(23, 25, 31),
    content = Color3.fromRGB(34, 37, 44),
    btn = Color3.fromRGB(52, 56, 64),
    btnAlt = Color3.fromRGB(44, 48, 56),
    accent = Color3.fromRGB(74, 144, 255),
    accent2 = Color3.fromRGB(126, 92, 255),
    stroke = Color3.fromRGB(70, 76, 88),
    text = Color3.new(1, 1, 1),
    subText = Color3.fromRGB(178, 184, 196),
}

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = GUI_NAME
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
ScreenGui.DisplayOrder = 999
ScreenGui.Parent = PlayerGui

local function addCorner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = radius
    c.Parent = parent
end

local function addGradient(parent, c1, c2, rotation)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new(c1, c2)
    g.Rotation = rotation or 0
    g.Parent = parent
end

local function addStroke(parent, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color
    s.Thickness = thickness or 1
    s.Parent = parent
end

-- ============ 灵动岛（原生按钮 + 放大热区 + Modal） ============
local IslandBtn = Instance.new("TextButton")
IslandBtn.AnchorPoint = Vector2.new(0.5, 0)
IslandBtn.Position = UDim2.new(0.5, 0, 0, 12)
IslandBtn.Size = UDim2.new(0, 140, 0, 48)
IslandBtn.BackgroundTransparency = 1
IslandBtn.Text = ""
IslandBtn.Modal = true
IslandBtn.ZIndex = 10
IslandBtn.Parent = ScreenGui

local IslandVisual = Instance.new("Frame")
IslandVisual.AnchorPoint = Vector2.new(0.5, 0.5)
IslandVisual.Position = UDim2.new(0.5, 0, 0.5, 0)
IslandVisual.Size = UDim2.new(0, 100, 0, 32)
IslandVisual.BackgroundColor3 = COLOR.side
IslandVisual.ZIndex = 9
IslandVisual.Parent = IslandBtn
addCorner(IslandVisual, UDim.new(1, 0))
addGradient(IslandVisual, Color3.fromRGB(42, 46, 56), Color3.fromRGB(24, 26, 32), 0)
addStroke(IslandVisual, COLOR.accent, 1)

-- 左侧状态圆点
local IslandDot = Instance.new("Frame")
IslandDot.AnchorPoint = Vector2.new(0, 0.5)
IslandDot.Position = UDim2.new(0, 12, 0.5, 0)
IslandDot.Size = UDim2.new(0, 8, 0, 8)
IslandDot.BackgroundColor3 = COLOR.accent
IslandDot.ZIndex = 9
IslandDot.Parent = IslandVisual
addCorner(IslandDot, UDim.new(1, 0))

local IslandLabel = Instance.new("TextLabel")
IslandLabel.AnchorPoint = Vector2.new(0.5, 0.5)
IslandLabel.Position = UDim2.new(0.55, 0, 0.5, 0)
IslandLabel.Size = UDim2.new(0.7, 0, 0.75, 0)
IslandLabel.BackgroundTransparency = 1
IslandLabel.Text = "灵动岛"
IslandLabel.TextColor3 = COLOR.text
IslandLabel.Font = Enum.Font.GothamBold
IslandLabel.TextSize = 12
IslandLabel.Active = false
IslandLabel.ZIndex = 9
IslandLabel.Parent = IslandVisual

-- ============ 主窗口 ============
local MainWindow = Instance.new("Frame")
MainWindow.AnchorPoint = Vector2.new(0.5, 0.5)
MainWindow.Position = UDim2.new(0.5, 0, 0.5, 0)
MainWindow.Size = UDim2.new(0, 520, 0, 380)
MainWindow.BackgroundColor3 = COLOR.main
MainWindow.Visible = false
MainWindow.ZIndex = 11
MainWindow.Parent = ScreenGui
addCorner(MainWindow, UDim.new(0.08, 0))
addStroke(MainWindow, COLOR.stroke, 1)

-- 标题栏（拖拽手柄）
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 38)
TitleBar.BackgroundColor3 = COLOR.side
TitleBar.Parent = MainWindow
addCorner(TitleBar, UDim.new(0.08, 0))
addGradient(TitleBar, Color3.fromRGB(38, 42, 50), Color3.fromRGB(26, 28, 34), 0)

-- 标题左侧装饰竖条
local TitleAccent = Instance.new("Frame")
TitleAccent.AnchorPoint = Vector2.new(0, 0.5)
TitleAccent.Position = UDim2.new(0, 12, 0.5, 0)
TitleAccent.Size = UDim2.new(0, 4, 0, 18)
TitleAccent.BackgroundColor3 = COLOR.accent
TitleAccent.Parent = TitleBar
addCorner(TitleAccent, UDim.new(1, 0))

local TitleText = Instance.new("TextLabel")
TitleText.Size = UDim2.new(1, -60, 1, 0)
TitleText.Position = UDim2.new(0, 24, 0, 0)
TitleText.BackgroundTransparency = 1
TitleText.Text = "功能控制台"
TitleText.TextColor3 = COLOR.text
TitleText.Font = Enum.Font.GothamBold
TitleText.TextSize = 14
TitleText.TextXAlignment = Enum.TextXAlignment.Left
TitleText.Active = false
TitleText.Parent = TitleBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.AnchorPoint = Vector2.new(1, 0.5)
CloseBtn.Position = UDim2.new(1, -10, 0.5, 0)
CloseBtn.Size = UDim2.new(0, 28, 0, 28)
CloseBtn.BackgroundColor3 = Color3.fromRGB(190, 55, 55)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = COLOR.text
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 12
CloseBtn.Parent = TitleBar
addCorner(CloseBtn, UDim.new(1, 0))

-- 拖拽
local function makeDraggable(frame, handle)
    local dragging = false
    local dragStart, startPos
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            local vp = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(800, 600)
            local nx = math.clamp(startPos.X.Offset + delta.X, 30, vp.X - 30)
            local ny = math.clamp(startPos.Y.Offset + delta.Y, 30, vp.Y - 30)
            frame.Position = UDim2.new(0, nx, 0, ny)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end
makeDraggable(MainWindow, TitleBar)

-- 左侧分类
local LeftBar = Instance.new("Frame")
LeftBar.Position = UDim2.new(0, 0, 0, 38)
LeftBar.Size = UDim2.new(0, 140, 1, -38)
LeftBar.BackgroundColor3 = COLOR.side
LeftBar.Parent = MainWindow

local LeftLayout = Instance.new("UIListLayout")
LeftLayout.Padding = UDim.new(0, 8)
LeftLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
LeftLayout.VerticalAlignment = Enum.VerticalAlignment.Top
LeftLayout.Parent = LeftBar

local LeftPadding = Instance.new("UIPadding")
LeftPadding.PaddingTop = UDim.new(0, 12)
LeftPadding.PaddingLeft = UDim.new(0, 10)
LeftPadding.PaddingRight = UDim.new(0, 10)
LeftPadding.Parent = LeftBar

-- 右侧内容
local RightPanel = Instance.new("Frame")
RightPanel.Position = UDim2.new(0, 140, 0, 38)
RightPanel.Size = UDim2.new(1, -140, 1, -38)
RightPanel.BackgroundColor3 = COLOR.content
RightPanel.Parent = MainWindow

-- ============ 视图：功能面板 ============
local FuncView = Instance.new("Frame")
FuncView.Size = UDim2.new(1, 0, 1, 0)
FuncView.BackgroundTransparency = 1
FuncView.Parent = RightPanel
FuncView.Visible = false

local FuncHint = Instance.new("TextLabel")
FuncHint.Size = UDim2.new(1, -24, 0, 24)
FuncHint.Position = UDim2.new(0, 12, 0, 10)
FuncHint.BackgroundTransparency = 1
FuncHint.Text = "功能 | F1 面板 · F2 飞行 · F3 隐身"
FuncHint.TextColor3 = COLOR.subText
FuncHint.Font = Enum.Font.Gotham
FuncHint.TextSize = 12
FuncHint.TextXAlignment = Enum.TextXAlignment.Left
FuncHint.Active = false
FuncHint.Parent = FuncView

local function makeFuncButton(name, y, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 220, 0, 38)
    btn.Position = UDim2.new(0.5, 0, 0, y)
    btn.AnchorPoint = Vector2.new(0.5, 0)
    btn.BackgroundColor3 = COLOR.btn
    btn.Text = name
    btn.TextColor3 = COLOR.text
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 12
    btn.ZIndex = 2
    btn.Parent = FuncView
    addCorner(btn, UDim.new(0.14, 0))
    addStroke(btn, COLOR.stroke, 1)
    btn.Activated:Connect(callback)
    return btn
end

local FlyBtn = makeFuncButton("飞行：关闭", 42, function()
    flyEnabled = not flyEnabled
    FlyBtn.Text = flyEnabled and "飞行：开启" or "飞行：关闭"
end)

local AntiKbBtn = makeFuncButton("防甩飞：关闭", 86, function()
    antiKnockback = not antiKnockback
    AntiKbBtn.Text = antiKnockback and "防甩飞：开启" or "防甩飞：关闭"
end)

local InvisBtn = makeFuncButton("隐身：关闭", 130, function()
    invisible = not invisible
    InvisBtn.Text = invisible and "隐身：开启" or "隐身：关闭"
    applyInvisibility()
end)

local HealBtn = makeFuncButton("自动回血：关闭", 174, function()
    autoHeal = not autoHeal
    HealBtn.Text = autoHeal and "自动回血：开启" or "自动回血：关闭"
end)

local TeleportBtn = makeFuncButton("传送到选中玩家", 218, function()
    pcall(function()
        if not selectedPlayer or not selectedPlayer.Character then return end
        local myChar = LocalPlayer.Character
        local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
        local targetHrp = selectedPlayer.Character:FindFirstChild("HumanoidRootPart")
        if myHrp and targetHrp then
            myHrp.CFrame = targetHrp.CFrame
        end
    end)
end)

local ResetBtn = makeFuncButton("重置角色", 262, function()
    pcall(function() LocalPlayer:LoadCharacter() end)
end)

-- 飞行速度输入
local SpeedLabel = Instance.new("TextLabel")
SpeedLabel.Size = UDim2.new(0, 120, 0, 24)
SpeedLabel.Position = UDim2.new(0.5, 0, 0, 306)
SpeedLabel.AnchorPoint = Vector2.new(0.5, 0)
SpeedLabel.BackgroundTransparency = 1
SpeedLabel.Text = "飞行速度：" .. tostring(flySpeed)
SpeedLabel.TextColor3 = COLOR.text
SpeedLabel.Font = Enum.Font.Gotham
SpeedLabel.TextSize = 12
SpeedLabel.Active = false
SpeedLabel.Parent = FuncView

local SpeedBox = Instance.new("TextBox")
SpeedBox.Size = UDim2.new(0, 120, 0, 32)
SpeedBox.Position = UDim2.new(0.5, 0, 0, 332)
SpeedBox.AnchorPoint = Vector2.new(0.5, 0)
SpeedBox.BackgroundColor3 = COLOR.btn
SpeedBox.Text = tostring(flySpeed)
SpeedBox.TextColor3 = COLOR.text
SpeedBox.Font = Enum.Font.Gotham
SpeedBox.TextSize = 12
SpeedBox.Parent = FuncView
addCorner(SpeedBox, UDim.new(0.12, 0))
SpeedBox.FocusLost:Connect(function()
    local v = tonumber(SpeedBox.Text) or flySpeed
    flySpeed = math.clamp(v, 0.2, 5)
    SpeedBox.Text = tostring(flySpeed)
    SpeedLabel.Text = "飞行速度：" .. tostring(flySpeed)
end)

-- ============ 视图：玩家列表 ============
local ListView = Instance.new("Frame")
ListView.Size = UDim2.new(1, 0, 1, 0)
ListView.BackgroundTransparency = 1
ListView.Parent = RightPanel
ListView.Visible = false

local ListScroll = Instance.new("ScrollingFrame")
ListScroll.Size = UDim2.new(1, -16, 1, -16)
ListScroll.Position = UDim2.new(0, 8, 0, 8)
ListScroll.BackgroundTransparency = 1
ListScroll.ScrollBarThickness = 4
ListScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
ListScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
ListScroll.Parent = ListView

local ListLayout = Instance.new("UIListLayout")
ListLayout.Padding = UDim.new(0, 6)
ListLayout.Parent = ListScroll

-- ============ 视图：服务器信息 ============
local InfoView = Instance.new("Frame")
InfoView.Size = UDim2.new(1, 0, 1, 0)
InfoView.BackgroundTransparency = 1
InfoView.Parent = RightPanel
InfoView.Visible = false

local InfoText = Instance.new("TextLabel")
InfoText.Size = UDim2.new(1, -24, 1, -24)
InfoText.Position = UDim2.new(0, 12, 0, 12)
InfoText.BackgroundTransparency = 1
InfoText.TextColor3 = COLOR.text
InfoText.Font = Enum.Font.Gotham
InfoText.TextSize = 13
InfoText.TextWrapped = true
InfoText.TextXAlignment = Enum.TextXAlignment.Left
InfoText.TextYAlignment = Enum.TextYAlignment.Top
InfoText.Active = false
InfoText.Parent = InfoView

-- ============ 分类按钮 ============
local categoryButtons = {}
local function addCategory(name, view)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -10, 0, 38)
    btn.BackgroundColor3 = COLOR.btnAlt
    btn.Text = name
    btn.TextColor3 = COLOR.text
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 12
    btn.ZIndex = 2
    btn.Parent = LeftBar
    addCorner(btn, UDim.new(0.14, 0))
    addStroke(btn, COLOR.stroke, 1)
    btn.Activated:Connect(function() setActiveView(view) end)
    table.insert(categoryButtons, { btn = btn, view = view })
end

addCategory("功能面板", FuncView)
addCategory("玩家列表", ListView)
addCategory("服务器信息", InfoView)

local views = { FuncView, ListView, InfoView }

setActiveView = function(view)
    for _, v in ipairs(views) do v.Visible = false end
    view.Visible = true
    for _, item in ipairs(categoryButtons) do
        item.btn.BackgroundColor3 = (item.view == view) and COLOR.accent or COLOR.btnAlt
    end
end

-- ============ 隐身逻辑 ============
applyInvisibility = function()
    pcall(function()
        local char = LocalPlayer.Character
        if not char then return end
        for _, v in ipairs(char:GetDescendants()) do
            if v:IsA("BasePart") then
                v.Transparency = invisible and 1 or 0
                v.CanCollide = not invisible
            elseif v:IsA("ParticleEmitter") or v:IsA("Fire") or v:IsA("Smoke") then
                v.Enabled = not invisible
            end
        end
    end)
end

-- ============ 数据刷新 ============
local function refreshServerInfo()
    pcall(function()
        local playerCount = #Players:GetPlayers()
        local maxPlayers = Players.MaxPlayers or 0
        local pingMs = "N/A"
        local okPing, ping = pcall(function() return LocalPlayer:GetNetworkPing() end)
        if okPing and ping then
            pingMs = tostring(math.floor(ping * 1000)) .. " ms"
        end
        InfoText.Text = string.format(
            "游戏名称：%s\nPlaceId：%d\n在线玩家：%d / %d\n本地 Ping：%s\n本地玩家：%s\n玩家 ID：%d",
            tostring(game.Name), game.PlaceId or 0, playerCount, maxPlayers,
            pingMs, LocalPlayer.Name, LocalPlayer.UserId
        )
    end)
end

local function refreshPlayerList()
    pcall(function()
        for _, v in pairs(ListScroll:GetChildren()) do
            if v:IsA("TextButton") then v:Destroy() end
        end
        local localRoot = nil
        if LocalPlayer.Character then
            localRoot = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        end
        local list = Players:GetPlayers()
        for _, plr in ipairs(list) do
            local char = plr.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local dist = "N/A"
            if hrp and localRoot then
                dist = tostring(math.floor((hrp.Position - localRoot.Position).Magnitude))
            end
            local hp = hum and tostring(math.floor(hum.Health)) or "N/A"
            local maxHp = hum and tostring(math.floor(hum.MaxHealth)) or "N/A"
            local teamName = (plr.Team and plr.Team.Name) or "无队伍"
            local tag = (plr == LocalPlayer) and "（自己）" or ""

            local entry = Instance.new("TextButton")
            entry.Size = UDim2.new(1, 0, 0, 56)
            entry.BackgroundColor3 = (selectedPlayer == plr) and COLOR.accent or Color3.fromRGB(44, 48, 56)
            entry.Parent = ListScroll
            addCorner(entry, UDim.new(0.08, 0))
            addStroke(entry, COLOR.stroke, 1)
            entry.Activated:Connect(function()
                selectedPlayer = plr
                refreshPlayerList()
            end)

            local info = Instance.new("TextLabel")
            info.Size = UDim2.new(1, -12, 1, -8)
            info.Position = UDim2.new(0, 6, 0, 4)
            info.BackgroundTransparency = 1
            info.TextColor3 = COLOR.text
            info.Font = Enum.Font.Gotham
            info.TextSize = 11
            info.TextWrapped = true
            info.TextXAlignment = Enum.TextXAlignment.Left
            info.TextYAlignment = Enum.TextYAlignment.Top
            info.Active = false
            info.Text = string.format(
                "【%s】%s ID:%d\nHP:%s/%s | 距离:%s studs\n队伍:%s",
                plr.Name, tag, plr.UserId, hp, maxHp, dist, teamName
            )
            info.Parent = entry
        end
    end)
end

-- ============ 开合控制 ============
local function closeMainWindow()
    isOpen = false
    MainWindow.Visible = false
    IslandLabel.Text = "灵动岛"
end

local function openMainWindow()
    isOpen = true
    MainWindow.Visible = true
    IslandLabel.Text = "已打开"
    refreshServerInfo()
    refreshPlayerList()
    setActiveView(FuncView)
end

CloseBtn.Activated:Connect(closeMainWindow)
IslandBtn.Activated:Connect(function()
    if isOpen then closeMainWindow() else openMainWindow() end
end)

-- 快捷键
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.F1 then
        if isOpen then closeMainWindow() else openMainWindow() end
    elseif input.KeyCode == Enum.KeyCode.F2 then
        flyEnabled = not flyEnabled
        FlyBtn.Text = flyEnabled and "飞行：开启" or "飞行：关闭"
    elseif input.KeyCode == Enum.KeyCode.F3 then
        invisible = not invisible
        InvisBtn.Text = invisible and "隐身：开启" or "隐身：关闭"
        applyInvisibility()
    end
end)

-- 玩家进出刷新
Players.PlayerAdded:Connect(function() if ListView.Visible then refreshPlayerList() end end)
Players.PlayerRemoving:Connect(function() if ListView.Visible then refreshPlayerList() end end)

-- ============ 主循环：CFrame 飞行 + 防甩飞 + 自动回血 ============
RunService.RenderStepped:Connect(function()
    pcall(function()
        local char = LocalPlayer.Character
        if not char then return end
        local hum = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hum or not hrp then return end
        local cam = workspace.CurrentCamera

        if flyEnabled and cam then
            hum.PlatformStand = true
            local dir = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - cam.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + cam.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir + Vector3.new(0, -1, 0) end
            if dir.Magnitude > 0 then dir = dir.Unit * flySpeed end
            hrp.CFrame = hrp.CFrame + dir
        else
            hum.PlatformStand = false
        end

        if antiKnockback and hrp.Velocity.Magnitude > 80 then
            hrp.Velocity = hrp.Velocity.Unit * 80
        end
        if autoHeal and hum.Health < hum.MaxHealth then
            hum.Health = hum.MaxHealth
        end
    end)
end)

-- 信息刷新 + GUI 守护
task.spawn(function()
    while task.wait(1.2) do
        pcall(function()
            if ScreenGui.Parent ~= PlayerGui then
                ScreenGui.Parent = PlayerGui
            end
        end)
        if MainWindow.Visible then
            refreshServerInfo()
            refreshPlayerList()
        end
    end
end)
