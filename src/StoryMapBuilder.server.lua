local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local StoryPuzzles = require(ReplicatedStorage:WaitForChild("StoryPuzzles"))

local signalsFolder = ReplicatedStorage:WaitForChild("GatewayToHellSignals")
local roundStartRequested = signalsFolder:WaitForChild("RoundStartRequested") :: BindableEvent
local puzzleProgressEvent = signalsFolder:WaitForChild("PuzzleProgress") :: BindableEvent
local puzzleSolvedEvent = signalsFolder:WaitForChild("PuzzleSolved") :: BindableEvent
local hideSpotRequested = signalsFolder:WaitForChild("HideSpotRequested") :: BindableEvent
local hideSpotReleased = signalsFolder:WaitForChild("HideSpotReleased") :: BindableEvent
local batteryPickupCollected = signalsFolder:WaitForChild("BatteryPickupCollected") :: BindableEvent
local secretObjectiveCompleted = signalsFolder:WaitForChild("SecretObjectiveCompleted") :: BindableEvent

local ROOT_NAME = "StoryMapGeometry"
local ORIGIN = GameConfig.STORY_REGION_ORIGIN
local STORY_KEY_COUNT = GameConfig.STORY_KEY_COUNT

local function ensureRoot()
	local existing = Workspace:FindFirstChild(ROOT_NAME)
	if existing then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = ROOT_NAME
	folder.Parent = Workspace
	return folder
end

local function createPart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material, anchored: boolean, canCollide: boolean, transparency: number?, castShadow: boolean?)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.Anchored = anchored
	part.CanCollide = canCollide
	part.CanQuery = canCollide
	part.CanTouch = canCollide
	part.CastShadow = if castShadow == nil then true else castShadow
	part.Transparency = transparency or 0
	part.Parent = parent
	return part
end

local function makeSign(part: BasePart, text: string, color: Color3, backgroundColor: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.PixelsPerStud = 50
	gui.Parent = part

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = backgroundColor
	frame.BackgroundTransparency = 0.08
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Transparency = 0.25
	stroke.Thickness = 1
	stroke.Parent = frame

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.TextWrapped = true
	label.TextDirection = Enum.TextDirection.RightToLeft
	label.Parent = frame

	return gui
end

local function makePrompt(part: BasePart, actionText: string, objectText: string, holdDuration: number)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = actionText
	prompt.ObjectText = objectText
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.HoldDuration = holdDuration or 0.2
	prompt.Parent = part
	return prompt
end

local function makeLantern(parent: Instance, position: Vector3)
	local body = createPart(parent, "Lantern", Vector3.new(0.45, 0.75, 0.45), CFrame.new(position), Color3.fromRGB(34, 22, 18), Enum.Material.Metal, true, false, 0, false)
	local glow = createPart(parent, "LanternGlow", Vector3.new(0.25, 0.35, 0.25), CFrame.new(position), Color3.fromRGB(255, 134, 72), Enum.Material.Neon, true, false, 0.15, false)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 144, 82)
	light.Brightness = 1.8
	light.Range = 16
	light.Shadows = true
	light.Parent = glow
	return body, glow
end

local puzzleProgress = {
	Keys = { Current = 0, Total = STORY_KEY_COUNT, State = "collect" },
	Symbols = { Current = 0, Total = #StoryPuzzles.Definitions.Symbols.Sequence, State = "enter" },
	Statues = { Current = 0, Total = #StoryPuzzles.Definitions.Statues.Targets, State = "align" },
	Candles = { Current = 0, Total = #StoryPuzzles.Definitions.Candles.Sequence, State = "ignite" },
	Sounds = { Current = 0, Total = #StoryPuzzles.Definitions.Sounds.Sequence, State = "listen" },
}

local controllers = {}

local function publishProgress(puzzleId: string, state: string?, current: number?, total: number?, solved: boolean?)
	local def = StoryPuzzles.getDefinition(puzzleId)
	if not def then
		return
	end

	local currentProgress = puzzleProgress[puzzleId]
	if not currentProgress then
		return
	end

	if current ~= nil then
		currentProgress.Current = current
	end
	if total ~= nil then
		currentProgress.Total = total
	end
	if state ~= nil then
		currentProgress.State = state
	end
	if solved ~= nil then
		currentProgress.Solved = solved
	else
		currentProgress.Solved = currentProgress.Solved or false
	end

	puzzleProgressEvent:Fire({
		PuzzleId = puzzleId,
		Label = def.Label,
		Current = currentProgress.Current,
		Total = currentProgress.Total,
		State = currentProgress.State,
		Solved = currentProgress.Solved == true,
	})
end

local function publishSolved(puzzleId: string, reason: string?)
	local def = StoryPuzzles.getDefinition(puzzleId)
	if not def then
		return
	end

	puzzleProgress[puzzleId].Current = puzzleProgress[puzzleId].Total
	puzzleProgress[puzzleId].State = "solved"
	puzzleProgress[puzzleId].Solved = true
	puzzleSolvedEvent:Fire({
		PuzzleId = puzzleId,
		Label = def.Label,
		Current = puzzleProgress[puzzleId].Total,
		Total = puzzleProgress[puzzleId].Total,
		State = reason or "solved",
		Solved = true,
	})
end

local function resetAllPuzzleState()
	for puzzleId, state in pairs(puzzleProgress) do
		state.Current = 0
		state.Solved = false
		if puzzleId == "Keys" then
			state.Total = STORY_KEY_COUNT
			state.State = "collect"
		elseif puzzleId == "Symbols" then
			state.Total = #StoryPuzzles.Definitions.Symbols.Sequence
			state.State = "enter"
		elseif puzzleId == "Statues" then
			state.Total = #StoryPuzzles.Definitions.Statues.Targets
			state.State = "align"
		elseif puzzleId == "Candles" then
			state.Total = #StoryPuzzles.Definitions.Candles.Sequence
			state.State = "ignite"
		elseif puzzleId == "Sounds" then
			state.Total = #StoryPuzzles.Definitions.Sounds.Sequence
			state.State = "listen"
		end
	end

	for puzzleId, controller in pairs(controllers) do
		if controller.Reset then
			controller.Reset()
		end
		publishProgress(puzzleId, puzzleProgress[puzzleId].State, 0, puzzleProgress[puzzleId].Total, false)
	end
end

local function addKey(parent: Instance, name: string, position: Vector3)
	local key = createPart(parent, name, Vector3.new(0.55, 0.18, 1.3), CFrame.new(position), Color3.fromRGB(255, 193, 79), Enum.Material.Neon, true, false, 0, false)
	key.Shape = Enum.PartType.Cylinder
	key.Orientation = Vector3.new(90, 0, 0)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 192, 88)
	light.Brightness = 1.1
	light.Range = 10
	light.Parent = key
	local prompt = makePrompt(key, "التقاط", "مفتاح", 0.2)
	return key, prompt
end

local function buildKeyPuzzle(root: Instance)
	local positions = {
		ORIGIN + Vector3.new(11.5, 1.4, -4.0),
		ORIGIN + Vector3.new(16.5, 1.4, 4.4),
		ORIGIN + Vector3.new(22.5, 1.4, -8.2),
		ORIGIN + Vector3.new(32.5, 1.4, 7.4),
		ORIGIN + Vector3.new(44.5, 1.4, -2.5),
	}

	local collected = 0
	for index, position in ipairs(positions) do
		local key, prompt = addKey(root, `StoryKey{index}`, position)
		prompt.Triggered:Connect(function(_player)
			if key:GetAttribute("Collected") then
				return
			end
			key:SetAttribute("Collected", true)
			key.Transparency = 1
			key.CanTouch = false
			key.CanCollide = false
			prompt.Enabled = false
			collected += 1
			publishProgress("Keys", "collect", collected, STORY_KEY_COUNT, false)
			if collected >= STORY_KEY_COUNT then
				publishSolved("Keys", "solved")
			end
		end)
	end

	controllers.Keys = {
		Reset = function()
			collected = 0
			for _, descendant in ipairs(root:GetChildren()) do
				if descendant:IsA("BasePart") and descendant.Name:match("^StoryKey") then
					descendant.Transparency = 0
					descendant.CanTouch = true
					descendant.CanCollide = false
					descendant:SetAttribute("Collected", false)
					local prompt = descendant:FindFirstChildOfClass("ProximityPrompt")
					if prompt then
						prompt.Enabled = true
					end
				end
			end
		end,
	}
end

local function createRoom(parent: Instance, name: string, center: Vector3, floorSize: Vector3, zHalfWidth: number)
	local floor = createPart(parent, name .. "Floor", floorSize, CFrame.new(center + Vector3.new(0, 0.15, 0)), Color3.fromRGB(47, 31, 25), Enum.Material.WoodPlanks, true, true, 0, true)
	floor.CastShadow = false
	createPart(parent, name .. "NorthWall", Vector3.new(floorSize.X, 12, 1), CFrame.new(center + Vector3.new(0, 6, zHalfWidth)), Color3.fromRGB(57, 49, 47), Enum.Material.Slate, true, true, 0, true)
	createPart(parent, name .. "SouthWall", Vector3.new(floorSize.X, 12, 1), CFrame.new(center + Vector3.new(0, 6, -zHalfWidth)), Color3.fromRGB(57, 49, 47), Enum.Material.Slate, true, true, 0, true)
	createPart(parent, name .. "Ceiling", Vector3.new(floorSize.X, 1, floorSize.Z), CFrame.new(center + Vector3.new(0, 12.5, 0)), Color3.fromRGB(28, 22, 24), Enum.Material.WoodPlanks, true, true, 0, true)
	return floor
end

local function buildSymbolsPuzzle(root: Instance)
	local roomCenter = ORIGIN + Vector3.new(18, 0, 11.5)
	createRoom(root, "SymbolsRoom", roomCenter, Vector3.new(18, 1, 12), 6)
	createPart(root, "SymbolsWestWall", Vector3.new(1, 12, 12), CFrame.new(roomCenter + Vector3.new(-9.5, 6, 0)), Color3.fromRGB(57, 49, 47), Enum.Material.Slate, true, true, 0, true)
	createPart(root, "SymbolsEastWall", Vector3.new(1, 12, 12), CFrame.new(roomCenter + Vector3.new(9.5, 6, 0)), Color3.fromRGB(57, 49, 47), Enum.Material.Slate, true, true, 0, true)
	local console = createPart(root, "SymbolsConsole", Vector3.new(3.8, 2.2, 1.1), CFrame.new(roomCenter + Vector3.new(0, 1.2, -2.6)), Color3.fromRGB(30, 18, 18), Enum.Material.Slate, true, true, 0, true)
	makeSign(console, "لوحة الرموز", Color3.fromRGB(255, 94, 60), Color3.fromRGB(42, 8, 8))

	local sequence = StoryPuzzles.Definitions.Symbols.Sequence
	local presses = 0
	local solved = false
	local plateSymbols = { "1", "2", "3", "4" }
	local platePositions = {
		roomCenter + Vector3.new(-4.0, 1.2, 2.6),
		roomCenter + Vector3.new(-1.0, 1.2, 3.4),
		roomCenter + Vector3.new(2.0, 1.2, 2.4),
		roomCenter + Vector3.new(5.0, 1.2, 3.0),
	}

	controllers.Symbols = {
		Reset = function()
			presses = 0
			solved = false
		end,
	}

	for index, position in ipairs(platePositions) do
		local plate = createPart(root, `SymbolPlate{index}`, Vector3.new(1.2, 1.2, 0.35), CFrame.new(position), Color3.fromRGB(104, 13, 13), Enum.Material.Neon, true, false, 0, false)
		makeSign(plate, plateSymbols[index], Color3.fromRGB(255, 78, 56), Color3.fromRGB(44, 5, 5))
		local prompt = makePrompt(plate, "أدخل", "رمز", 0.2)
		prompt.Triggered:Connect(function()
			if solved then
				return
			end
			local expected = sequence[presses + 1]
			if plateSymbols[index] == expected then
				presses += 1
				publishProgress("Symbols", `الرموز {presses}/{#sequence}`, presses, #sequence, false)
				if presses >= #sequence then
					solved = true
					publishSolved("Symbols", "solved")
				end
			else
				presses = 0
				publishProgress("Symbols", "إعادة ضبط", 0, #sequence, false)
			end
		end)
	end

	controllers.Symbols.Reset = function()
		presses = 0
		solved = false
	end
end

local function buildStatuesPuzzle(root: Instance)
	local roomCenter = ORIGIN + Vector3.new(30, 0, -11.5)
	createRoom(root, "StatuesRoom", roomCenter, Vector3.new(18, 1, 12), 6)
	createPart(root, "StatuesWestWall", Vector3.new(1, 12, 12), CFrame.new(roomCenter + Vector3.new(-9.5, 6, 0)), Color3.fromRGB(57, 49, 47), Enum.Material.Slate, true, true, 0, true)
	createPart(root, "StatuesEastWall", Vector3.new(1, 12, 12), CFrame.new(roomCenter + Vector3.new(9.5, 6, 0)), Color3.fromRGB(57, 49, 47), Enum.Material.Slate, true, true, 0, true)
	local targetDirections = StoryPuzzles.Definitions.Statues.Targets
	local statueStates = {}
	local statues = {}
	local correctCount = 0

	controllers.Statues = {
		Reset = function()
			statueStates = {}
			correctCount = 0
			for index, statue in ipairs(statues) do
				local position = statue.Position
				statue.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, 0)
				statueStates[index] = 1
			end
		end,
	}

	local facingAngles = { 0, 90, 180, 270 }
	for index, position in ipairs({
		roomCenter + Vector3.new(-4.5, 0.9, -1.8),
		roomCenter + Vector3.new(0, 0.9, 2.4),
		roomCenter + Vector3.new(4.5, 0.9, -1.8),
	}) do
		createPart(root, `StatueBase{index}`, Vector3.new(1.3, 0.8, 1.3), CFrame.new(position), Color3.fromRGB(40, 34, 34), Enum.Material.Slate, true, true, 0, true)
		local statue = createPart(root, `Statue{index}`, Vector3.new(1.6, 3.8, 1.6), CFrame.new(position + Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, math.rad(facingAngles[1]), 0), Color3.fromRGB(52, 44, 43), Enum.Material.Slate, true, true, 0, true)
		local prompt = makePrompt(statue, "لف", "تمثال", 0.2)
		statues[index] = statue
		statueStates[index] = 1
		prompt.Triggered:Connect(function()
			statueStates[index] = (statueStates[index] % #facingAngles) + 1
			statue.CFrame = CFrame.new(position + Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, math.rad(facingAngles[statueStates[index]]), 0)
			correctCount = 0
			for statueIndex, stateIndex in pairs(statueStates) do
				if facingAngles[stateIndex] == targetDirections[statueIndex] then
					correctCount += 1
				end
			end
			publishProgress("Statues", `المطابق {correctCount}/{#targetDirections}`, correctCount, #targetDirections, false)
			if correctCount >= #targetDirections then
				publishSolved("Statues", "solved")
			end
		end)
	end
end

local function buildCandlesPuzzle(root: Instance)
	local roomCenter = ORIGIN + Vector3.new(42, 0, 11.5)
	createRoom(root, "CandlesRoom", roomCenter, Vector3.new(18, 1, 12), 6)
	createPart(root, "CandlesWestWall", Vector3.new(1, 12, 12), CFrame.new(roomCenter + Vector3.new(-9.5, 6, 0)), Color3.fromRGB(57, 49, 47), Enum.Material.Slate, true, true, 0, true)
	createPart(root, "CandlesEastWall", Vector3.new(1, 12, 12), CFrame.new(roomCenter + Vector3.new(9.5, 6, 0)), Color3.fromRGB(57, 49, 47), Enum.Material.Slate, true, true, 0, true)
	local sequence = StoryPuzzles.Definitions.Candles.Sequence
	local candleStates = { false, false, false, false }
	local nextIndex = 1
	local solved = false
	local candlePositions = {
		roomCenter + Vector3.new(-5, 1.1, -1.8),
		roomCenter + Vector3.new(-1.8, 1.1, 1.5),
		roomCenter + Vector3.new(1.8, 1.1, -1.8),
		roomCenter + Vector3.new(5, 1.1, 1.5),
	}

	local function refreshCandles()
		for index, candle in ipairs(candleStates) do
			local part = root:FindFirstChild(`Candle{index}`)
			local flame = part and part:FindFirstChild(`CandleFlame`)
			local pointLight = flame and flame:FindFirstChildOfClass("PointLight")
			if part and part:IsA("BasePart") then
				part.Color = if candle then Color3.fromRGB(255, 200, 110) else Color3.fromRGB(75, 56, 48)
			end
			if flame and flame:IsA("BasePart") then
				flame.Transparency = if candle then 0 else 1
			end
			if pointLight then
				pointLight.Brightness = if candle then 1.6 else 0
			end
		end
	end

	controllers.Candles = {
		Reset = function()
			candleStates = { false, false, false, false }
			nextIndex = 1
			solved = false
			refreshCandles()
		end,
	}

	for index, position in ipairs(candlePositions) do
		local candle = createPart(root, `Candle{index}`, Vector3.new(0.5, 1.3, 0.5), CFrame.new(position), Color3.fromRGB(75, 56, 48), Enum.Material.SmoothPlastic, true, true, 0, true)
		local flame = createPart(candle, `CandleFlame`, Vector3.new(0.26, 0.45, 0.26), CFrame.new(position + Vector3.new(0, 1, 0)), Color3.fromRGB(255, 134, 72), Enum.Material.Neon, true, false, 1, false)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 144, 82)
		light.Brightness = 0.0
		light.Range = 12
		light.Parent = flame
		local prompt = makePrompt(candle, "أشعل", "شمعة", 0.15)
		prompt.Triggered:Connect(function()
			if solved then
				return
			end
			local expected = sequence[nextIndex]
			if index == expected then
				candleStates[index] = true
				nextIndex += 1
				refreshCandles()
				publishProgress("Candles", `الشموع {nextIndex - 1}/{#sequence}`, nextIndex - 1, #sequence, false)
				if nextIndex > #sequence then
					solved = true
					publishSolved("Candles", "solved")
				end
			else
				candleStates = { false, false, false, false }
				nextIndex = 1
				refreshCandles()
				publishProgress("Candles", "إعادة ضبط", 0, #sequence, false)
			end
		end)
	end

	controllers.Candles.Reset = function()
		candleStates = { false, false, false, false }
		nextIndex = 1
		solved = false
		refreshCandles()
	end

	refreshCandles()
end

local function buildSoundsPuzzle(root: Instance)
	local roomCenter = ORIGIN + Vector3.new(54, 0, -11.5)
	createRoom(root, "SoundsRoom", roomCenter, Vector3.new(18, 1, 12), 6)
	createPart(root, "SoundsWestWall", Vector3.new(1, 12, 12), CFrame.new(roomCenter + Vector3.new(-9.5, 6, 0)), Color3.fromRGB(57, 49, 47), Enum.Material.Slate, true, true, 0, true)
	createPart(root, "SoundsEastWall", Vector3.new(1, 12, 12), CFrame.new(roomCenter + Vector3.new(9.5, 6, 0)), Color3.fromRGB(57, 49, 47), Enum.Material.Slate, true, true, 0, true)

	local sequence = StoryPuzzles.Definitions.Sounds.Sequence
	local triggerIndex = 1
	local solved = false
	local previewToken = 0
	local padPositions = {
		roomCenter + Vector3.new(-5, 1.0, -2.0),
		roomCenter + Vector3.new(0, 1.0, 2.1),
		roomCenter + Vector3.new(5, 1.0, -2.0),
	}

	local function flashPad(index: number)
		local pad = root:FindFirstChild(`SoundPad{index}`)
		if pad and pad:IsA("BasePart") then
			pad.Color = Color3.fromRGB(84, 61, 77)
			task.delay(0.18, function()
				if pad.Parent then
					pad.Color = Color3.fromRGB(55, 33, 36)
				end
			end)
		end
	end

	controllers.Sounds = {
		Reset = function()
			triggerIndex = 1
			solved = false
			previewToken += 1
			local token = previewToken
			task.spawn(function()
				task.wait(0.8)
				for _, padIndex in ipairs(sequence) do
					if token ~= previewToken then
						return
					end
					if solved then
						return
					end
					flashPad(padIndex)
					task.wait(0.65)
				end
			end)
		end,
	}

	for index, position in ipairs(padPositions) do
		local pad = createPart(root, `SoundPad{index}`, Vector3.new(2.8, 0.45, 2.8), CFrame.new(position), Color3.fromRGB(55, 33, 36), Enum.Material.WoodPlanks, true, true, 0, true)
		local speaker = createPart(pad, `SoundSpeaker`, Vector3.new(1.1, 1.1, 1.1), CFrame.new(position + Vector3.new(0, 0.75, 0)), Color3.fromRGB(104, 64, 48), Enum.Material.Metal, true, false, 0, false)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 93, 61)
		light.Brightness = 0.9
		light.Range = 10
		light.Parent = speaker
		local prompt = makePrompt(pad, "استمع", "صدى", 0.15)
		prompt.Triggered:Connect(function()
			if solved then
				return
			end
			local expected = sequence[triggerIndex]
			if index == expected then
				triggerIndex += 1
				flashPad(index)
				publishProgress("Sounds", `الأصوات {triggerIndex - 1}/{#sequence}`, triggerIndex - 1, #sequence, false)
				if triggerIndex > #sequence then
					solved = true
					publishSolved("Sounds", "solved")
				end
			else
				triggerIndex = 1
				publishProgress("Sounds", "إعادة ضبط", 0, #sequence, false)
			end
		end)
	end

	controllers.Sounds.Reset = function()
		triggerIndex = 1
		solved = false
	end
end

local function buildImmersionSystems(root: Instance)
	local hideSpotStates = {}
	local hideSpotStatesById = {}
	local batteryStates = {}

	local function setHidePrompt(state, occupied)
		state.Prompt.ActionText = if occupied then "خروج" else "اختباء"
		state.Prompt.ObjectText = state.Label
	end

	local function resetHideSpot(state)
		state.occupiedUserId = nil
		state.blocked = false
		setHidePrompt(state, false)
	end

	local function makeHideSpot(name, label, position, size)
		local folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = root

		local base = createPart(folder, `${name}Base`, size, CFrame.new(position), Color3.fromRGB(59, 44, 40), Enum.Material.WoodPlanks, true, true, 0, true)
		createPart(folder, `${name}Cover`, Vector3.new(size.X * 0.92, size.Y * 0.85, size.Z * 0.18), CFrame.new(position + Vector3.new(0, size.Y * 0.05, size.Z * 0.48)), Color3.fromRGB(33, 24, 27), Enum.Material.Wood, true, true, 0, true)
		local prompt = makePrompt(base, "اختباء", label, 0.3)
		local state = {
			Id = name,
			Label = label,
			Prompt = prompt,
			occupiedUserId = nil,
			blocked = false,
		}
		setHidePrompt(state, false)

		prompt.Triggered:Connect(function(player)
			if state.blocked then
				return
			end

			if state.occupiedUserId == player.UserId then
				hideSpotRequested:Fire({
					Player = player,
					Hidden = false,
					SpotId = state.Id,
					SpotLabel = state.Label,
				})
				resetHideSpot(state)
				return
			end

			if state.occupiedUserId and state.occupiedUserId ~= player.UserId then
				return
			end

			state.occupiedUserId = player.UserId
			setHidePrompt(state, true)
			hideSpotRequested:Fire({
				Player = player,
				Hidden = true,
				SpotId = state.Id,
				SpotLabel = state.Label,
			})
		end)

		hideSpotStates[#hideSpotStates + 1] = state
		hideSpotStatesById[state.Id] = state
	end

	local function makeBattery(name, position)
		local battery = createPart(root, name, Vector3.new(0.6, 0.9, 0.6), CFrame.new(position), Color3.fromRGB(255, 193, 79), Enum.Material.Neon, true, false, 0, false)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 193, 79)
		light.Brightness = 0.7
		light.Range = 8
		light.Parent = battery
		local prompt = makePrompt(battery, "التقاط", "بطارية", 0.25)
		local state = {
			Id = name,
			Part = battery,
			Prompt = prompt,
			Collected = false,
		}

		prompt.Triggered:Connect(function(player)
			if state.Collected then
				return
			end

			state.Collected = true
			batteryPickupCollected:Fire({
				Player = player,
				PickupId = state.Id,
			})
			battery.Transparency = 1
			battery.CanTouch = false
			battery.CanCollide = false
			prompt.Enabled = false
		end)

		batteryStates[#batteryStates + 1] = state
	end

	local function makeProbe(name, position)
		createPart(root, name, Vector3.new(1.4, 1.4, 1.4), CFrame.new(position), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, true, false, 1, false)
	end

	makeHideSpot("HideLockerA", "خزانة", ORIGIN + Vector3.new(17, 1.2, -8.2), Vector3.new(4.2, 4.2, 2.4))
	makeHideSpot("HideClosetB", "خزانة", ORIGIN + Vector3.new(31, 1.2, 8.2), Vector3.new(4.6, 4.4, 2.4))
	makeHideSpot("HideTableC", "تحت الطاولة", ORIGIN + Vector3.new(44, 1.1, -7.5), Vector3.new(4.8, 2.8, 2.6))
	makeHideSpot("HideCrateD", "صندوق", ORIGIN + Vector3.new(54, 1.0, 7.4), Vector3.new(3.6, 3.0, 3.0))

	makeBattery("BatteryPickupA", ORIGIN + Vector3.new(12, 1.2, 6.0))
	makeBattery("BatteryPickupB", ORIGIN + Vector3.new(26, 1.2, -5.4))
	makeBattery("BatteryPickupC", ORIGIN + Vector3.new(39, 1.2, 5.2))
	makeBattery("BatteryPickupD", ORIGIN + Vector3.new(58, 1.2, -3.8))

	for _, point in ipairs({
		ORIGIN + Vector3.new(6, 1.2, 0),
		ORIGIN + Vector3.new(18, 1.2, 0),
		ORIGIN + Vector3.new(24, 1.2, 8.4),
		ORIGIN + Vector3.new(34, 1.2, -8.4),
		ORIGIN + Vector3.new(46, 1.2, 0),
		ORIGIN + Vector3.new(58, 1.2, 0),
	}) do
		makeProbe("StoryLightProbe", point)
	end

	controllers.HideSpots = {
		Reset = function()
			for _, state in ipairs(hideSpotStates) do
				resetHideSpot(state)
			end
		end,
	}

	controllers.Batteries = {
		Reset = function()
			for _, state in ipairs(batteryStates) do
				state.Collected = false
				state.Part.Transparency = 0
				state.Part.CanTouch = true
				state.Part.CanCollide = false
				state.Prompt.Enabled = true
			end
		end,
	}

	hideSpotReleased.Event:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end

		local state = nil
		if type(payload.SpotId) == "string" then
			state = hideSpotStatesById[payload.SpotId]
		end

		if not state and typeof(payload.Player) == "Instance" and payload.Player:IsA("Player") then
			for _, candidate in ipairs(hideSpotStates) do
				if candidate.occupiedUserId == payload.Player.UserId then
					state = candidate
					break
				end
			end
		end

		if state then
			resetHideSpot(state)
		end
	end)
end

local function buildSecretObjective(root: Instance)
	local chamber = Instance.new("Folder")
	chamber.Name = "SecretRitualChamber"
	chamber.Parent = root

	createPart(chamber, "SecretFloor", Vector3.new(10, 1, 10), CFrame.new(ORIGIN + Vector3.new(24, 1.0, 14.8)), Color3.fromRGB(36, 20, 20), Enum.Material.Slate, true, true, 0, true)
	createPart(chamber, "SecretWallA", Vector3.new(0.8, 8, 10), CFrame.new(ORIGIN + Vector3.new(19.8, 5, 14.8)), Color3.fromRGB(28, 18, 18), Enum.Material.Slate, true, true, 0, true)
	createPart(chamber, "SecretWallB", Vector3.new(8.8, 8, 0.8), CFrame.new(ORIGIN + Vector3.new(24, 5, 19.0)), Color3.fromRGB(28, 18, 18), Enum.Material.Slate, true, true, 0, true)
	createPart(chamber, "SecretWallC", Vector3.new(8.8, 8, 0.8), CFrame.new(ORIGIN + Vector3.new(24, 5, 10.6)), Color3.fromRGB(28, 18, 18), Enum.Material.Slate, true, true, 0, true)
	local sigil = createPart(chamber, "SecretSigil", Vector3.new(2.2, 0.3, 2.2), CFrame.new(ORIGIN + Vector3.new(24, 1.55, 14.8)), Color3.fromRGB(113, 14, 16), Enum.Material.Neon, true, false, 0, false)
	local sigilLight = Instance.new("PointLight")
	sigilLight.Color = Color3.fromRGB(255, 82, 35)
	sigilLight.Brightness = 0.8
	sigilLight.Range = 10
	sigilLight.Parent = sigil
	local prompt = makePrompt(sigil, "كشف السر", "طقس البوابة", 1)
	local solved = false

	prompt.Triggered:Connect(function(player)
		if solved then
			return
		end

		solved = true
		prompt.Enabled = false
		secretObjectiveCompleted:Fire({
			Player = player,
			ObjectiveId = GameConfig.SECRET_OBJECTIVE_ID,
		})
	end)

	controllers.SecretObjective = {
		Reset = function()
			solved = false
			prompt.Enabled = true
		end,
	}
end

local function buildLobbyGeometry(root: Instance)
	local floorColor = Color3.fromRGB(47, 31, 25)
	local wallColor = Color3.fromRGB(57, 49, 47)
	local trimColor = Color3.fromRGB(71, 60, 55)
	local darkColor = Color3.fromRGB(25, 18, 20)

	local corridorSegments = {
		{ name = "EntranceFloor", center = ORIGIN + Vector3.new(6, 0.15, 0), size = Vector3.new(16, 1, 18) },
		{ name = "CorridorFloor", center = ORIGIN + Vector3.new(24, 0.15, 0), size = Vector3.new(22, 1, 10) },
		{ name = "CenterFloor", center = ORIGIN + Vector3.new(40, 0.15, 0), size = Vector3.new(20, 1, 16) },
		{ name = "ExitFloor", center = ORIGIN + Vector3.new(56, 0.15, 0), size = Vector3.new(16, 1, 18) },
	}

	for _, segment in ipairs(corridorSegments) do
		local floor = createPart(root, segment.name, segment.size, CFrame.new(segment.center), floorColor, Enum.Material.WoodPlanks, true, true, 0, true)
		floor.CastShadow = false
	end

	for _, wall in ipairs({
		{ "LeftWall", ORIGIN + Vector3.new(28, 6, -9.5), Vector3.new(70, 12, 1.2) },
		{ "RightWall", ORIGIN + Vector3.new(28, 6, 9.5), Vector3.new(70, 12, 1.2) },
		{ "BackWall", ORIGIN + Vector3.new(-2, 6, 0), Vector3.new(1.2, 12, 20) },
		{ "FarWall", ORIGIN + Vector3.new(64.5, 6, 0), Vector3.new(1.2, 12, 20) },
	}) do
		createPart(root, wall[1], wall[3], CFrame.new(wall[2]), wallColor, Enum.Material.Slate, true, true, 0, true)
	end

	for _, x in ipairs({ 2, 10, 18, 26, 34, 42, 50, 58 }) do
		createPart(root, `CeilingBeam{x}`, Vector3.new(0.5, 10.8, 0.5), CFrame.new(ORIGIN + Vector3.new(x, 10.8, 0)), trimColor, Enum.Material.Wood, true, true, 0, false)
	end
	createPart(root, "CeilingCenter", Vector3.new(68, 1, 18), CFrame.new(ORIGIN + Vector3.new(32, 12.5, 0)), darkColor, Enum.Material.WoodPlanks, true, true, 0, true)

	for _, position in ipairs({
		ORIGIN + Vector3.new(3, 9.6, -7.2),
		ORIGIN + Vector3.new(12, 9.6, 7.2),
		ORIGIN + Vector3.new(20, 9.6, -7.2),
		ORIGIN + Vector3.new(29, 9.6, 7.2),
		ORIGIN + Vector3.new(38, 9.6, -7.2),
		ORIGIN + Vector3.new(47, 9.6, 7.2),
		ORIGIN + Vector3.new(56, 9.6, -7.2),
	}) do
		makeLantern(root, position)
	end

	local entranceSpawn = createPart(root, "StoryEntranceSpawn", Vector3.new(8, 1, 8), CFrame.new(ORIGIN + Vector3.new(2, 2.5, 0)), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, true, false, 1, false)
	entranceSpawn.CanTouch = false
	entranceSpawn.CanQuery = false

	createPart(root, "StoryExitGateLeft", Vector3.new(1.1, 11, 1.2), CFrame.new(ORIGIN + Vector3.new(61.3, 5.8, -3.8)), trimColor, Enum.Material.Slate, true, true, 0, true)
	createPart(root, "StoryExitGateRight", Vector3.new(1.1, 11, 1.2), CFrame.new(ORIGIN + Vector3.new(61.3, 5.8, 3.8)), trimColor, Enum.Material.Slate, true, true, 0, true)
	createPart(root, "StoryExitGateLintel", Vector3.new(8.8, 1.5, 1.2), CFrame.new(ORIGIN + Vector3.new(61.3, 11.3, 0)), trimColor, Enum.Material.Slate, true, true, 0, true)
	createPart(root, "StoryExitGate", Vector3.new(6.7, 9.6, 0.8), CFrame.new(ORIGIN + Vector3.new(61.3, 5.1, 0)), darkColor, Enum.Material.Slate, true, true, 0, true)
	local exitGlow = createPart(root, "StoryExitGateGlow", Vector3.new(6.0, 8.5, 0.2), CFrame.new(ORIGIN + Vector3.new(61.3, 5.1, -0.55)), Color3.fromRGB(255, 117, 56), Enum.Material.Neon, true, false, 0.1, false)
	local exitTrigger = createPart(root, "StoryExitTrigger", Vector3.new(6.0, 10, 4), CFrame.new(ORIGIN + Vector3.new(64.2, 5.2, 0)), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, true, false, 1, false)
	exitTrigger.CanTouch = true
	exitTrigger.CanQuery = false
	local exitLight = Instance.new("PointLight")
	exitLight.Color = Color3.fromRGB(255, 122, 63)
	exitLight.Brightness = 2.2
	exitLight.Range = 20
	exitLight.Shadows = true
	exitLight.Parent = exitGlow

	local titlePlate = createPart(root, "StoryTitlePlate", Vector3.new(9, 1, 0.5), CFrame.new(ORIGIN + Vector3.new(32, 14, 0)), Color3.fromRGB(118, 16, 18), Enum.Material.Neon, true, false, 0, false)
	makeSign(titlePlate, "بوابة الجحيم", Color3.fromRGB(255, 100, 75), Color3.fromRGB(42, 8, 8))

	local leaderboardMount = createPart(root, "StoryLeaderboardMount", Vector3.new(10, 7.8, 0.8), CFrame.new(ORIGIN + Vector3.new(22, 8.4, 11.2)), Color3.fromRGB(34, 20, 20), Enum.Material.Wood, true, true, 0, true)
	makeSign(leaderboardMount, "المتصدرون", Color3.fromRGB(255, 140, 77), Color3.fromRGB(22, 12, 14))
	local shopSign = createPart(root, "StoryShopSign", Vector3.new(6.5, 0.9, 0.4), CFrame.new(ORIGIN + Vector3.new(33, 8.4, -11.2)), Color3.fromRGB(100, 60, 30), Enum.Material.Wood, true, true, 0, true)
	makeSign(shopSign, "Shop", Color3.fromRGB(255, 198, 120), Color3.fromRGB(34, 22, 10))
	local exitSignA = createPart(root, "StoryExitSignA", Vector3.new(3.6, 1.0, 0.3), CFrame.new(ORIGIN + Vector3.new(52.0, 7.0, 7.6)), Color3.fromRGB(113, 14, 16), Enum.Material.Neon, true, false, 0, false)
	makeSign(exitSignA, "EXIT", Color3.fromRGB(255, 78, 56), Color3.fromRGB(44, 5, 5))
	local exitSignB = createPart(root, "StoryExitSignB", Vector3.new(3.6, 1.0, 0.3), CFrame.new(ORIGIN + Vector3.new(40.0, 7.0, -7.6)) * CFrame.Angles(0, math.rad(180), 0), Color3.fromRGB(113, 14, 16), Enum.Material.Neon, true, false, 0, false)
	makeSign(exitSignB, "EXIT", Color3.fromRGB(255, 78, 56), Color3.fromRGB(44, 5, 5))
	local horrorSign = createPart(root, "HorrorStoriesSign", Vector3.new(6, 0.9, 0.35), CFrame.new(ORIGIN + Vector3.new(8, 8.0, -11.2)), Color3.fromRGB(104, 13, 13), Enum.Material.Neon, true, false, 0, false)
	makeSign(horrorSign, "قصص مرعبه", Color3.fromRGB(255, 74, 44), Color3.fromRGB(45, 5, 5))

	createPart(root, "DemonTorso", Vector3.new(7, 4.2, 8.2), CFrame.new(ORIGIN + Vector3.new(63.8, 6.2, 0)), Color3.fromRGB(18, 15, 18), Enum.Material.Slate, true, false, 0, true)
	createPart(root, "DemonChest", Vector3.new(5.2, 3.4, 3.8), CFrame.new(ORIGIN + Vector3.new(62.6, 7.3, 0)), Color3.fromRGB(18, 15, 18), Enum.Material.Slate, true, false, 0, true)
	createPart(root, "DemonHead", Vector3.new(3.5, 3.2, 3.4), CFrame.new(ORIGIN + Vector3.new(63.6, 11.6, 0)), Color3.fromRGB(18, 15, 18), Enum.Material.Slate, true, false, 0, true)
	createPart(root, "DemonHornL", Vector3.new(1.0, 4.2, 1.0), CFrame.new(ORIGIN + Vector3.new(62.8, 14.5, -1.1)) * CFrame.Angles(0, 0, math.rad(-26)), Color3.fromRGB(18, 15, 18), Enum.Material.Slate, true, false, 0, true)
	createPart(root, "DemonHornR", Vector3.new(1.0, 4.2, 1.0), CFrame.new(ORIGIN + Vector3.new(62.8, 14.5, 1.1)) * CFrame.Angles(0, 0, math.rad(26)), Color3.fromRGB(18, 15, 18), Enum.Material.Slate, true, false, 0, true)
	createPart(root, "DemonEyeL", Vector3.new(0.28, 0.28, 0.28), CFrame.new(ORIGIN + Vector3.new(62.1, 11.6, -0.8)), Color3.fromRGB(255, 45, 15), Enum.Material.Neon, true, false, 0, false)
	createPart(root, "DemonEyeR", Vector3.new(0.28, 0.28, 0.28), CFrame.new(ORIGIN + Vector3.new(62.1, 11.6, 0.8)), Color3.fromRGB(255, 45, 15), Enum.Material.Neon, true, false, 0, false)
	local halo = createPart(root, "DemonHalo", Vector3.new(6.5, 7.5, 0.1), CFrame.new(ORIGIN + Vector3.new(61.0, 7.7, 0)), Color3.fromRGB(255, 90, 32), Enum.Material.Neon, true, false, 0.7, false)
	local haloLight = Instance.new("PointLight")
	haloLight.Color = Color3.fromRGB(255, 82, 35)
	haloLight.Brightness = 1.8
	haloLight.Range = 18
	haloLight.Shadows = true
	haloLight.Parent = halo

	for _, point in ipairs({
		ORIGIN + Vector3.new(18, 1.6, 2.2),
		ORIGIN + Vector3.new(28, 1.6, -3.2),
		ORIGIN + Vector3.new(38, 1.6, 4.4),
		ORIGIN + Vector3.new(48, 1.6, -5.0),
		ORIGIN + Vector3.new(58, 1.6, 2.5),
	}) do
		createPart(root, "DebrisPlank", Vector3.new(3.5, 0.3, 0.35), CFrame.new(point) * CFrame.Angles(math.rad(15), math.rad(12), math.rad(-10)), Color3.fromRGB(62, 40, 27), Enum.Material.WoodPlanks, true, false, 0, false)
	end

	for _, point in ipairs({
		ORIGIN + Vector3.new(14, 1.8, 6.5),
		ORIGIN + Vector3.new(30, 1.8, -6.0),
		ORIGIN + Vector3.new(46, 1.8, 6.0),
	}) do
		createPart(root, "TombCross", Vector3.new(0.7, 3.4, 0.7), CFrame.new(point), Color3.fromRGB(40, 37, 39), Enum.Material.Slate, true, false, 0, true)
		createPart(root, "TombCrossBar", Vector3.new(1.9, 0.45, 0.45), CFrame.new(point + Vector3.new(0, 1.0, 0)), Color3.fromRGB(40, 37, 39), Enum.Material.Slate, true, false, 0, true)
	end

	local waypointFolder = Instance.new("Folder")
	waypointFolder.Name = "MonsterWaypoints"
	waypointFolder.Parent = root
	for index, point in ipairs({
		ORIGIN + Vector3.new(6, 1.5, 0),
		ORIGIN + Vector3.new(18, 1.5, 0),
		ORIGIN + Vector3.new(24, 1.5, 10.5),
		ORIGIN + Vector3.new(30, 1.5, -10.5),
		ORIGIN + Vector3.new(40, 1.5, 0),
		ORIGIN + Vector3.new(52, 1.5, 0),
		ORIGIN + Vector3.new(61.5, 1.5, 0),
	}) do
		createPart(waypointFolder, `Waypoint{index}`, Vector3.new(1, 1, 1), CFrame.new(point), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, true, false, 1, false)
	end

	local monsterPortal = createPart(root, "MonsterSpawnPortal", Vector3.new(7, 11, 1), CFrame.new(ORIGIN + Vector3.new(70, 5.5, 0)), Color3.fromRGB(22, 12, 14), Enum.Material.Slate, true, true, 0, true)
	makeSign(monsterPortal, "حارس الجحيم", Color3.fromRGB(255, 84, 44), Color3.fromRGB(34, 6, 8))
	local monsterSpawnPoint = createPart(root, "MonsterSpawnPoint", Vector3.new(3, 1, 3), CFrame.new(ORIGIN + Vector3.new(72, 1.2, 0)), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, true, false, 1, false)
	monsterSpawnPoint.CanTouch = false
	monsterSpawnPoint.CanQuery = false
	local spectatorSpawn = createPart(root, "StorySpectatorSpawn", Vector3.new(6, 1, 6), CFrame.new(ORIGIN + Vector3.new(10, 18, 0)), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, true, false, 1, false)
	spectatorSpawn.CanTouch = false
	spectatorSpawn.CanQuery = false
end

local function buildMap()
	local root = ensureRoot()
	buildLobbyGeometry(root)
	buildImmersionSystems(root)
	buildSecretObjective(root)
	buildKeyPuzzle(root)
	buildSymbolsPuzzle(root)
	buildStatuesPuzzle(root)
	buildCandlesPuzzle(root)
	buildSoundsPuzzle(root)
	resetAllPuzzleState()

	roundStartRequested.Event:Connect(function()
		resetAllPuzzleState()
	end)
end

buildMap()
