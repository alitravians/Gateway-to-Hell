local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "MainMenuGui"
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 20
screenGui.Parent = playerGui

local root = Instance.new("Frame")
root.Size = UDim2.fromScale(1, 1)
root.BackgroundColor3 = GameConfig.COLORS.Background
root.BorderSizePixel = 0
root.Parent = screenGui

local overlay = Instance.new("Frame")
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundTransparency = 0.18
overlay.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
overlay.BorderSizePixel = 0
overlay.Parent = root

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Position = UDim2.new(0.08, 0, 0.12, 0)
title.Size = UDim2.new(0.6, 0, 0.12, 0)
title.Font = Enum.Font.GothamBlack
title.Text = GameConfig.GameTitleAr
title.TextColor3 = GameConfig.COLORS.AccentAlt
title.TextScaled = true
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = root

local subtitle = Instance.new("TextLabel")
subtitle.BackgroundTransparency = 1
subtitle.Position = UDim2.new(0.09, 0, 0.23, 0)
subtitle.Size = UDim2.new(0.54, 0, 0.06, 0)
subtitle.Font = Enum.Font.GothamMedium
subtitle.Text = GameConfig.TaglineAr
subtitle.TextColor3 = GameConfig.COLORS.TextMuted
subtitle.TextScaled = true
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Parent = root

local buttonPanel = Instance.new("Frame")
buttonPanel.BackgroundTransparency = 1
buttonPanel.Position = UDim2.new(0.09, 0, 0.36, 0)
buttonPanel.Size = UDim2.new(0.22, 0, 0.36, 0)
buttonPanel.Parent = root

local buttonLayout = Instance.new("UIListLayout")
buttonLayout.Padding = UDim.new(0, 12)
buttonLayout.SortOrder = Enum.SortOrder.LayoutOrder
buttonLayout.Parent = buttonPanel

local function makeButton(text)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, 0, 0.28, 0)
    button.AutoButtonColor = false
    button.BackgroundColor3 = GameConfig.COLORS.Panel
    button.BorderSizePixel = 0
    button.Font = Enum.Font.GothamBold
    button.Text = text
    button.TextColor3 = GameConfig.COLORS.Text
    button.TextScaled = true
    return button
end

local playButton = makeButton("ابدأ اللعب")
playButton.Parent = buttonPanel

local modesButton = makeButton("أوضاع اللعب")
modesButton.Parent = buttonPanel

local updatesButton = makeButton("التحديثات")
updatesButton.Parent = buttonPanel

local contentPanel = Instance.new("Frame")
contentPanel.AnchorPoint = Vector2.new(1, 0)
contentPanel.Position = UDim2.new(0.9, 0, 0.16, 0)
contentPanel.Size = UDim2.new(0.28, 0, 0.56, 0)
contentPanel.BackgroundColor3 = GameConfig.COLORS.Panel
contentPanel.BackgroundTransparency = 0.07
contentPanel.BorderSizePixel = 0
contentPanel.Visible = false
contentPanel.Parent = root

local contentCorner = Instance.new("UICorner")
contentCorner.CornerRadius = UDim.new(0, 14)
contentCorner.Parent = contentPanel

local contentStroke = Instance.new("UIStroke")
contentStroke.Color = GameConfig.COLORS.AccentDim
contentStroke.Thickness = 1
contentStroke.Transparency = 0.2
contentStroke.Parent = contentPanel

local contentTitle = Instance.new("TextLabel")
contentTitle.BackgroundTransparency = 1
contentTitle.Position = UDim2.new(0.06, 0, 0.04, 0)
contentTitle.Size = UDim2.new(0.88, 0, 0.1, 0)
contentTitle.Font = Enum.Font.GothamBlack
contentTitle.TextColor3 = GameConfig.COLORS.AccentAlt
contentTitle.TextScaled = true
contentTitle.TextXAlignment = Enum.TextXAlignment.Left
contentTitle.Parent = contentPanel

local contentBody = Instance.new("ScrollingFrame")
contentBody.BackgroundTransparency = 1
contentBody.Position = UDim2.new(0.05, 0, 0.16, 0)
contentBody.Size = UDim2.new(0.9, 0, 0.8, 0)
contentBody.BorderSizePixel = 0
contentBody.ScrollBarImageColor3 = GameConfig.COLORS.Accent
contentBody.CanvasSize = UDim2.new(0, 0, 0, 0)
contentBody.Visible = false
contentBody.Parent = contentPanel

local bodyLayout = Instance.new("UIListLayout")
bodyLayout.Padding = UDim.new(0, 8)
bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
bodyLayout.Parent = contentBody

local activePanel = nil

local function setContent(lines, header)
    contentTitle.Text = header
    contentBody:ClearAllChildren()
    bodyLayout.Parent = contentBody

    for _, line in ipairs(lines) do
        local label = Instance.new("TextLabel")
        label.BackgroundTransparency = 0.14
        label.BackgroundColor3 = GameConfig.COLORS.PanelSoft
        label.BorderSizePixel = 0
        label.Size = UDim2.new(1, 0, 0, 48)
        label.Font = Enum.Font.GothamMedium
        label.Text = line
        label.TextColor3 = GameConfig.COLORS.Text
        label.TextWrapped = true
        label.TextScaled = true
        label.Parent = contentBody
    end

    task.defer(function()
        contentBody.CanvasSize = UDim2.new(0, 0, 0, bodyLayout.AbsoluteContentSize.Y + 8)
    end)
end

local function showPanel(name)
    contentPanel.Visible = true
    contentBody.Visible = true

    if name == "modes" then
        local lines = {}
        for _, mode in ipairs(GameConfig.GAME_MODES) do
            table.insert(lines, `• {mode.NameAr} ({mode.NameEn}) — {mode.DescriptionAr}`)
        end
        setContent(lines, "أوضاع اللعب")
        activePanel = name
    elseif name == "updates" then
        local lines = {}
        for _, section in ipairs(GameConfig.UPDATE_SECTIONS) do
            table.insert(lines, `◆ {section.TitleAr}`)
            for _, item in ipairs(section.Items) do
                table.insert(lines, `  • {item}`)
            end
            table.insert(lines, " ")
        end
        setContent(lines, "التحديثات")
        activePanel = name
    else
        contentPanel.Visible = false
        contentBody.Visible = false
        activePanel = nil
    end
end

local function togglePanel(name)
    if activePanel == name then
        showPanel(nil)
    else
        showPanel(name)
    end
end

playButton.MouseButton1Click:Connect(function()
    contentPanel.Visible = false
    contentBody.Visible = false
    activePanel = nil

    local flash = TweenService:Create(root, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        BackgroundColor3 = GameConfig.COLORS.PanelSoft,
    })
    flash:Play()
end)

modesButton.MouseButton1Click:Connect(function()
    togglePanel("modes")
end)

updatesButton.MouseButton1Click:Connect(function()
    togglePanel("updates")
end)
