local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local StoryPuzzles = require(ReplicatedStorage:WaitForChild("StoryPuzzles"))

local remotesFolder = ReplicatedStorage:WaitForChild("GatewayToHellRemotes")
local signalsFolder = ReplicatedStorage:WaitForChild("GatewayToHellSignals")

local roundStartRequested = signalsFolder:WaitForChild("RoundStartRequested") :: BindableEvent
local puzzleProgressEvent = signalsFolder:WaitForChild("PuzzleProgress") :: BindableEvent
local puzzleSolvedEvent = signalsFolder:WaitForChild("PuzzleSolved") :: BindableEvent
local huntStartRequested = signalsFolder:WaitForChild("HuntStartRequested") :: BindableEvent
local huntStopRequested = signalsFolder:WaitForChild("HuntStopRequested") :: BindableEvent
local monsterCaughtPlayer = signalsFolder:WaitForChild("MonsterCaughtPlayer") :: BindableEvent
local monsterStateUpdated = signalsFolder:WaitForChild("MonsterStateUpdated") :: BindableEvent
local hideSpotRequested = signalsFolder:WaitForChild("HideSpotRequested") :: BindableEvent
local hideSpotReleased = signalsFolder:WaitForChild("HideSpotReleased") :: BindableEvent
local batteryPickupCollected = signalsFolder:WaitForChild("BatteryPickupCollected") :: BindableEvent
local secretObjectiveCompleted = signalsFolder:WaitForChild("SecretObjectiveCompleted") :: BindableEvent
local roundOutcomeResolved = signalsFolder:WaitForChild("RoundOutcomeResolved") :: BindableEvent

local teleportAnnouncedEvent = remotesFolder:WaitForChild("TeleportAnnounced") :: RemoteEvent
local roundStateUpdatedEvent = remotesFolder:WaitForChild("RoundStateUpdated") :: RemoteEvent
local roundOutcomeEvent = remotesFolder:WaitForChild("RoundOutcome") :: RemoteEvent
local toggleFlashlightRequest = remotesFolder:WaitForChild("ToggleFlashlightRequest") :: RemoteEvent

local lobbySpawn = Workspace:WaitForChild("SpawnLocation") :: SpawnLocation
local storyEntranceSpawn = Workspace:WaitForChild("StoryEntranceSpawn") :: BasePart
local storyExitGate = Workspace:WaitForChild("StoryExitGate") :: BasePart
local storyExitTrigger = Workspace:WaitForChild("StoryExitTrigger") :: BasePart
local spectatorSpawn = Workspace:WaitForChild("StorySpectatorSpawn") :: BasePart
local storyGeometry = Workspace:WaitForChild("StoryMapGeometry")

local ROUND_RETURN_DELAY = 2.5
local ROUND_START_TELEPORT_DELAY = 0.5
local REVIVE_SECONDS = 60
local BROADCAST_INTERVAL = 1
local FLASHLIGHT_UPDATE_INTERVAL = 1
local SANITY_UPDATE_INTERVAL = 1

local activeRound = nil
local exitTouchConnection = nil

local function getModeTimeLimit(modeId: string): number
	return GameConfig.MODE_TIME_LIMITS[modeId] or GameConfig.MODE_TIME_LIMITS[GameConfig.DEFAULT_MODE_ID]
end

local function getModeName(modeId: string): string
	local mode = GameConfig.getModeById(modeId)
	if mode then
		return mode.NameAr
	end
	return modeId
end

local function getModeTuning(modeId: string)
	return GameConfig.MODE_TUNING[modeId] or GameConfig.MODE_TUNING[GameConfig.DEFAULT_MODE_ID]
end

local function getHiddenDwellWindow(modeId: string)
	local tuning = getModeTuning(modeId)
	return tuning.Hiding.DwellMin, tuning.Hiding.DwellMax
end

local function getFlashlightTuning(modeId: string)
	return getModeTuning(modeId).Flashlight
end

local function getSanityTuning(modeId: string)
	return getModeTuning(modeId).Sanity
end

local function getGameplayTuning(modeId: string)
	return getModeTuning(modeId).Gameplay
end

local function asPlayerArray(payloadPlayers)
	local result = {}
	local seen = {}

	if type(payloadPlayers) ~= "table" then
		return result
	end

	for _, candidate in ipairs(payloadPlayers) do
		if typeof(candidate) == "Instance" and candidate:IsA("Player") and not seen[candidate.UserId] then
			seen[candidate.UserId] = true
			table.insert(result, candidate)
		end
	end

	return result
end

local function getCharacter(player: Player)
	local character = player.Character
	if character and character.Parent then
		return character
	end

	character = player.CharacterAdded:Wait()
	return character
end

local function getHumanoid(character: Model)
	return character:FindFirstChildOfClass("Humanoid")
end

local function setCharacterStatus(character: Model, status: string)
	character:SetAttribute("GatewayStatus", status)
	character:SetAttribute("GatewayAlive", status == "Alive")
	character:SetAttribute("GatewayDowned", status == "Downed")
	character:SetAttribute("GatewayDead", status == "Dead")
	character:SetAttribute("GatewayEscaped", status == "Escaped")
end

local function freezeCharacter(character: Model, frozen: boolean)
	local humanoid = getHumanoid(character)
	if not humanoid then
		return
	end

	if frozen then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.AutoRotate = false
		humanoid.PlatformStand = true
	else
		humanoid.WalkSpeed = 16
		humanoid.JumpPower = 50
		humanoid.AutoRotate = true
		humanoid.PlatformStand = false
	end
end

local function moveCharacter(player: Player, cframe: CFrame)
	local character = getCharacter(player)
	local ok = pcall(function()
		character:PivotTo(cframe)
	end)
	if not ok then
		warn(`Gateway to Hell: failed to move {player.Name}`)
	end
end

local function safeDestroy(instance)
	if instance and instance.Parent then
		pcall(function()
			instance:Destroy()
		end)
	end
end

local function setGateClosed()
	storyExitGate.CanCollide = true
	storyExitGate.CanQuery = true
	storyExitGate.CanTouch = true
	storyExitGate.Transparency = 0
	storyExitGate.Material = Enum.Material.Slate
	storyExitGate.Color = Color3.fromRGB(55, 44, 42)
end

local function setGateOpen()
	storyExitGate.CanCollide = false
	storyExitGate.CanQuery = false
	storyExitGate.CanTouch = true
	storyExitGate.Transparency = 0.42
	storyExitGate.Material = Enum.Material.Neon
	storyExitGate.Color = Color3.fromRGB(255, 128, 68)
end

local function createPuzzleState(definition)
	return {
		Id = definition.Id,
		Label = definition.Label,
		Total = definition.Total,
		Current = 0,
		State = "idle",
		Solved = false,
	}
end

local function createPlayerState(player: Player, modeId: string)
	return {
		player = player,
		round = nil,
		name = player.Name,
		status = "Alive",
		hiding = false,
		hideSpotId = nil,
		hideToken = 0,
		hideExpiresAt = nil,
		battery = 100,
		flashlightOn = false,
		sanity = 100,
		sanityState = "Safe",
		sanityDirty = false,
		allowRevive = getGameplayTuning(modeId).AllowRevive,
		revivePrompt = nil,
		revivePromptHighlight = nil,
		flashlightLight = nil,
		flashlightAttachment = nil,
		flashlightSpotLight = nil,
	}
end

local function buildObjectiveSummary(round)
	if round.gateOpen then
		return "البوابة مفتوحة، اهرب الآن"
	end

	if round.huntActive then
		return `الحارس يطارد الفريق • الألغاز {round.solvedCount}/{round.puzzlesTotal}`
	end

	return `ألغاز مكتملة {round.solvedCount}/{round.puzzlesTotal}`
end

local function getPlayerState(round, player)
	return round.playerStates[player.UserId]
end

local function makeSelfState(round, player)
	local state = getPlayerState(round, player)
	if not state then
		return nil
	end

	local bleedRemaining = 0
	if state.status == "Downed" and state.bleedOutAt then
		bleedRemaining = math.max(0, math.ceil(state.bleedOutAt - os.clock()))
	end

	return {
		State = state.status,
		BleedRemaining = bleedRemaining,
		DownedAt = state.downedAt,
		ReviveAvailable = state.status == "Downed",
		Escaped = state.status == "Escaped",
		Dead = state.status == "Dead",
		Hidden = state.hiding,
		HideSpotId = state.hideSpotId,
		Battery = state.battery,
		FlashlightOn = state.flashlightOn,
		Sanity = state.sanity,
		SanityState = state.sanityState,
	}
end

local function makeStateSnapshot(round, forPlayer)
	local elapsed = math.max(0, os.clock() - round.startTime)
	local remaining = math.max(0, math.floor(round.timeLimit - elapsed))
	local objectives = {}

	for _, puzzleId in ipairs(round.puzzleOrder) do
		local state = round.puzzlesById[puzzleId]
		table.insert(objectives, {
			PuzzleId = state.Id,
			Label = state.Label,
			Current = state.Current,
			Total = state.Total,
			State = state.State,
			Solved = state.Solved,
		})
	end

	local players = {}
	for userId, state in pairs(round.playerStates) do
		table.insert(players, {
			UserId = userId,
			Name = state.name,
			State = state.status,
			BleedRemaining = state.status == "Downed" and state.bleedOutAt and math.max(0, math.ceil(state.bleedOutAt - os.clock())) or 0,
			CanRevive = state.status == "Downed",
			Escaped = state.status == "Escaped",
			Dead = state.status == "Dead",
			Hidden = state.hiding,
			Battery = state.battery,
			FlashlightOn = state.flashlightOn,
			Sanity = state.sanity,
			SanityState = state.sanityState,
		})
	end

	local selfState = nil
	if forPlayer then
		selfState = makeSelfState(round, forPlayer)
	end

	return {
		Active = true,
		ModeId = round.modeId,
		ModeName = round.modeName,
		Remaining = remaining,
		ObjectiveSummary = buildObjectiveSummary(round),
		Objectives = objectives,
		PuzzlesSolved = round.solvedCount,
		PuzzlesTotal = round.puzzlesTotal,
		GateOpen = round.gateOpen,
		PlayerCount = round.playerCount,
		HuntActive = round.huntActive,
		HuntPhase = round.huntPhase,
		Monster = round.monsterTelemetry,
		Players = players,
		SelfState = selfState,
	}
end

local function broadcastState(round)
	for userId, player in pairs(round.playersByUserId) do
		if player.Parent == Players then
			roundStateUpdatedEvent:FireClient(player, makeStateSnapshot(round, player))
		else
			round.playersByUserId[userId] = nil
			round.playerStates[userId] = nil
		end
	end
end

local function broadcastOutcome(round, result: string, reason: string)
	local endingType = round.endingType
	if not endingType then
		if result == "Lose" then
			endingType = "Bad"
		else
			endingType = "Good"
		end
	end

	local payload = {
		Result = result,
		Reason = reason,
		EndingType = endingType,
		ModeId = round.modeId,
		ModeName = round.modeName,
		Duration = math.max(0, os.clock() - round.startTime),
		Remaining = math.max(0, math.floor(round.timeLimit - (os.clock() - round.startTime))),
		SecretObjectiveComplete = round.secretObjectiveComplete == true,
		EscapedCount = round.escapedCount or 0,
		DeadCount = round.deadCount or 0,
		HasNoDeaths = (round.deadCount or 0) == 0,
		Players = round.playersArray,
		Participants = {},
	}

	for userId, state in pairs(round.playerStates) do
		table.insert(payload.Participants, {
			UserId = userId,
			Name = state.name,
			State = state.status,
		})
	end

	for _, player in pairs(round.playersByUserId) do
		if player.Parent == Players then
			roundOutcomeEvent:FireClient(player, payload)
		end
	end

	roundOutcomeResolved:Fire(payload)
end

local function rewardPlayer(player: Player, roundDuration: number)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then
		return
	end

	local wins = leaderstats:FindFirstChild("Wins")
	local stars = leaderstats:FindFirstChild("Stars")
	local fastestTime = leaderstats:FindFirstChild("FastestTime")

	if wins and wins:IsA("IntValue") then
		wins.Value += 1
	end

	if stars and stars:IsA("IntValue") then
		stars.Value += 1
	end

	if fastestTime and fastestTime:IsA("NumberValue") then
		if fastestTime.Value <= 0 or roundDuration < fastestTime.Value then
			fastestTime.Value = roundDuration
		end
	end
end

local function getCharacterRoot(character: Model)
	return character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Head")
end

local function updateCharacterAttributes(state)
	local character = state.player.Character
	if not character then
		return
	end

	setCharacterStatus(character, state.status)
	character:SetAttribute("GatewayHidden", state.hiding)
	character:SetAttribute("GatewayHideSpotId", state.hideSpotId or "")
	character:SetAttribute("GatewayBattery", state.battery)
	character:SetAttribute("GatewayFlashlightOn", state.flashlightOn)
	character:SetAttribute("GatewaySanity", state.sanity)
	character:SetAttribute("GatewaySanityState", state.sanityState)
end

local function ensureFlashlightRig(state)
	local character = state.player.Character
	if not character then
		return
	end

	local rootPart = getCharacterRoot(character)
	if not rootPart or not rootPart:IsA("BasePart") then
		return
	end

	if state.flashlightAttachment and state.flashlightAttachment.Parent ~= rootPart then
		safeDestroy(state.flashlightAttachment)
		state.flashlightAttachment = nil
		state.flashlightSpotLight = nil
	end

	if not state.flashlightAttachment then
		local attachment = Instance.new("Attachment")
		attachment.Name = "GuardianFlashlightAttachment"
		attachment.Position = Vector3.new(0, 0, -0.7)
		attachment.Parent = rootPart
		state.flashlightAttachment = attachment

		local spot = Instance.new("SpotLight")
		spot.Name = "GuardianFlashlight"
		spot.Color = Color3.fromRGB(255, 244, 220)
		spot.Angle = 55
		spot.Range = 26
		spot.Brightness = 0
		spot.Enabled = false
		spot.Shadows = true
		spot.Parent = attachment
		state.flashlightSpotLight = spot
	end
end

local function setFlashlightEnabled(state, enabled)
	state.flashlightOn = enabled and state.battery > 0
	ensureFlashlightRig(state)
	if state.flashlightSpotLight then
		state.flashlightSpotLight.Enabled = state.flashlightOn
		state.flashlightSpotLight.Brightness = if state.flashlightOn then 2.6 else 0
	end
	updateCharacterAttributes(state)
end

local function setHiddenState(round, state, hidden, spotId, spotLabel)
	if state.status ~= "Alive" and hidden then
		return false
	end

	if hidden then
		local occupied = round.hiddenSpotOccupants[spotId]
		if occupied and occupied ~= state.player.UserId then
			return false
		end

		round.hiddenSpotOccupants[spotId] = state.player.UserId
		state.hiding = true
		state.hideSpotId = spotId
		state.hideSpotLabel = spotLabel
		state.hideToken += 1
		state.hideExpiresAt = os.clock() + math.random(getHiddenDwellWindow(round.modeId))
		setFlashlightEnabled(state, false)
		updateCharacterAttributes(state)
		return true
	end

	if state.hideSpotId then
		hideSpotReleased:Fire({
			Player = state.player,
			SpotId = state.hideSpotId,
		})
		round.hiddenSpotOccupants[state.hideSpotId] = nil
	end

	state.hiding = false
	state.hideSpotId = nil
	state.hideSpotLabel = nil
	state.hideExpiresAt = nil
	state.hideToken += 1
	updateCharacterAttributes(state)
	return true
end

local function releaseHiddenState(round, state)
	if not state.hiding and not state.hideSpotId then
		return
	end

	local spotId = state.hideSpotId
	if spotId then
		hideSpotReleased:Fire({
			Player = state.player,
			SpotId = spotId,
		})
		round.hiddenSpotOccupants[spotId] = nil
	end

	state.hiding = false
	state.hideSpotId = nil
	state.hideSpotLabel = nil
	state.hideExpiresAt = nil
	state.hideToken += 1
	updateCharacterAttributes(state)
end

local function changeSanity(state, amount)
	state.sanity = math.clamp((state.sanity or 100) + amount, 0, 100)
	if state.sanity <= getSanityTuning(state.round.modeId).LowThreshold then
		state.sanityState = "Critical"
	elseif state.sanity <= 55 then
		state.sanityState = "Low"
	else
		state.sanityState = "Safe"
	end
	updateCharacterAttributes(state)
end

local function isNearLight(character: Model)
	local root = getCharacterRoot(character)
	if not root or not root:IsA("BasePart") then
		return false
	end

	local probes = {}
	for _, descendant in ipairs(storyGeometry:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name == "StoryLightProbe" then
			table.insert(probes, descendant)
		end
	end

	for _, probe in ipairs(probes) do
		if (probe.Position - root.Position).Magnitude <= 18 then
			return true
		end
	end

	return false
end

local function clearParticipantVisuals(participantState)
	safeDestroy(participantState.revivePrompt)
	safeDestroy(participantState.revivePromptHighlight)
	participantState.revivePrompt = nil
	participantState.revivePromptHighlight = nil
end

local function cleanupRoundVisuals(round)
	for _, state in pairs(round.playerStates) do
		releaseHiddenState(round, state)
		clearParticipantVisuals(state)
		safeDestroy(state.flashlightSpotLight)
		safeDestroy(state.flashlightAttachment)
		state.flashlightSpotLight = nil
		state.flashlightAttachment = nil
	end
end

local function returnPlayerToLobby(player: Player, index: number)
	local lobbyCFrame = lobbySpawn.CFrame * CFrame.new((index - 1) * 3.5, 4, 0)
	moveCharacter(player, lobbyCFrame)
end

local function allParticipantsDead(round)
	for _, state in pairs(round.playerStates) do
		if state.status == "Alive" or state.status == "Downed" then
			return false
		end
	end

	return true
end

local function endRound(round, result: string, reason: string)
	if not round or round.ending then
		return
	end

	round.ending = true
	round.finished = true
	round.result = result
	round.reason = reason
	if not round.endingType then
		round.endingType = if result == "Lose" then "Bad" else "Good"
	end

	if round.huntActive then
		huntStopRequested:Fire({ RoundId = round.roundId })
	end

	broadcastOutcome(round, result, reason)
	cleanupRoundVisuals(round)

	local survivors = {}
	for _, player in pairs(round.playersByUserId) do
		local state = round.playerStates[player.UserId]
		if player.Parent == Players and state and state.status ~= "Dead" then
			table.insert(survivors, player)
		end
	end

	task.delay(ROUND_RETURN_DELAY, function()
		if result == "Win" then
			local duration = math.max(0, os.clock() - round.startTime)
			for _, player in ipairs(survivors) do
				rewardPlayer(player, duration)
			end
		end

		for index, player in ipairs(survivors) do
			if player.Parent == Players then
				local character = player.Character
				if character then
					setCharacterStatus(character, "Alive")
					freezeCharacter(character, false)
				end
				returnPlayerToLobby(player, index)
			end
		end

		activeRound = nil
		setGateClosed()
	end)
end

local function allParticipantsResolved(round)
	for _, state in pairs(round.playerStates) do
		if state.status == "Alive" or state.status == "Downed" then
			return false
		end
	end

	return true
end

local function computeEndingType(round)
	if round.secretObjectiveComplete and round.escapedCount > 0 then
		return "Secret"
	end

	return "Good"
end

local function maybeResolveRound(round)
	if not round or round.ending then
		return
	end

	if allParticipantsDead(round) then
		round.badEndingTriggered = true
		endRound(round, "Lose", "all_dead")
		return
	end

	if allParticipantsResolved(round) and round.escapedCount > 0 then
		round.endingType = computeEndingType(round)
		endRound(round, "Win", round.endingType == "Secret" and "secret_escape" or "all_survivors_escaped")
	end
end

local function maybeOpenGate(round)
	if not round.gateOpen and round.solvedCount >= round.puzzlesTotal then
		round.gateOpen = true
		setGateOpen()
		broadcastState(round)
	end
end

local function setParticipantStatus(round, player: Player, status: string)
	local state = round.playerStates[player.UserId]
	if not state then
		return
	end

	state.status = status
	local character = player.Character
	if character then
		setCharacterStatus(character, status)
	end
end

local function attachRevivePrompt(round, player: Player)
	local state = round.playerStates[player.UserId]
	if not state then
		return
	end

	if not state.allowRevive then
		return
	end

	releaseHiddenState(round, state)
	clearParticipantVisuals(state)

	local character = player.Character
	if not character then
		return
	end

	local rootPart = character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Head")
	if not rootPart or not rootPart:IsA("BasePart") then
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RevivePrompt"
	prompt.ActionText = "إنعاش"
	prompt.ObjectText = player.Name
	prompt.HoldDuration = 3
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = rootPart

	local highlight = Instance.new("Highlight")
	highlight.Name = "DownedHighlight"
	highlight.FillColor = Color3.fromRGB(180, 42, 36)
	highlight.OutlineColor = Color3.fromRGB(255, 140, 77)
	highlight.FillTransparency = 0.6
	highlight.OutlineTransparency = 0.2
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = character

	state.revivePrompt = prompt
	state.revivePromptHighlight = highlight

	prompt.Triggered:Connect(function(reviver)
		if not activeRound or activeRound ~= round or round.ending then
			return
		end

		local targetState = round.playerStates[player.UserId]
		local reviverState = round.playerStates[reviver.UserId]
		if not targetState or not reviverState then
			return
		end

		if targetState.status ~= "Downed" or reviverState.status ~= "Alive" or reviver == player then
			return
		end

		clearParticipantVisuals(targetState)
		setParticipantStatus(round, player, "Alive")
		targetState.downedAt = nil
		targetState.bleedOutAt = nil
		targetState.downReason = nil
		local revivedCharacter = player.Character
		if revivedCharacter then
			freezeCharacter(revivedCharacter, false)
			local humanoid = getHumanoid(revivedCharacter)
			if humanoid then
				humanoid.Health = math.max(humanoid.Health, 1)
			end
		end
		broadcastState(round)
	end)
end

local function markPlayerDead(round, player: Player, reason: string)
	local state = round.playerStates[player.UserId]
	if not state or state.status == "Dead" or state.status == "Escaped" then
		return
	end

	releaseHiddenState(round, state)
	clearParticipantVisuals(state)
	state.status = "Dead"
	state.deadReason = reason
	state.deadAt = os.clock()
	round.deadCount = (round.deadCount or 0) + 1

	local character = player.Character
	if character then
		setCharacterStatus(character, "Dead")
		freezeCharacter(character, true)
		pcall(function()
			character:PivotTo(spectatorSpawn.CFrame * CFrame.new((player.UserId % 3) * 4, 0, math.floor(player.UserId % 5) * 4))
		end)
	end

	updateCharacterAttributes(state)

	broadcastState(round)
	maybeResolveRound(round)
end

local function markPlayerDowned(round, player: Player, source: string)
	local state = round.playerStates[player.UserId]
	if not state or state.status ~= "Alive" then
		return
	end

	if state.hiding then
		releaseHiddenState(round, state)
	end

	if not state.allowRevive then
		markPlayerDead(round, player, source or "hardcore")
		return
	end

	setParticipantStatus(round, player, "Downed")
	state.downedAt = os.clock()
	state.bleedOutAt = state.downedAt + REVIVE_SECONDS
	state.downReason = source

	local character = player.Character
	if character then
		setCharacterStatus(character, "Downed")
		freezeCharacter(character, true)
		attachRevivePrompt(round, player)
	end

	updateCharacterAttributes(state)

	broadcastState(round)

	task.delay(REVIVE_SECONDS, function()
		if not activeRound or activeRound ~= round or round.ending then
			return
		end

		local delayedState = round.playerStates[player.UserId]
		if delayedState and delayedState.status == "Downed" and delayedState.bleedOutAt and os.clock() >= delayedState.bleedOutAt then
			markPlayerDead(round, player, "bleedout")
		end
	end)
end

local function markPlayerEscaped(round, player: Player)
	local state = round.playerStates[player.UserId]
	if not state or state.status ~= "Alive" then
		return
	end

	releaseHiddenState(round, state)
	clearParticipantVisuals(state)
	state.status = "Escaped"
	state.escapedAt = os.clock()
	round.escapedCount = (round.escapedCount or 0) + 1

	local character = player.Character
	if character then
		setCharacterStatus(character, "Escaped")
	end

	updateCharacterAttributes(state)

	broadcastState(round)
	maybeResolveRound(round)
end

local function handlePuzzleProgress(payload)
	if not activeRound or type(payload) ~= "table" then
		return
	end

	local puzzleId = payload.PuzzleId
	if type(puzzleId) ~= "string" then
		return
	end

	local puzzle = activeRound.puzzlesById[puzzleId]
	if not puzzle then
		return
	end

	if payload.Label then
		puzzle.Label = payload.Label
	end
	if payload.Total then
		puzzle.Total = math.max(1, tonumber(payload.Total) or puzzle.Total)
	end
	if payload.Current ~= nil then
		puzzle.Current = math.clamp(tonumber(payload.Current) or puzzle.Current, 0, puzzle.Total)
	end
	if payload.State then
		puzzle.State = tostring(payload.State)
	end
	if payload.Solved == true then
		if not puzzle.Solved then
			puzzle.Solved = true
			activeRound.solvedCount += 1
		end
		puzzle.Current = puzzle.Total
		puzzle.State = "solved"
		maybeOpenGate(activeRound)
		broadcastState(activeRound)
		return
	end

	broadcastState(activeRound)
end

local function handlePuzzleSolved(payload)
	if type(payload) ~= "table" then
		return
	end

	local puzzleId = payload.PuzzleId
	if type(puzzleId) ~= "string" then
		return
	end

	local puzzle = activeRound and activeRound.puzzlesById[puzzleId]
	if not puzzle then
		return
	end

	if not puzzle.Solved then
		puzzle.Solved = true
		puzzle.Current = puzzle.Total
		puzzle.State = "solved"
		activeRound.solvedCount += 1
	end

	maybeOpenGate(activeRound)
	broadcastState(activeRound)
end

local function handleMonsterCaught(payload)
	if not activeRound or type(payload) ~= "table" then
		return
	end

	local player = payload.Player
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return
	end

	if not activeRound.playersByUserId[player.UserId] then
		return
	end

	markPlayerDowned(activeRound, player, payload.Source or "monster")
end

local function handleMonsterTelemetry(payload)
	if not activeRound or type(payload) ~= "table" then
		return
	end

	activeRound.monsterTelemetry = {
		State = payload.State,
		TargetUserId = payload.TargetUserId,
		Distance = payload.Distance,
		Intensity = payload.Intensity,
		SearchTarget = payload.SearchTarget,
		LastKnownPosition = payload.LastKnownPosition,
		Position = payload.Position,
	}
	broadcastState(activeRound)
end

local function handleSecretObjectiveCompleted(payload)
	if not activeRound or type(payload) ~= "table" then
		return
	end

	local player = payload.Player
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return
	end

	local state = activeRound.playerStates[player.UserId]
	if not state or state.status ~= "Alive" then
		return
	end

	if activeRound.secretObjectiveComplete then
		return
	end

	activeRound.secretObjectiveComplete = true
	activeRound.secretObjectivePlayer = player.UserId
	broadcastState(activeRound)
end

local function handleHideSpotRequest(payload)
	if not activeRound or type(payload) ~= "table" then
		return
	end

	local player = payload.Player
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return
	end

	local state = activeRound.playerStates[player.UserId]
	if not state or state.status ~= "Alive" then
		return
	end

	local spotId = payload.SpotId
	if type(spotId) ~= "string" then
		return
	end

	if payload.Hidden == true then
		if setHiddenState(activeRound, state, true, spotId, payload.SpotLabel) then
			broadcastState(activeRound)
		else
			hideSpotReleased:Fire({
				Player = player,
				SpotId = spotId,
			})
		end
	else
		if setHiddenState(activeRound, state, false, spotId, payload.SpotLabel) then
			broadcastState(activeRound)
		end
	end
end

local function handleBatteryPickup(payload)
	if not activeRound or type(payload) ~= "table" then
		return
	end

	local player = payload.Player
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return
	end

	local state = activeRound.playerStates[player.UserId]
	if not state or state.status == "Dead" then
		return
	end

	local amount = getFlashlightTuning(activeRound.modeId).BatteryPickupAmount
	state.battery = math.clamp(state.battery + amount, 0, 100)
	if state.battery > 0 and state.flashlightOn then
		ensureFlashlightRig(state)
		if state.flashlightSpotLight then
			state.flashlightSpotLight.Enabled = true
		end
	end
	updateCharacterAttributes(state)
	broadcastState(activeRound)
end

local function handleFlashlightToggle(player: Player)
	if not activeRound or activeRound.ending then
		return
	end

	local state = activeRound.playerStates[player.UserId]
	if not state or state.status ~= "Alive" then
		return
	end

	if state.hiding then
		return
	end

	if state.battery <= 0 then
		setFlashlightEnabled(state, false)
		broadcastState(activeRound)
		return
	end

	setFlashlightEnabled(state, not state.flashlightOn)
	broadcastState(activeRound)
end

local function startHunt(round)
	if round.huntActive then
		return
	end

	round.huntActive = true
	round.huntPhase = "Hunt"
	round.huntStartedAt = os.clock()
	huntStartRequested:Fire({
		RoundId = round.roundId,
		ModeId = round.modeId,
		ModeTuning = round.modeTuning,
		Players = round.playersArray,
		StoryRegionOrigin = GameConfig.STORY_REGION_ORIGIN,
	})
	broadcastState(round)
end

local function attachExitListener()
	if exitTouchConnection then
		exitTouchConnection:Disconnect()
	end

	exitTouchConnection = storyExitTrigger.Touched:Connect(function(hit)
		if typeof(hit) ~= "Instance" then
			return
		end

		if not activeRound or not activeRound.gateOpen or activeRound.ending then
			return
		end

		local character = hit.Parent
		if not character then
			return
		end

		local player = Players:GetPlayerFromCharacter(character)
		if not player and character.Parent then
			player = Players:GetPlayerFromCharacter(character.Parent)
		end

		if not player or not activeRound.playersByUserId[player.UserId] then
			return
		end

		local state = activeRound.playerStates[player.UserId]
		if state and state.status ~= "Alive" then
			return
		end

		markPlayerEscaped(activeRound, player)
	end)
end

local function beginRound(payload)
	if activeRound and not activeRound.finished then
		warn("Gateway to Hell: round request ignored because a round is already active.")
		return
	end

	local playersForRound = asPlayerArray(payload and payload.Players)
	if #playersForRound == 0 then
		return
	end

	local modeId = if type(payload) == "table" and type(payload.ModeId) == "string" then payload.ModeId else GameConfig.DEFAULT_MODE_ID
	local modeName = getModeName(modeId)
	local timeLimit = getModeTimeLimit(modeId)
	local modeTuning = getModeTuning(modeId)
	local puzzleDefs = StoryPuzzles.getOrderedDefinitions()
	local round = {
		roundId = tostring(os.clock()) .. `_{math.random(1000, 9999)}`,
		modeId = modeId,
		modeName = modeName,
		modeTuning = modeTuning,
		timeLimit = timeLimit,
		startTime = os.clock(),
		playerCount = #playersForRound,
		puzzlesTotal = #puzzleDefs,
		solvedCount = 0,
		escapedCount = 0,
		deadCount = 0,
		gateOpen = false,
		huntActive = false,
		huntPhase = "Puzzle",
		secretObjectiveComplete = false,
		secretObjectivePlayer = nil,
		endingType = nil,
		playersArray = playersForRound,
		playersByUserId = {},
		playerStates = {},
		puzzleOrder = {},
		puzzlesById = {},
		monsterTelemetry = nil,
		hiddenSpotOccupants = {},
		ending = false,
		finished = false,
	}

	for _, def in ipairs(puzzleDefs) do
		table.insert(round.puzzleOrder, def.Id)
		round.puzzlesById[def.Id] = createPuzzleState(def)
	end

	setGateClosed()

	for index, player in ipairs(playersForRound) do
		local state = createPlayerState(player, modeId)
		state.round = round
		round.playersByUserId[player.UserId] = player
		round.playerStates[player.UserId] = state
		teleportAnnouncedEvent:FireClient(player, {
			Destination = "StoryRegion",
			ModeName = modeName,
			PlayerCount = #playersForRound,
		})
		task.delay(ROUND_START_TELEPORT_DELAY, function()
			if activeRound == round and round.playersByUserId[player.UserId] == player and player.Parent == Players then
				local offsetX = ((index - 1) % 3) * 2.5
				local offsetZ = math.floor((index - 1) / 3) * 3.0
				moveCharacter(player, storyEntranceSpawn.CFrame * CFrame.new(offsetX, 0, offsetZ))
				local character = player.Character
				if character then
					setCharacterStatus(character, "Alive")
					freezeCharacter(character, false)
					local playerState = round.playerStates[player.UserId]
					if playerState then
						ensureFlashlightRig(playerState)
						updateCharacterAttributes(playerState)
					end
				end
			end
		end)
	end

	activeRound = round
	broadcastState(round)

	task.spawn(function()
		local lastBroadcast = 0
		local updateInterval = math.min(FLASHLIGHT_UPDATE_INTERVAL, SANITY_UPDATE_INTERVAL)
		while activeRound == round and not round.ending do
			local elapsed = os.clock() - round.startTime
			local remaining = round.timeLimit - elapsed
			local now = os.clock()

			if not round.huntActive and remaining <= 0 then
				startHunt(round)
			end

			for _, player in ipairs(round.playersArray) do
				local state = round.playerStates[player.UserId]
				if state and state.status == "Downed" and state.bleedOutAt and now >= state.bleedOutAt then
					markPlayerDead(round, player, "bleedout")
				elseif state and state.hiding and state.hideExpiresAt and now >= state.hideExpiresAt then
					local expiredSpotId = state.hideSpotId
					local expiredSpotLabel = state.hideSpotLabel
					setHiddenState(round, state, false, expiredSpotId, expiredSpotLabel)
					broadcastState(round)
					monsterCaughtPlayer:Fire({ Player = player, Source = "hidden_dwell", SpotId = expiredSpotId })
				elseif state and state.status == "Alive" then
					local dt = updateInterval
					local flashlightTuning = getFlashlightTuning(round.modeId)
					local sanityTuning = getSanityTuning(round.modeId)
					local character = player.Character
					if state.flashlightOn then
						state.battery = math.max(0, state.battery - (flashlightTuning.BatteryDrainPerSecond * dt))
						if state.battery <= 0 then
							state.battery = 0
							setFlashlightEnabled(state, false)
						end
					end

					local sanityDelta = 0
					if character then
						if isNearLight(character) then
							sanityDelta += sanityTuning.RecoveryPerSecond * dt
						else
							sanityDelta -= sanityTuning.DarkDrainPerSecond * dt
						end

						if state.hiding then
							sanityDelta += sanityTuning.HiddenDrainPerSecond * dt
						end
					end

					if round.monsterTelemetry and round.monsterTelemetry.Position and character then
						local root = getCharacterRoot(character)
						if root and root:IsA("BasePart") then
							local monsterDistance = (round.monsterTelemetry.Position - root.Position).Magnitude
							if monsterDistance < 60 then
								sanityDelta -= math.clamp((60 - monsterDistance) / 60, 0, 1) * sanityTuning.MonsterDrainPerSecond * dt
							end
						end
					end

					if round.huntActive then
						sanityDelta -= 0.15 * dt
					end

					if math.abs(sanityDelta) > 0 then
						changeSanity(state, sanityDelta)
					end

					updateCharacterAttributes(state)
				end
			end

			maybeResolveRound(round)

			if os.clock() - lastBroadcast >= BROADCAST_INTERVAL then
				broadcastState(round)
				lastBroadcast = os.clock()
			end

			task.wait(updateInterval)
		end
	end)
end

roundStartRequested.Event:Connect(beginRound)
puzzleProgressEvent.Event:Connect(handlePuzzleProgress)
puzzleSolvedEvent.Event:Connect(handlePuzzleSolved)
monsterCaughtPlayer.Event:Connect(handleMonsterCaught)
monsterStateUpdated.Event:Connect(handleMonsterTelemetry)
hideSpotRequested.Event:Connect(handleHideSpotRequest)
batteryPickupCollected.Event:Connect(handleBatteryPickup)
secretObjectiveCompleted.Event:Connect(handleSecretObjectiveCompleted)
toggleFlashlightRequest.OnServerEvent:Connect(handleFlashlightToggle)

Players.PlayerRemoving:Connect(function(player)
	if not activeRound then
		return
	end

	local round = activeRound
	local state = round.playerStates[player.UserId]
	if state then
		releaseHiddenState(round, state)
		clearParticipantVisuals(state)
	end
	round.playersByUserId[player.UserId] = nil
	round.playerStates[player.UserId] = nil

	if not round.ending then
		maybeResolveRound(round)
	end
end)

attachExitListener()
setGateClosed()
