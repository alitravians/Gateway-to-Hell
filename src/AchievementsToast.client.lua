local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local achievementUnlockedEvent = ReplicatedStorage:WaitForChild("GatewayToHellRemotes"):WaitForChild("AchievementUnlocked")

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "AchievementsToastGui"
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 90
screenGui.Parent = playerGui

local stack = Instance.new("Frame")
stack.AnchorPoint = Vector2.new(1, 1)
stack.Position = UDim2.new(0.98, 0, 0.96, 0)
stack.Size = UDim2.new(0.28, 0, 0.30, 0)
stack.BackgroundTransparency = 1
stack.Parent = screenGui

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = stack

local function makeToast(titleText, bodyText)
	local toast = Instance.new("Frame")
	toast.BackgroundColor3 = GameConfig.COLORS.Panel
	toast.BackgroundTransparency = 0.04
	toast.BorderSizePixel = 0
	toast.Size = UDim2.new(1, 0, 0, 64)
	toast.Parent = stack

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = toast

	local stroke = Instance.new("UIStroke")
	stroke.Color = GameConfig.COLORS.AccentAlt
	stroke.Transparency = 0.22
	stroke.Parent = toast

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position = UDim2.new(0.06, 0, 0.10, 0)
	title.Size = UDim2.new(0.88, 0, 0.32, 0)
	title.Font = Enum.Font.GothamBlack
	title.TextColor3 = GameConfig.COLORS.AccentAlt
	title.TextScaled = true
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = titleText
	title.Parent = toast

	local body = Instance.new("TextLabel")
	body.BackgroundTransparency = 1
	body.Position = UDim2.new(0.06, 0, 0.44, 0)
	body.Size = UDim2.new(0.88, 0, 0.38, 0)
	body.Font = Enum.Font.GothamMedium
	body.TextColor3 = GameConfig.COLORS.Text
	body.TextScaled = true
	body.TextWrapped = true
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.Text = bodyText
	body.Parent = toast

	toast.BackgroundTransparency = 1
	stroke.Transparency = 1
	TweenService:Create(toast, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.04,
	}):Play()
	TweenService:Create(stroke, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 0.22,
	}):Play()

	task.delay(3.5, function()
		if toast.Parent then
			TweenService:Create(toast, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				BackgroundTransparency = 1,
			}):Play()
			TweenService:Create(stroke, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Transparency = 1,
			}):Play()
			task.delay(0.28, function()
				if toast.Parent then
					toast:Destroy()
				end
			end)
		end
	end)
end

achievementUnlockedEvent.OnClientEvent:Connect(function(payload)
	if type(payload) ~= "table" then
		return
	end

	makeToast(payload.TitleAr or "إنجاز جديد", payload.DescriptionAr or "تم فتح إنجاز جديد.")
end)
