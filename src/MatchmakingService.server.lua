local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local REMOTES_FOLDER_NAME = "GatewayToHellRemotes"
local SIGNALS_FOLDER_NAME = "GatewayToHellSignals"

local remotesFolder = ReplicatedStorage:WaitForChild(REMOTES_FOLDER_NAME)
local openChoiceEvent = remotesFolder:WaitForChild("OpenMatchmakingChoice")
local submitChoiceEvent = remotesFolder:WaitForChild("SubmitMatchmakingChoice")
local countdownEvent = remotesFolder:WaitForChild("QueueCountdown")
local roundStartRequested = ReplicatedStorage:WaitForChild(SIGNALS_FOLDER_NAME):WaitForChild("RoundStartRequested")

local matchmakingCircle = Workspace:WaitForChild("MatchmakingCircle")

local queuesByKey = {}
local activeCountdowns = {}
local playerQueueKey = {}
local playerInCircle = {}

local function queueKey(modeId, playerCount)
	return `{modeId}:{playerCount}`
end

local function removeUserFromQueue(queue, userId)
	for index = #queue, 1, -1 do
		if queue[index] == userId then
			table.remove(queue, index)
		end
	end
end

local function removePlayerFromAllQueues(userId)
	local currentKey = playerQueueKey[userId]
	if currentKey and queuesByKey[currentKey] then
		removeUserFromQueue(queuesByKey[currentKey], userId)
	end

	for _, queue in pairs(queuesByKey) do
		removeUserFromQueue(queue, userId)
	end

	playerQueueKey[userId] = nil
end

local function fireChoice(player)
	openChoiceEvent:FireClient(player, {
		Modes = GameConfig.GAME_MODES,
		Counts = GameConfig.PLAYER_COUNT_OPTIONS,
	})
end

local function getPlayerFromHit(hit)
	local character = hit and hit.Parent
	if not character then
		return nil
	end

	local player = Players:GetPlayerFromCharacter(character)
	if player then
		return player
	end

	local parent = character.Parent
	if parent then
		return Players:GetPlayerFromCharacter(parent)
	end

	return nil
end

local function startCountdownForKey(key, modeId, playerCount)
	if activeCountdowns[key] then
		return
	end

	activeCountdowns[key] = true

	task.spawn(function()
		local queue = queuesByKey[key]
		for remaining = GameConfig.COUNTDOWN_SECONDS, 0, -1 do
			for _, userId in ipairs(queue) do
				local player = Players:GetPlayerByUserId(userId)
				if player then
					countdownEvent:FireClient(player, {
						ModeId = modeId,
						PlayerCount = playerCount,
						Remaining = remaining,
					})
				end
			end
			task.wait(1)
		end

		local queuedPlayers = {}
		for _, userId in ipairs(queue) do
			local player = Players:GetPlayerByUserId(userId)
			if player then
				table.insert(queuedPlayers, player)
			end
		end

		if #queuedPlayers < playerCount then
			activeCountdowns[key] = nil
			return
		end

		roundStartRequested:Fire({
			Players = queuedPlayers,
			PlayerCount = playerCount,
			ModeId = modeId,
		})

		queuesByKey[key] = {}
		for _, player in ipairs(queuedPlayers) do
			playerQueueKey[player.UserId] = nil
		end
		activeCountdowns[key] = nil
	end)
end

matchmakingCircle.Touched:Connect(function(hit)
	local player = getPlayerFromHit(hit)
	if not player then
		return
	end

	playerInCircle[player.UserId] = true
	fireChoice(player)
end)

matchmakingCircle.TouchEnded:Connect(function(hit)
	local player = getPlayerFromHit(hit)
	if player then
		playerInCircle[player.UserId] = nil
	end
end)

submitChoiceEvent.OnServerEvent:Connect(function(player, payload)
	if not playerInCircle[player.UserId] then
		return
	end

	local modeId = GameConfig.DEFAULT_MODE_ID
	local playerCount = nil

	if type(payload) == "table" then
		if type(payload.ModeId) == "string" then
			modeId = payload.ModeId
		end
		if type(payload.PlayerCount) == "number" then
			playerCount = payload.PlayerCount
		end
	elseif type(payload) == "number" then
		playerCount = payload
	end

	local validMode = false
	for _, mode in ipairs(GameConfig.GAME_MODES) do
		if mode.Id == modeId then
			validMode = true
			break
		end
	end

	if not validMode or type(playerCount) ~= "number" then
		return
	end

	local validCount = false
	for _, count in ipairs(GameConfig.PLAYER_COUNT_OPTIONS) do
		if count == playerCount then
			validCount = true
			break
		end
	end

	if not validCount then
		return
	end

	removePlayerFromAllQueues(player.UserId)

	local key = queueKey(modeId, playerCount)
	local queue = queuesByKey[key]
	if not queue then
		queue = {}
		queuesByKey[key] = queue
	end

	playerQueueKey[player.UserId] = key
	table.insert(queue, player.UserId)

	if #queue >= playerCount then
		startCountdownForKey(key, modeId, playerCount)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	playerInCircle[player.UserId] = nil
	removePlayerFromAllQueues(player.UserId)
end)
