local BadgeService = game:GetService("BadgeService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local ACHIEVEMENTS_STORE = DataStoreService:GetDataStore("GatewayToHell_Achievements_v1")
local remotesFolder = ReplicatedStorage:WaitForChild("GatewayToHellRemotes")
local achievementUnlockedEvent = remotesFolder:WaitForChild("AchievementUnlocked") :: RemoteEvent
local signalsFolder = ReplicatedStorage:WaitForChild("GatewayToHellSignals")
local roundOutcomeResolved = signalsFolder:WaitForChild("RoundOutcomeResolved") :: BindableEvent

local cacheByUserId = {}

local ACHIEVEMENTS = {
	FirstEscape = {
		TitleAr = "أول هروب",
		DescriptionAr = "نجوت من الجولة الأولى وحملت ضوء البوابة معك.",
		BadgeId = GameConfig.PLACEHOLDER_BADGE_IDS.FirstEscape,
	},
	NoDeathEscape = {
		TitleAr = "نجاة جماعية",
		DescriptionAr = "خرج الفريق دون أي وفاة واحدة.",
		BadgeId = GameConfig.PLACEHOLDER_BADGE_IDS.NoDeathsEscape,
	},
	NightmareClear = {
		TitleAr = "قاهر الكابوس",
		DescriptionAr = "أكملت جولة الكابوس وخرجت حيًا.",
		BadgeId = GameConfig.PLACEHOLDER_BADGE_IDS.NightmareClear,
	},
	HardcoreClear = {
		TitleAr = "النجاة المستحيلة",
		DescriptionAr = "تفوقت على وضع Hardcore الصارم.",
		BadgeId = GameConfig.PLACEHOLDER_BADGE_IDS.HardcoreClear,
	},
	SecretEnding = {
		TitleAr = "سر البوابة",
		DescriptionAr = "فتحت النهاية السرية عبر الطقس المخفي.",
		BadgeId = GameConfig.PLACEHOLDER_BADGE_IDS.SecretEnding,
	},
}

local function defaultRecord()
	return {
		Unlocked = {},
		Progress = {
			Escapes = 0,
			NoDeathClears = 0,
			NightmareClears = 0,
			HardcoreClears = 0,
			SecretEndings = 0,
		},
	}
end

local function normalizeRecord(data)
	local record = defaultRecord()
	if type(data) ~= "table" then
		return record
	end

	if type(data.Unlocked) == "table" then
		for key, value in pairs(data.Unlocked) do
			if type(key) == "string" and value == true then
				record.Unlocked[key] = true
			end
		end
	end

	if type(data.Progress) == "table" then
		record.Progress.Escapes = math.max(0, tonumber(data.Progress.Escapes) or 0)
		record.Progress.NoDeathClears = math.max(0, tonumber(data.Progress.NoDeathClears) or 0)
		record.Progress.NightmareClears = math.max(0, tonumber(data.Progress.NightmareClears) or 0)
		record.Progress.HardcoreClears = math.max(0, tonumber(data.Progress.HardcoreClears) or 0)
		record.Progress.SecretEndings = math.max(0, tonumber(data.Progress.SecretEndings) or 0)
	end

	return record
end

local function loadRecord(userId)
	local success, data = pcall(function()
		return ACHIEVEMENTS_STORE:GetAsync(tostring(userId))
	end)

	if success then
		return normalizeRecord(data)
	end

	return defaultRecord()
end

local function saveRecord(userId)
	local record = cacheByUserId[userId]
	if not record then
		return
	end

	pcall(function()
		ACHIEVEMENTS_STORE:SetAsync(tostring(userId), record)
	end)
end

local function awardBadge(player, badgeId)
	if type(badgeId) ~= "number" or badgeId <= 0 then
		return
	end

	pcall(function()
		if not BadgeService:UserHasBadgeAsync(player.UserId, badgeId) then
			BadgeService:AwardBadge(player.UserId, badgeId)
		end
	end)
end

local function notifyPlayer(player, achievementId)
	local achievement = ACHIEVEMENTS[achievementId]
	if not achievement then
		return
	end

	achievementUnlockedEvent:FireClient(player, {
		AchievementId = achievementId,
		TitleAr = achievement.TitleAr,
		DescriptionAr = achievement.DescriptionAr,
	})

	awardBadge(player, achievement.BadgeId)
end

local function countUnlocked(record)
	local total = 0
	for _, unlocked in pairs(record.Unlocked) do
		if unlocked == true then
			total += 1
		end
	end
	return total
end

local function unlock(player, achievementId)
	local achievement = ACHIEVEMENTS[achievementId]
	if not achievement then
		return
	end

	local record = cacheByUserId[player.UserId]
	if not record then
		record = defaultRecord()
		cacheByUserId[player.UserId] = record
	end

	if record.Unlocked[achievementId] then
		return
	end

	record.Unlocked[achievementId] = true
	player:SetAttribute("AchievementCount", countUnlocked(record))
	notifyPlayer(player, achievementId)
	saveRecord(player.UserId)
end

local function syncPlayer(player)
	local record = loadRecord(player.UserId)
	cacheByUserId[player.UserId] = record
	player:SetAttribute("AchievementCount", countUnlocked(record))
end

local function handleOutcome(payload)
	if type(payload) ~= "table" then
		return
	end

	local participants = {}
	if type(payload.Participants) == "table" then
		for _, participant in ipairs(payload.Participants) do
			if type(participant) == "table" and type(participant.UserId) == "number" then
				participants[participant.UserId] = participant
			end
		end
	end

	local didWin = payload.Result == "Win"
	local endingType = payload.EndingType
	local modeId = payload.ModeId
	local hasNoDeaths = payload.HasNoDeaths == true
	local secretComplete = payload.SecretObjectiveComplete == true or endingType == "Secret"

	for _, player in ipairs(Players:GetPlayers()) do
		local participant = participants[player.UserId]
		if participant and participant.State == "Escaped" then
			local record = cacheByUserId[player.UserId]
			if record then
				record.Progress.Escapes += 1
			end
			if record and record.Progress.Escapes == 1 then
				unlock(player, "FirstEscape")
			end

			if didWin and hasNoDeaths then
				if record then
					record.Progress.NoDeathClears += 1
				end
				unlock(player, "NoDeathEscape")
			end

			if didWin and modeId == "Nightmare" then
				if record then
					record.Progress.NightmareClears += 1
				end
				unlock(player, "NightmareClear")
			end

			if didWin and modeId == "Hardcore" then
				if record then
					record.Progress.HardcoreClears += 1
				end
				unlock(player, "HardcoreClear")
			end

			if secretComplete then
				if record then
					record.Progress.SecretEndings += 1
				end
				unlock(player, "SecretEnding")
			end
		end
	end

	for userId, record in pairs(cacheByUserId) do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			player:SetAttribute("AchievementCount", countUnlocked(record))
		end
		saveRecord(userId)
	end
end

Players.PlayerAdded:Connect(syncPlayer)
Players.PlayerRemoving:Connect(function(player)
	saveRecord(player.UserId)
	cacheByUserId[player.UserId] = nil
end)

for _, player in ipairs(Players:GetPlayers()) do
	syncPlayer(player)
end

roundOutcomeResolved.Event:Connect(handleOutcome)
