local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local signalsFolder = ReplicatedStorage:WaitForChild("GatewayToHellSignals")
local huntStartRequested = signalsFolder:WaitForChild("HuntStartRequested") :: BindableEvent
local huntStopRequested = signalsFolder:WaitForChild("HuntStopRequested") :: BindableEvent
local monsterCaughtPlayer = signalsFolder:WaitForChild("MonsterCaughtPlayer") :: BindableEvent
local monsterStateUpdated = signalsFolder:WaitForChild("MonsterStateUpdated") :: BindableEvent

local geometryRoot = Workspace:WaitForChild("StoryMapGeometry")

local monsterModel = nil
local monsterHumanoid = nil
local monsterRoot = nil

local activeHuntId = 0
local huntActive = false
local trackedPlayers = {}
local patrolPoints = {}
local patrolIndex = 1
local state = "Idle"
local targetPlayer = nil
local lastKnownPosition = nil
local currentGoal = nil
local currentPath = nil
local pathIndex = 1
local nextRepathAt = 0
local nextRelocateAt = 0
local lastTelemetryAt = 0
local lastCatchAt = 0
local lastSearchTarget = nil

local VISION_RANGE = 80
local HEARING_RANGE = 60
local CHASE_SPEED = 24
local PATROL_SPEED = 14
local INVESTIGATE_SPEED = 18
local CATCH_RANGE = 5
local REPATH_INTERVAL = 0.7
local TELEMETRY_INTERVAL = 0.25
local SEARCH_RELOCATE_MIN = 120
local SEARCH_RELOCATE_MAX = 180
local currentModeTuning = GameConfig.MODE_TUNING[GameConfig.DEFAULT_MODE_ID]
local currentModeId = GameConfig.DEFAULT_MODE_ID

local function getVisionRange()
	return currentModeTuning.Monster.VisionRange or VISION_RANGE
end

local function getHearingRange()
	return currentModeTuning.Monster.HearingRange or HEARING_RANGE
end

local function getCatchRange()
	return currentModeTuning.Monster.CatchRange or CATCH_RANGE
end

local function getSpeedMultiplier()
	return currentModeTuning.Monster.SpeedMultiplier or 1
end

local function getSearchRelocateMin()
	return currentModeTuning.Monster.SearchRelocateMin or SEARCH_RELOCATE_MIN
end

local function getSearchRelocateMax()
	return currentModeTuning.Monster.SearchRelocateMax or SEARCH_RELOCATE_MAX
end

local function safeDestroy(instance)
	if instance and instance.Parent then
		pcall(function()
			instance:Destroy()
		end)
	end
end

local function makePart(parent, name, size, cframe, color, material, transparency)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Transparency = transparency or 0
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = true
	part.CanQuery = false
	part.Massless = true
	part.Parent = parent
	return part
end

local function weldToRoot(part, root)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = part
	weld.Part1 = root
	weld.Parent = part
end

local function createMonsterModel()
	safeDestroy(monsterModel)

	local model = Instance.new("Model")
	model.Name = "GuardianOfHell"
	model.Parent = Workspace
	local spawnPoint = geometryRoot:WaitForChild("MonsterSpawnPoint") :: BasePart

	local root = makePart(model, "HumanoidRootPart", Vector3.new(2.6, 3.4, 1.9), spawnPoint.CFrame, Color3.fromRGB(18, 12, 16), Enum.Material.Slate, 1)
	root.RootPriority = 10
	root.CanCollide = false

	local humanoid = Instance.new("Humanoid")
	humanoid.Name = "GuardianHumanoid"
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.WalkSpeed = PATROL_SPEED
	humanoid.JumpPower = 40
	humanoid.HipHeight = 0
	humanoid.AutoRotate = true
	humanoid.Parent = model

	local torso = makePart(model, "Torso", Vector3.new(4.2, 5.2, 3.2), root.CFrame * CFrame.new(0, 0.5, 0), Color3.fromRGB(25, 18, 22), Enum.Material.Slate)
	local head = makePart(model, "Head", Vector3.new(2.8, 2.8, 2.6), root.CFrame * CFrame.new(0, 3.7, 0), Color3.fromRGB(25, 18, 22), Enum.Material.Slate)
	local armL = makePart(model, "LeftArm", Vector3.new(1.1, 4.2, 1.1), root.CFrame * CFrame.new(-2.8, 0.9, 0), Color3.fromRGB(22, 16, 20), Enum.Material.Slate)
	local armR = makePart(model, "RightArm", Vector3.new(1.1, 4.2, 1.1), root.CFrame * CFrame.new(2.8, 0.9, 0), Color3.fromRGB(22, 16, 20), Enum.Material.Slate)
	local legL = makePart(model, "LeftLeg", Vector3.new(1.2, 4.5, 1.2), root.CFrame * CFrame.new(-1.0, -3.8, 0), Color3.fromRGB(22, 16, 20), Enum.Material.Slate)
	local legR = makePart(model, "RightLeg", Vector3.new(1.2, 4.5, 1.2), root.CFrame * CFrame.new(1.0, -3.8, 0), Color3.fromRGB(22, 16, 20), Enum.Material.Slate)
	local hornL = makePart(model, "HornL", Vector3.new(0.7, 3.5, 0.7), root.CFrame * CFrame.new(-1.3, 5.0, -0.6) * CFrame.Angles(0, 0, math.rad(-25)), Color3.fromRGB(18, 14, 16), Enum.Material.Slate)
	local hornR = makePart(model, "HornR", Vector3.new(0.7, 3.5, 0.7), root.CFrame * CFrame.new(1.3, 5.0, -0.6) * CFrame.Angles(0, 0, math.rad(25)), Color3.fromRGB(18, 14, 16), Enum.Material.Slate)
	local eyeL = makePart(model, "EyeL", Vector3.new(0.24, 0.24, 0.24), root.CFrame * CFrame.new(-0.55, 3.8, -1.2), Color3.fromRGB(255, 52, 20), Enum.Material.Neon)
	local eyeR = makePart(model, "EyeR", Vector3.new(0.24, 0.24, 0.24), root.CFrame * CFrame.new(0.55, 3.8, -1.2), Color3.fromRGB(255, 52, 20), Enum.Material.Neon)
	local glow = makePart(model, "Glow", Vector3.new(6, 7, 0.2), root.CFrame * CFrame.new(0, 1.4, -1.0), Color3.fromRGB(255, 82, 35), Enum.Material.Neon, 0.65)

	for _, part in ipairs({ torso, head, armL, armR, legL, legR, hornL, hornR, eyeL, eyeR, glow }) do
		weldToRoot(part, root)
	end

	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 78, 36)
	light.Range = 18
	light.Brightness = 1.5
	light.Shadows = true
	light.Parent = glow

	model.PrimaryPart = root
	model:PivotTo(spawnPoint.CFrame)

	monsterModel = model
	monsterHumanoid = humanoid
	monsterRoot = root
	return model, humanoid, root
end

local function getWaypoints()
	local folder = geometryRoot:FindFirstChild("MonsterWaypoints")
	local items = {}

	if folder then
		for _, child in ipairs(folder:GetChildren()) do
			if child:IsA("BasePart") then
				table.insert(items, child)
			end
		end
		table.sort(items, function(a, b)
			return a.Name < b.Name
		end)
	end

	local positions = {}
	for _, part in ipairs(items) do
		table.insert(positions, part.Position)
	end

	if #positions == 0 then
		positions = {
			geometryRoot:FindFirstChild("MonsterSpawnPoint").Position,
			geometryRoot:FindFirstChild("StoryEntranceSpawn").Position,
			geometryRoot:FindFirstChild("StoryExitGate").Position,
		}
	end

	return positions
end

local function setState(newState, payload)
	state = newState
	monsterStateUpdated:Fire({
		State = state,
		TargetUserId = payload and payload.TargetUserId or nil,
		TargetName = payload and payload.TargetName or nil,
		Distance = payload and payload.Distance or nil,
		Intensity = payload and payload.Intensity or 0,
		SearchTarget = payload and payload.SearchTarget or nil,
		LastKnownPosition = payload and payload.LastKnownPosition or nil,
		Position = payload and payload.Position or nil,
		ModeId = payload and payload.ModeId or currentModeId,
	})
end

local function getTrackedPlayerCharacters()
	local results = {}
	for _, player in ipairs(trackedPlayers) do
		if player.Parent == Players then
			local character = player.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			local hum = character and character:FindFirstChildOfClass("Humanoid")
			local status = character and character:GetAttribute("GatewayStatus")
			local hidden = character and character:GetAttribute("GatewayHidden")
			if character and hrp and hum and status == "Alive" and not hidden then
				table.insert(results, { Player = player, Character = character, HumanoidRootPart = hrp, Humanoid = hum })
			end
		end
	end
	return results
end

local function hasLineOfSight(targetCharacter)
	if not monsterRoot then
		return false
	end

	local targetRoot = targetCharacter.HumanoidRootPart
	local direction = targetRoot.Position - monsterRoot.Position
	if direction.Magnitude <= 0 then
		return true
	end

	local coneDot = monsterRoot.CFrame.LookVector:Dot(direction.Unit)
	if coneDot < 0.15 then
		return false
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { monsterModel }
	params.IgnoreWater = true

	local hit = Workspace:Raycast(monsterRoot.Position + Vector3.new(0, 2, 0), direction, params)
	if not hit then
		return true
	end

	return hit.Instance:IsDescendantOf(targetCharacter.Character)
end

local function pickTarget()
	local candidates = getTrackedPlayerCharacters()
	local best = nil
	local bestScore = math.huge

	for _, entry in ipairs(candidates) do
		local distance = (entry.HumanoidRootPart.Position - monsterRoot.Position).Magnitude
		if distance <= getVisionRange() then
			local visible = hasLineOfSight(entry)
			local speed = entry.HumanoidRootPart.AssemblyLinearVelocity.Magnitude
			local loud = speed >= 10 or entry.Humanoid.WalkSpeed >= 18
			if visible then
				local score = distance - math.clamp(speed, 0, 20) * 0.5
				if score < bestScore then
					best = { Player = entry.Player, Distance = distance, Visible = true }
					bestScore = score
				end
			elseif distance <= getHearingRange() and loud then
				local score = distance + 15
				if score < bestScore then
					best = { Player = entry.Player, Distance = distance, Visible = false }
					bestScore = score
				end
			end
		end
	end

	return best
end

local function planPath(goalPosition)
	if not monsterHumanoid or not monsterRoot then
		return {}
	end

	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 7,
		AgentCanJump = true,
		AgentCanClimb = true,
	})

	local waypoints = {}
	local ok = pcall(function()
		path:ComputeAsync(monsterRoot.Position, goalPosition)
	end)

	if ok and path.Status == Enum.PathStatus.Success then
		waypoints = path:GetWaypoints()
	else
		waypoints = { { Position = goalPosition, Action = Enum.PathWaypointAction.Walk } }
	end

	return waypoints
end

local function refreshNavigation(goalPosition, useSearchTarget)
	currentGoal = goalPosition
	currentPath = planPath(goalPosition)
	pathIndex = 1
	nextRepathAt = os.clock() + REPATH_INTERVAL
	if useSearchTarget then
		lastSearchTarget = goalPosition
	end
end

local function advanceNavigation()
	if not monsterHumanoid or not monsterRoot or not currentPath then
		return
	end

	local waypoint = currentPath[pathIndex]
	if not waypoint then
		return
	end

	local destination = waypoint.Position
	if (monsterRoot.Position - destination).Magnitude <= 4 then
		pathIndex += 1
		return
	end

	if waypoint.Action == Enum.PathWaypointAction.Jump then
		monsterHumanoid.Jump = true
	end

	monsterHumanoid:MoveTo(destination)
end

local function choosePatrolTarget()
	if #patrolPoints == 0 then
		return geometryRoot:FindFirstChild("StoryExitGate").Position
	end

	patrolIndex = (patrolIndex % #patrolPoints) + 1
	return patrolPoints[patrolIndex]
end

local function catchPlayer(player)
	local now = os.clock()
	if now - lastCatchAt < 1.5 then
		return
	end

	lastCatchAt = now
	monsterCaughtPlayer:Fire({
		Player = player,
		Source = state,
	})
end

local function cleanupMonster()
	huntActive = false
	activeHuntId += 1
	trackedPlayers = {}
	patrolPoints = {}
	currentPath = nil
	pathIndex = 1
	currentGoal = nil
	targetPlayer = nil
	lastKnownPosition = nil
	lastSearchTarget = nil
	state = "Idle"
	safeDestroy(monsterModel)
	monsterModel = nil
	monsterHumanoid = nil
	monsterRoot = nil
end

local function runAI(huntId)
	while huntActive and activeHuntId == huntId and monsterModel and monsterHumanoid and monsterRoot do
		local now = os.clock()
		local target = pickTarget()
		if target then
			targetPlayer = target.Player
			local character = targetPlayer and targetPlayer.Character
			local targetRoot = character and character:FindFirstChild("HumanoidRootPart")
			if targetRoot then
				local targetPos = targetRoot.Position
				lastKnownPosition = targetPos
				monsterHumanoid.WalkSpeed = CHASE_SPEED * getSpeedMultiplier()
				state = "CHASE"
				setState("CHASE", {
					TargetUserId = targetPlayer.UserId,
					TargetName = targetPlayer.Name,
					Distance = target.Distance,
					Intensity = math.clamp(1 - (target.Distance / getVisionRange()), 0, 1),
					LastKnownPosition = lastKnownPosition,
					Position = monsterRoot.Position,
				})
				if not currentGoal or (currentGoal - targetPos).Magnitude > 6 or now >= nextRepathAt then
					refreshNavigation(targetPos, false)
				end
			else
				target = nil
			end
		else
			targetPlayer = nil
			local goal = nil
			if lastKnownPosition and (monsterRoot.Position - lastKnownPosition).Magnitude > 5 then
				monsterHumanoid.WalkSpeed = INVESTIGATE_SPEED * getSpeedMultiplier()
				state = "INVESTIGATE"
				goal = lastKnownPosition
			elseif now >= nextRelocateAt then
				monsterHumanoid.WalkSpeed = PATROL_SPEED * getSpeedMultiplier()
				state = "SEARCH"
				goal = choosePatrolTarget()
				nextRelocateAt = now + math.random(getSearchRelocateMin(), getSearchRelocateMax())
			else
				monsterHumanoid.WalkSpeed = PATROL_SPEED * getSpeedMultiplier()
				state = "PATROL"
				goal = choosePatrolTarget()
			end

			if goal and (not currentGoal or (currentGoal - goal).Magnitude > 4 or now >= nextRepathAt) then
				refreshNavigation(goal, state == "SEARCH")
			end
			setState(state, {
				Distance = nil,
				Intensity = 0,
				LastKnownPosition = lastKnownPosition,
				SearchTarget = lastSearchTarget,
				Position = monsterRoot.Position,
			})
		end

		advanceNavigation()

		if monsterRoot then
			for _, entry in ipairs(getTrackedPlayerCharacters()) do
				local distance = (entry.HumanoidRootPart.Position - monsterRoot.Position).Magnitude
				if distance <= getCatchRange() and entry.Character:GetAttribute("GatewayStatus") == "Alive" and not entry.Character:GetAttribute("GatewayHidden") then
					catchPlayer(entry.Player)
				end
			end
		end

		if now - lastTelemetryAt >= TELEMETRY_INTERVAL then
			monsterStateUpdated:Fire({
				State = state,
				TargetUserId = targetPlayer and targetPlayer.UserId or nil,
				TargetName = targetPlayer and targetPlayer.Name or nil,
				Distance = target and target.Distance or nil,
				Intensity = target and math.clamp(1 - (target.Distance / getVisionRange()), 0, 1) or 0,
				SearchTarget = lastSearchTarget,
				LastKnownPosition = lastKnownPosition,
				Position = monsterRoot and monsterRoot.Position or nil,
				ModeId = currentModeId,
			})
			lastTelemetryAt = now
		end

		task.wait(0.2)
	end
end

local function startHunt(payload)
	if huntActive then
		return
	end

	currentModeId = type(payload) == "table" and type(payload.ModeId) == "string" and payload.ModeId or GameConfig.DEFAULT_MODE_ID
	currentModeTuning = type(payload) == "table" and type(payload.ModeTuning) == "table" and payload.ModeTuning or GameConfig.MODE_TUNING[currentModeId] or GameConfig.MODE_TUNING[GameConfig.DEFAULT_MODE_ID]

	local players = {}
	if type(payload) == "table" and type(payload.Players) == "table" then
		for _, player in ipairs(payload.Players) do
			if typeof(player) == "Instance" and player:IsA("Player") then
				table.insert(players, player)
			end
		end
	end

	if #players == 0 then
		return
	end

	trackedPlayers = players
	patrolPoints = getWaypoints()
	patrolIndex = 0
	nextRelocateAt = os.clock() + math.random(getSearchRelocateMin(), getSearchRelocateMax())
	huntActive = true
	activeHuntId += 1
	local huntId = activeHuntId
	createMonsterModel()
	setState("PATROL", { SearchTarget = nil, Intensity = 0 })
	task.spawn(function()
		runAI(huntId)
	end)
end

local function stopHunt(payload)
	if not huntActive then
		return
	end

	if type(payload) == "table" and payload.RoundId then
		-- no-op placeholder for future multi-round coordination
	end

	cleanupMonster()
end

huntStartRequested.Event:Connect(startHunt)
huntStopRequested.Event:Connect(stopHunt)

if geometryRoot:FindFirstChild("MonsterSpawnPoint") == nil then
	warn("Gateway to Hell: MonsterSpawnPoint missing; monster will fail to spawn.")
end
