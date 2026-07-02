local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local RECORDS_STORE = DataStoreService:GetDataStore("GatewayToHell_PlayerRecords_v1")
local WINS_BOARD = DataStoreService:GetOrderedDataStore("GatewayToHell_WinsBoard_v1")
local REFRESH_INTERVAL = 60
local SHOW_SAMPLE_WHEN_EMPTY = true
local MAX_ENTRIES = 10
local FETCH_LIMIT = 25

local SAMPLE_ENTRIES = {
    { UserId = 1, Name = "NightHunter", Wins = 11_178 },
    { UserId = 2, Name = "AshWalker", Wins = 8_504 },
    { UserId = 3, Name = "Mothveil", Wins = 7_219 },
    { UserId = 4, Name = "Cinder", Wins = 6_886 },
    { UserId = 5, Name = "GravePulse", Wins = 5_430 },
    { UserId = 6, Name = "Noctis", Wins = 4_992 },
    { UserId = 7, Name = "Ruin", Wins = 4_210 },
    { UserId = 8, Name = "Specter", Wins = 3_771 },
    { UserId = 9, Name = "Ember", Wins = 3_102 },
    { UserId = 10, Name = "Ashen", Wins = 2_415 },
}

local leaderboardAnchor = Workspace:WaitForChild("LeaderboardAnchor")

local function defaultRecord()
    return {
        Wins = 0,
        FastestTime = 0,
        Stars = 0,
    }
end

local function getScore(record)
    local wins = tonumber(record.Wins) or 0
    local stars = tonumber(record.Stars) or 0
    local fastestTime = tonumber(record.FastestTime) or 0
    return wins * 100000 + stars * 100 - math.floor(fastestTime * 10)
end

local function loadRecord(userId)
    local success, data = pcall(function()
        return RECORDS_STORE:GetAsync(tostring(userId))
    end)

    if success and type(data) == "table" then
        return {
            Wins = tonumber(data.Wins) or 0,
            FastestTime = tonumber(data.FastestTime) or 0,
            Stars = tonumber(data.Stars) or 0,
        }
    end

    return defaultRecord()
end

local function saveRecord(userId, record)
    local payload = {
        Wins = tonumber(record.Wins) or 0,
        FastestTime = tonumber(record.FastestTime) or 0,
        Stars = tonumber(record.Stars) or 0,
    }

    pcall(function()
        RECORDS_STORE:SetAsync(tostring(userId), payload)
    end)

    pcall(function()
        WINS_BOARD:SetAsync(tostring(userId), getScore(payload))
    end)
end

local function ensureLeaderstats(player)
    local leaderstats = player:FindFirstChild("leaderstats")
    if not leaderstats then
        leaderstats = Instance.new("Folder")
        leaderstats.Name = "leaderstats"
        leaderstats.Parent = player
    end

    local wins = leaderstats:FindFirstChild("Wins") or Instance.new("IntValue")
    wins.Name = "Wins"
    wins.Parent = leaderstats

    local stars = leaderstats:FindFirstChild("Stars") or Instance.new("IntValue")
    stars.Name = "Stars"
    stars.Parent = leaderstats

    local fastestTime = leaderstats:FindFirstChild("FastestTime") or Instance.new("NumberValue")
    fastestTime.Name = "FastestTime"
    fastestTime.Parent = leaderstats

    return leaderstats, wins, stars, fastestTime
end

local playerCache = {}

local function syncPlayer(player)
    local record = loadRecord(player.UserId)
    playerCache[player.UserId] = record

    local _, winsValue, starsValue, fastestValue = ensureLeaderstats(player)
    winsValue.Value = record.Wins
    starsValue.Value = record.Stars
    fastestValue.Value = record.FastestTime
end

local function persistPlayer(player)
    local record = playerCache[player.UserId]
    if not record then
        return
    end

    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        local wins = leaderstats:FindFirstChild("Wins")
        local stars = leaderstats:FindFirstChild("Stars")
        local fastestTime = leaderstats:FindFirstChild("FastestTime")
        if wins and stars and fastestTime then
            record.Wins = wins.Value
            record.Stars = stars.Value
            record.FastestTime = fastestTime.Value
        end
    end

    saveRecord(player.UserId, record)
    playerCache[player.UserId] = nil
end

local function formatWins(value)
    local text = tostring(math.floor(tonumber(value) or 0))
    local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    formatted = formatted:gsub("^,", "")
    return `{formatted} انتصارات`
end

local function formatThousands(value)
    return formatWins(value)
end

local function resolveUsername(userId)
    local success, username = pcall(function()
        return Players:GetNameFromUserIdAsync(userId)
    end)

    if success and username and username ~= "" then
        return username
    end

    return `User {userId}`
end

local function avatarThumb(userId)
    return `rbxthumb://type=AvatarHeadShot&id={userId}&w=150&h=150`
end

local boardGui = Instance.new("SurfaceGui")
boardGui.Name = "LeaderboardBoard"
boardGui.Face = Enum.NormalId.Front
boardGui.LightInfluence = 0
boardGui.AlwaysOnTop = true
boardGui.PixelsPerStud = 40
boardGui.ResetOnSpawn = false
boardGui.Parent = leaderboardAnchor

local root = Instance.new("Frame")
root.Size = UDim2.fromScale(1, 1)
root.BackgroundColor3 = GameConfig.COLORS.Panel
root.BackgroundTransparency = 0.02
root.BorderSizePixel = 0
root.Parent = boardGui

local frameStroke = Instance.new("UIStroke")
frameStroke.Color = GameConfig.COLORS.AccentDim
frameStroke.Thickness = 1
frameStroke.Transparency = 0.18
frameStroke.Parent = root

local header = Instance.new("TextLabel")
header.Size = UDim2.new(1, 0, 0.13, 0)
header.BackgroundColor3 = Color3.fromRGB(19, 12, 16)
header.BackgroundTransparency = 0.02
header.BorderSizePixel = 0
header.Text = "بوابة الجحيم • المتصدرون"
header.Font = Enum.Font.GothamBlack
header.TextColor3 = GameConfig.COLORS.AccentAlt
header.TextScaled = true
header.Parent = root

local headerStroke = Instance.new("UIStroke")
headerStroke.Color = GameConfig.COLORS.AccentDim
headerStroke.Thickness = 1
headerStroke.Transparency = 0.3
headerStroke.Parent = header

local subheader = Instance.new("TextLabel")
subheader.Position = UDim2.new(0, 0, 0.13, 0)
subheader.Size = UDim2.new(1, 0, 0.05, 0)
subheader.BackgroundTransparency = 1
subheader.Text = "Top 10 Wins"
subheader.Font = Enum.Font.GothamMedium
subheader.TextColor3 = GameConfig.COLORS.TextMuted
subheader.TextScaled = true
subheader.Parent = root

local rowsContainer = Instance.new("Frame")
rowsContainer.Position = UDim2.new(0.04, 0, 0.2, 0)
rowsContainer.Size = UDim2.new(0.92, 0, 0.76, 0)
rowsContainer.BackgroundTransparency = 1
rowsContainer.Parent = root

local rowsLayout = Instance.new("UIListLayout")
rowsLayout.Padding = UDim.new(0, 6)
rowsLayout.SortOrder = Enum.SortOrder.LayoutOrder
rowsLayout.Parent = rowsContainer

local rowTemplates = {}

local function makeLabel(parent, name, position, size, align)
    local label = Instance.new("TextLabel")
    label.Name = name
    label.BackgroundTransparency = 1
    label.Position = position
    label.Size = size
    label.Font = Enum.Font.GothamSemibold
    label.TextColor3 = GameConfig.COLORS.Text
    label.TextScaled = true
    label.TextXAlignment = align or Enum.TextXAlignment.Left
    label.Parent = parent
    return label
end

local function makeRow(index)
    local row = Instance.new("Frame")
    row.Name = `Row{index}`
    row.Size = UDim2.new(1, 0, 0.12, 0)
    row.BackgroundColor3 = GameConfig.COLORS.PanelSoft
    row.BackgroundTransparency = 0.05
    row.BorderSizePixel = 0
    row.Parent = rowsContainer

    local rowStroke = Instance.new("UIStroke")
    rowStroke.Color = GameConfig.COLORS.AccentDim
    rowStroke.Thickness = 1
    rowStroke.Transparency = 0.55
    rowStroke.Parent = row

    local rankLabel = makeLabel(row, "Rank", UDim2.new(0.02, 0, 0, 0), UDim2.new(0.07, 0, 1, 0), Enum.TextXAlignment.Left)
    rankLabel.Font = Enum.Font.GothamBlack
    rankLabel.TextColor3 = GameConfig.COLORS.AccentAlt

    local avatar = Instance.new("ImageLabel")
    avatar.Name = "Avatar"
    avatar.BackgroundColor3 = Color3.fromRGB(12, 8, 10)
    avatar.BorderSizePixel = 0
    avatar.Position = UDim2.new(0.1, 0, 0.15, 0)
    avatar.Size = UDim2.new(0.18, 0, 0.7, 0)
    avatar.Image = ""
    avatar.ScaleType = Enum.ScaleType.Crop
    avatar.Parent = row

    local avatarCorner = Instance.new("UICorner")
    avatarCorner.CornerRadius = UDim.new(0, 6)
    avatarCorner.Parent = avatar

    local avatarStroke = Instance.new("UIStroke")
    avatarStroke.Color = GameConfig.COLORS.AccentDim
    avatarStroke.Thickness = 1
    avatarStroke.Transparency = 0.2
    avatarStroke.Parent = avatar

    local nameLabel = makeLabel(row, "Name", UDim2.new(0.31, 0, 0, 0), UDim2.new(0.39, 0, 1, 0), Enum.TextXAlignment.Left)
    nameLabel.Font = Enum.Font.GothamSemibold

    local winsLabel = makeLabel(row, "Wins", UDim2.new(0.71, 0, 0, 0), UDim2.new(0.27, 0, 1, 0), Enum.TextXAlignment.Right)
    winsLabel.Font = Enum.Font.GothamBold
    winsLabel.TextColor3 = GameConfig.COLORS.Text

    rowTemplates[index] = {
        Row = row,
        RankLabel = rankLabel,
        AvatarLabel = avatar,
        NameLabel = nameLabel,
        WinsLabel = winsLabel,
    }
end

for index = 1, MAX_ENTRIES do
    makeRow(index)
end

local function resolveBoardEntries()
    local success, pages = pcall(function()
        return WINS_BOARD:GetSortedAsync(false, FETCH_LIMIT)
    end)

    if not success or not pages then
        return {}
    end

    local rawEntries = {}
    local page = pages:GetCurrentPage()
    for _, item in ipairs(page) do
        local userId = tonumber(item.key)
        if userId then
            local record = loadRecord(userId)
            table.insert(rawEntries, {
                UserId = userId,
                Username = resolveUsername(userId),
                Wins = tonumber(record.Wins) or 0,
                Score = tonumber(item.value) or getScore(record),
            })
        end
    end

    table.sort(rawEntries, function(a, b)
        if a.Wins == b.Wins then
            if a.Score == b.Score then
                return a.Username < b.Username
            end
            return a.Score > b.Score
        end
        return a.Wins > b.Wins
    end)

    local trimmed = {}
    for index = 1, math.min(MAX_ENTRIES, #rawEntries) do
        trimmed[index] = rawEntries[index]
    end
    return trimmed
end

local function applyEntry(row, index, entry)
    row.Visible = true
    row.RankLabel.Text = `#{index}`
    row.AvatarLabel.Image = avatarThumb(entry.UserId)
    row.NameLabel.Text = entry.Username
    row.WinsLabel.Text = formatThousands(entry.Wins)
end

local function applyPlaceholder(row, index)
    row.Visible = true
    row.RankLabel.Text = `#{index}`
    row.AvatarLabel.Image = ""
    row.NameLabel.Text = "—"
    row.WinsLabel.Text = "—"
end

local function applySampleBoard()
    for index = 1, MAX_ENTRIES do
        local row = rowTemplates[index]
        local entry = SAMPLE_ENTRIES[index]
        row.Visible = true
        row.RankLabel.Text = `#{index}`
        row.AvatarLabel.Image = avatarThumb(entry.UserId)
        row.NameLabel.Text = entry.Name
        row.WinsLabel.Text = formatThousands(entry.Wins)
    end
end

local function refreshBoard()
    local entries = resolveBoardEntries()

    if #entries == 0 and SHOW_SAMPLE_WHEN_EMPTY then
        applySampleBoard()
        return
    end

    for index = 1, MAX_ENTRIES do
        local row = rowTemplates[index]
        local entry = entries[index]
        if entry then
            applyEntry(row, index, entry)
        else
            applyPlaceholder(row, index)
        end
    end
end

Players.PlayerAdded:Connect(syncPlayer)
Players.PlayerRemoving:Connect(function(player)
    persistPlayer(player)
end)

for _, player in ipairs(Players:GetPlayers()) do
    syncPlayer(player)
end

game:BindToClose(function()
    for _, player in ipairs(Players:GetPlayers()) do
        persistPlayer(player)
    end
end)

refreshBoard()
task.spawn(function()
    while task.wait(REFRESH_INTERVAL) do
        refreshBoard()
    end
end)
