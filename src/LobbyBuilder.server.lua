local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local InsertService = game:GetService("InsertService")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local REMOTES_FOLDER_NAME = "GatewayToHellRemotes"
local REMOTE_NAMES = {
    "GameReady",
    "OpenMatchmakingChoice",
    "SubmitMatchmakingChoice",
    "QueueCountdown",
    "TeleportAnnounced",
    "RoundStateUpdated",
    "RoundOutcome",
    "ToggleFlashlightRequest",
    "AchievementUnlocked",
}
local SIGNAL_NAMES = {
    "RoundStartRequested",
    "PuzzleProgress",
    "PuzzleSolved",
    "HuntStartRequested",
    "HuntStopRequested",
    "MonsterCaughtPlayer",
    "MonsterStateUpdated",
    "HideSpotRequested",
    "HideSpotReleased",
    "BatteryPickupCollected",
    "SecretObjectiveCompleted",
    "RoundOutcomeResolved",
}

local function ensureChild(parent: Instance, className: string, name: string)
    local existing = parent:FindFirstChild(name)
    if existing then
        return existing
    end

    local instance = Instance.new(className)
    instance.Name = name
    instance.Parent = parent
    return instance
end

local function ensureRemoteFolder()
    local folder = ensureChild(ReplicatedStorage, "Folder", REMOTES_FOLDER_NAME)

    for _, remoteName in ipairs(REMOTE_NAMES) do
        ensureChild(folder, "RemoteEvent", remoteName)
    end

    return folder
end

local function ensureSignalFolder()
    local folder = ensureChild(ReplicatedStorage, "Folder", "GatewayToHellSignals")

    for _, signalName in ipairs(SIGNAL_NAMES) do
        ensureChild(folder, "BindableEvent", signalName)
    end

    return folder
end

local function loadAsset(assetId: number)
    if assetId <= 0 then
        return nil
    end

    local success, result = pcall(function()
        return InsertService:LoadAsset(assetId)
    end)

    if not success then
        warn(`Gateway to Hell asset load failed for {assetId}: {result}`)
        return nil
    end

    return result
end

local function ensureAnchor(name: string, size: Vector3, cframe: CFrame, color: Color3)
    local existing = Workspace:FindFirstChild(name)
    if existing and existing:IsA("BasePart") then
        return existing
    end

    local part = Instance.new("Part")
    part.Name = name
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.CastShadow = false
    part.Transparency = 1
    part.Size = size
    part.CFrame = cframe
    part.Color = color
    part.Parent = Workspace

    return part
end

local function attachFlickerLight(part: BasePart, lightColor: Color3)
    local light = Instance.new("PointLight")
    light.Color = lightColor
    light.Range = 14
    light.Brightness = 1
    light.Shadows = true
    light.Parent = part

    task.spawn(function()
        local baseBrightness = light.Brightness
        while light.Parent do
            light.Brightness = baseBrightness * (0.55 + math.random() * 0.55)
            task.wait(0.15 + math.random() * 0.22)
        end
    end)
end

local function createPart(
    name: string,
    size: Vector3,
    cframe: CFrame,
    color: Color3,
    material: Enum.Material,
    parent: Instance,
    anchored: boolean,
    canCollide: boolean,
    transparency: number?,
    castShadow: boolean?
)
    local part = Instance.new("Part")
    part.Name = name
    part.Anchored = anchored
    part.CanCollide = canCollide
    part.CanQuery = canCollide
    part.CanTouch = canCollide
    part.CastShadow = if castShadow == nil then true else castShadow
    part.Size = size
    part.CFrame = cframe
    part.Color = color
    part.Material = material
    part.Transparency = transparency or 0
    part.Parent = parent
    return part
end

local function createSignSurface(part: BasePart, text: string, textColor: Color3, backgroundColor: Color3, textSize: number?)
    local surfaceGui = Instance.new("SurfaceGui")
    surfaceGui.Name = `{part.Name}Surface`
    surfaceGui.Face = Enum.NormalId.Front
    surfaceGui.LightInfluence = 0
    surfaceGui.AlwaysOnTop = false
    surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
    surfaceGui.PixelsPerStud = 50
    surfaceGui.Parent = part

    local frame = Instance.new("Frame")
    frame.Size = UDim2.fromScale(1, 1)
    frame.BackgroundColor3 = backgroundColor
    frame.BackgroundTransparency = 0.05
    frame.BorderSizePixel = 0
    frame.Parent = surfaceGui

    local stroke = Instance.new("UIStroke")
    stroke.Color = textColor
    stroke.Transparency = 0.2
    stroke.Thickness = 1
    stroke.Parent = frame

    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Size = UDim2.fromScale(1, 1)
    label.Text = text
    label.Font = Enum.Font.GothamBlack
    label.TextColor3 = textColor
    label.TextScaled = true
    label.TextWrapped = true
    label.RichText = false
    label.TextXAlignment = Enum.TextXAlignment.Center
    label.TextYAlignment = Enum.TextYAlignment.Center
    label.TextDirection = Enum.TextDirection.RightToLeft
    label.Parent = frame

    if textSize then
        label.TextSize = textSize
    end

    return surfaceGui
end

local function createLantern(parent: Instance, cframe: CFrame)
    local body = createPart(
        "Lantern",
        Vector3.new(0.55, 0.85, 0.55),
        cframe,
        Color3.fromRGB(28, 20, 18),
        Enum.Material.Metal,
        parent,
        true,
        false,
        0,
        false
    )
    body.Shape = Enum.PartType.Block
    attachFlickerLight(body, Color3.fromRGB(255, 138, 72))

    local glass = createPart(
        "LanternGlow",
        Vector3.new(0.38, 0.46, 0.38),
        cframe * CFrame.new(0, -0.02, 0),
        Color3.fromRGB(255, 120, 58),
        Enum.Material.Neon,
        parent,
        true,
        false,
        0.1,
        false
    )
    glass.Shape = Enum.PartType.Block
    return body, glass
end

local function addFloorPlanks(parent: Instance, hallLength: number, hallWidth: number)
    local plankCount = 18
    local plankWidth = hallWidth / plankCount
    local floorMaterial = Enum.Material.WoodPlanks

    for index = 1, plankCount do
        local zOffset = -hallWidth / 2 + plankWidth / 2 + (index - 1) * plankWidth
        local plank = createPart(
            `FloorPlank{index}`,
            Vector3.new(hallLength, plankWidth * 0.92, 0.25),
            CFrame.new(0, 0.12, zOffset) * CFrame.Angles(0, math.rad(90), 0),
            Color3.fromRGB(44, 29, 23),
            floorMaterial,
            parent,
            true,
            true,
            0,
            true
        )
        plank.Reflectance = 0
        plank.CastShadow = false
    end

    for _, x in ipairs({-12, -2, 8, 18, 28, 38}) do
        local stain = createPart(
            `BloodStain{x}`,
            Vector3.new(4.5, 0.08, 2.2),
            CFrame.new(x, 0.19, math.random(-4, 4)),
            Color3.fromRGB(74, 14, 14),
            Enum.Material.SmoothPlastic,
            parent,
            true,
            false,
            0.28,
            false
        )
        stain.CastShadow = false
    end
end

local function addWall(parent: Instance, cframe: CFrame, size: Vector3)
    return createPart(
        "Wall",
        size,
        cframe,
        Color3.fromRGB(47, 39, 36),
        Enum.Material.Slate,
        parent,
        true,
        true,
        0,
        true
    )
end

local function addCeiling(parent: Instance, hallLength: number, hallWidth: number, hallHeight: number)
    local ceiling = createPart(
        "Ceiling",
        Vector3.new(hallLength, hallWidth, 1),
        CFrame.new(0, hallHeight, 0),
        Color3.fromRGB(33, 26, 24),
        Enum.Material.WoodPlanks,
        parent,
        true,
        true,
        0,
        true
    )
    ceiling.CastShadow = false

    for _, x in ipairs({-28, -14, 0, 14, 28, 42}) do
        local beam = createPart(
            `CeilingBeam{x}`,
            Vector3.new(0.45, hallWidth - 3, 0.45),
            CFrame.new(x, hallHeight - 0.35, 0) * CFrame.Angles(0, 0, math.rad(90)),
            Color3.fromRGB(39, 24, 18),
            Enum.Material.Wood,
            parent,
            true,
            true,
            0,
            true
        )
        beam.CastShadow = false
    end
end

local function addSideColumns(parent: Instance, hallLength: number, hallWidth: number, hallHeight: number)
    for _, zSide in ipairs({-1, 1}) do
        for _, x in ipairs({-30, -12, 6, 24, 42}) do
            local column = createPart(
                `Column{x}_{zSide}`,
                Vector3.new(1.5, 1.5, hallHeight),
                CFrame.new(x, hallHeight / 2, zSide * (hallWidth / 2 - 1.25)),
                Color3.fromRGB(64, 52, 47),
                Enum.Material.Slate,
                parent,
                true,
                true,
                0,
                true
            )
            column.Shape = Enum.PartType.Block

            local cap = createPart(
                `ColumnCap{x}_{zSide}`,
                Vector3.new(2.1, 2.1, 0.7),
                CFrame.new(x, hallHeight - 0.2, zSide * (hallWidth / 2 - 1.25)),
                Color3.fromRGB(72, 58, 52),
                Enum.Material.Slate,
                parent,
                true,
                true,
                0,
                true
            )
            cap.CastShadow = false
        end
    end
end

local function addBalcony(parent: Instance, hallLength: number, hallWidth: number, hallHeight: number)
    local balconyY = 8.5
    local deckDepth = 3.8
    local railHeight = 2.4
    local sideOffset = hallWidth / 2 - 3.0

    for _, zSide in ipairs({-1, 1}) do
        local deck = createPart(
            `BalconyDeck{zSide}`,
            Vector3.new(hallLength - 6, deckDepth, 1),
            CFrame.new(20, balconyY, zSide * sideOffset),
            Color3.fromRGB(62, 40, 28),
            Enum.Material.WoodPlanks,
            parent,
            true,
            true,
            0,
            true
        )
        deck.CastShadow = true

        local railTop = createPart(
            `BalconyRailTop{zSide}`,
            Vector3.new(hallLength - 6, 0.35, 0.35),
            CFrame.new(20, balconyY + railHeight, zSide * sideOffset),
            Color3.fromRGB(75, 47, 31),
            Enum.Material.Wood,
            parent,
            true,
            true,
            0,
            true
        )
        railTop.CastShadow = false

        for _, x in ipairs({-32, -22, -12, -2, 8, 18, 28, 38, 48}) do
            local post = createPart(
                `RailPost{x}_{zSide}`,
                Vector3.new(0.24, 0.24, railHeight),
                CFrame.new(x, balconyY + railHeight / 2, zSide * (sideOffset + 0.95)),
                Color3.fromRGB(80, 51, 34),
                Enum.Material.Wood,
                parent,
                true,
                true,
                0,
                true
            )
            post.CastShadow = false
        end

        for _, x in ipairs({-25, 0, 25, 42}) do
            local beam = createPart(
                `BalconySupport{x}_{zSide}`,
                Vector3.new(1.0, 1.0, 5.0),
                CFrame.new(x, 4.1, zSide * (sideOffset + 0.4)),
                Color3.fromRGB(43, 26, 18),
                Enum.Material.Wood,
                parent,
                true,
                true,
                0,
                true
            )
            beam.CastShadow = false
        end
    end
end

local function addStairs(parent: Instance, hallHeight: number, zSide: number)
    local baseX = -22
    for step = 1, 5 do
        local stepPart = createPart(
            `StairStep{step}_{zSide}`,
            Vector3.new(2.6, 1.0, 0.55),
            CFrame.new(baseX + step * 2.4, step * 1.4, zSide * 17.3) * CFrame.Angles(0, 0, math.rad(14 * zSide)),
            Color3.fromRGB(56, 36, 25),
            Enum.Material.WoodPlanks,
            parent,
            true,
            true,
            0,
            true
        )
        stepPart.CastShadow = false
    end
end

local function addArchway(parent: Instance)
    local archBaseX = 38
    local archZ = 0
    local stoneColor = Color3.fromRGB(61, 50, 45)
    local darkStone = Color3.fromRGB(38, 31, 31)

    createPart("PortalBase", Vector3.new(12, 2, 2), CFrame.new(archBaseX, 1, archZ), darkStone, Enum.Material.Slate, parent, true, true, 0, true)
    createPart("PortalFloor", Vector3.new(12, 0.6, 5.5), CFrame.new(archBaseX, 0.3, archZ), darkStone, Enum.Material.Slate, parent, true, true, 0, true)

    local leftPillar = createPart("PortalPillarL", Vector3.new(1.8, 12, 2), CFrame.new(archBaseX - 4.3, 6.2, archZ), stoneColor, Enum.Material.Slate, parent, true, true, 0, true)
    local rightPillar = createPart("PortalPillarR", Vector3.new(1.8, 12, 2), CFrame.new(archBaseX + 4.3, 6.2, archZ), stoneColor, Enum.Material.Slate, parent, true, true, 0, true)
    local lintel = createPart("PortalLintel", Vector3.new(10.4, 1.8, 2.2), CFrame.new(archBaseX, 12, archZ), stoneColor, Enum.Material.Slate, parent, true, true, 0, true)
    local keystone = createPart("PortalKeystone", Vector3.new(2.0, 1.8, 2.2), CFrame.new(archBaseX, 13.2, archZ), Color3.fromRGB(74, 61, 56), Enum.Material.Slate, parent, true, true, 0, true)
    local opening = createPart("PortalOpening", Vector3.new(7.2, 9.2, 1.1), CFrame.new(archBaseX, 5.1, archZ + 0.15), Color3.fromRGB(17, 9, 9), Enum.Material.SmoothPlastic, parent, true, true, 0, false)
    opening.CastShadow = false

    local glow = createPart("PortalGlow", Vector3.new(6.2, 8.0, 0.2), CFrame.new(archBaseX, 5.2, archZ + 0.88), Color3.fromRGB(255, 104, 34), Enum.Material.Neon, parent, true, false, 0.12, false)
    glow.CastShadow = false
    local glowLight = Instance.new("PointLight")
    glowLight.Color = Color3.fromRGB(255, 113, 45)
    glowLight.Brightness = 3.5
    glowLight.Range = 28
    glowLight.Shadows = true
    glowLight.Parent = glow

    for _, y in ipairs({9.8, 11.1}) do
        for _, z in ipairs({-3.6, 3.6}) do
            local chainAnchor = createPart(
                `ChainAnchor{y}_{z}`,
                Vector3.new(0.4, 0.4, 0.4),
                CFrame.new(archBaseX + math.sign(z) * 3.0, y, z),
                Color3.fromRGB(40, 40, 42),
                Enum.Material.Metal,
                parent,
                true,
                false,
                0,
                false
            )
            chainAnchor.CastShadow = false
        end
    end

    for index, z in ipairs({-3.1, 0, 3.1}) do
        for link = 1, 8 do
            local t = (link - 1) / 7
            local x = archBaseX - 2.6 + t * 5.2
            local y = 11.5 - math.abs(z) * 0.55 - math.sin(t * math.pi) * 1.0
            local chainLink = createPart(
                `ChainLink{index}_{link}`,
                Vector3.new(0.55, 0.18, 0.55),
                CFrame.new(x, y, z) * CFrame.Angles(0, math.rad(20 * (link % 2 == 0 and 1 or -1)), math.rad(30)),
                Color3.fromRGB(56, 56, 60),
                Enum.Material.Metal,
                parent,
                true,
                false,
                0,
                false
            )
            chainLink.Shape = Enum.PartType.Cylinder
            chainLink.CastShadow = false
        end
    end

    local titlePlate = createPart(
        "GatewayTitlePlate",
        Vector3.new(8.2, 1.2, 0.4),
        CFrame.new(archBaseX, 15.0, archZ),
        Color3.fromRGB(120, 19, 19),
        Enum.Material.Neon,
        parent,
        true,
        false,
        0,
        false
    )
    titlePlate.CastShadow = false
    createSignSurface(titlePlate, "بوابة الجحيم\nساحة الرعب", Color3.fromRGB(255, 98, 60), Color3.fromRGB(55, 6, 6), nil)

    local sideSign = createPart(
        "HorrorStoriesSign",
        Vector3.new(6, 0.9, 0.35),
        CFrame.new(-31.5, 8.0, -15.3) * CFrame.Angles(0, math.rad(180), 0),
        Color3.fromRGB(104, 13, 13),
        Enum.Material.Neon,
        parent,
        true,
        false,
        0,
        false
    )
    sideSign.CastShadow = false
    createSignSurface(sideSign, "قصص مرعبه", Color3.fromRGB(255, 74, 44), Color3.fromRGB(45, 5, 5), nil)

    return {
        leftPillar,
        rightPillar,
        lintel,
        keystone,
        opening,
        glow,
        titlePlate,
        sideSign,
    }
end

local function addDemonBackdrop(parent: Instance)
    local pieces = {}
    local darkColor = Color3.fromRGB(18, 15, 18)

    local torso = createPart("DemonTorso", Vector3.new(7, 4.2, 8.2), CFrame.new(45.0, 6.2, 0), darkColor, Enum.Material.Slate, parent, true, true, 0, true)
    torso.Shape = Enum.PartType.Block
    pieces[#pieces + 1] = torso

    local chest = createPart("DemonChest", Vector3.new(5.2, 3.4, 3.8), CFrame.new(43.8, 7.3, 0), darkColor, Enum.Material.Slate, parent, true, true, 0, true)
    chest.Shape = Enum.PartType.Block
    pieces[#pieces + 1] = chest

    local head = createPart("DemonHead", Vector3.new(3.5, 3.2, 3.4), CFrame.new(44.8, 11.6, 0), darkColor, Enum.Material.Slate, parent, true, true, 0, true)
    head.Shape = Enum.PartType.Block
    pieces[#pieces + 1] = head

    local shoulders = createPart("DemonShoulders", Vector3.new(10.0, 2.4, 3.2), CFrame.new(43.3, 9.1, 0), darkColor, Enum.Material.Slate, parent, true, true, 0, true)
    shoulders.Shape = Enum.PartType.Block
    pieces[#pieces + 1] = shoulders

    local leftHorn = createPart("DemonHornL", Vector3.new(1.0, 4.2, 1.0), CFrame.new(43.9, 14.5, -1.1) * CFrame.Angles(0, 0, math.rad(-26)), darkColor, Enum.Material.Slate, parent, true, true, 0, true)
    local rightHorn = createPart("DemonHornR", Vector3.new(1.0, 4.2, 1.0), CFrame.new(43.9, 14.5, 1.1) * CFrame.Angles(0, 0, math.rad(26)), darkColor, Enum.Material.Slate, parent, true, true, 0, true)
    pieces[#pieces + 1] = leftHorn
    pieces[#pieces + 1] = rightHorn

    local arms = createPart("DemonArms", Vector3.new(12.0, 1.8, 3.0), CFrame.new(44.0, 7.5, 0), darkColor, Enum.Material.Slate, parent, true, true, 0, true)
    arms.Shape = Enum.PartType.Block
    pieces[#pieces + 1] = arms

    local legs = createPart("DemonLegs", Vector3.new(4.6, 7.2, 3.0), CFrame.new(44.0, 2.0, 0), darkColor, Enum.Material.Slate, parent, true, true, 0, true)
    legs.Shape = Enum.PartType.Block
    pieces[#pieces + 1] = legs

    local eyeLeft = createPart("DemonEyeL", Vector3.new(0.28, 0.28, 0.28), CFrame.new(43.0, 11.6, -0.8), Color3.fromRGB(255, 45, 15), Enum.Material.Neon, parent, true, false, 0, false)
    local eyeRight = createPart("DemonEyeR", Vector3.new(0.28, 0.28, 0.28), CFrame.new(43.0, 11.6, 0.8), Color3.fromRGB(255, 45, 15), Enum.Material.Neon, parent, true, false, 0, false)
    pieces[#pieces + 1] = eyeLeft
    pieces[#pieces + 1] = eyeRight

    local halo = createPart("DemonHalo", Vector3.new(6.5, 7.5, 0.1), CFrame.new(41.8, 7.7, 0), Color3.fromRGB(255, 90, 32), Enum.Material.Neon, parent, true, false, 0.7, false)
    halo.CastShadow = false
    pieces[#pieces + 1] = halo

    local rimLight = Instance.new("PointLight")
    rimLight.Color = Color3.fromRGB(255, 82, 35)
    rimLight.Brightness = 1.8
    rimLight.Range = 18
    rimLight.Shadows = true
    rimLight.Parent = halo

    return pieces
end

local function addWallProps(parent: Instance)
    local props = {}

    local signBoard = createPart(
        "LeaderBoardFrame",
        Vector3.new(9.9, 0.65, 11.8),
        CFrame.new(-20.9, 9.7, 7.2) * CFrame.Angles(0, math.rad(90), 0),
        Color3.fromRGB(33, 19, 19),
        Enum.Material.Wood,
        parent,
        true,
        true,
        0,
        true
    )
    props[#props + 1] = signBoard

    local shopSign = createPart(
        "ShopSign",
        Vector3.new(5.8, 1.0, 0.35),
        CFrame.new(24.5, 8.0, -15.0) * CFrame.Angles(0, math.rad(180), 0),
        Color3.fromRGB(95, 58, 28),
        Enum.Material.Wood,
        parent,
        true,
        true,
        0,
        true
    )
    createSignSurface(shopSign, "Shop", Color3.fromRGB(255, 193, 117), Color3.fromRGB(34, 22, 10), nil)
    props[#props + 1] = shopSign

    local exitLeft = createPart(
        "ExitLeft",
        Vector3.new(3.4, 0.95, 0.35),
        CFrame.new(-12.0, 6.0, -20.2) * CFrame.Angles(0, math.rad(180), 0),
        Color3.fromRGB(112, 14, 14),
        Enum.Material.Neon,
        parent,
        true,
        false,
        0,
        false
    )
    createSignSurface(exitLeft, "EXIT", Color3.fromRGB(255, 55, 40), Color3.fromRGB(44, 5, 5), nil)
    props[#props + 1] = exitLeft

    local exitRight = createPart(
        "ExitRight",
        Vector3.new(3.4, 0.95, 0.35),
        CFrame.new(14.0, 6.0, 20.2),
        Color3.fromRGB(112, 14, 14),
        Enum.Material.Neon,
        parent,
        true,
        false,
        0,
        false
    )
    createSignSurface(exitRight, "EXIT", Color3.fromRGB(255, 55, 40), Color3.fromRGB(44, 5, 5), nil)
    props[#props + 1] = exitRight

    local stairsLeft = createPart(
        "StairLandingLeft",
        Vector3.new(8.0, 6.5, 1.0),
        CFrame.new(-16, 3.1, -17.8) * CFrame.Angles(0, 0, math.rad(12)),
        Color3.fromRGB(54, 35, 24),
        Enum.Material.WoodPlanks,
        parent,
        true,
        true,
        0,
        true
    )
    props[#props + 1] = stairsLeft

    local stairsRight = createPart(
        "StairLandingRight",
        Vector3.new(8.0, 6.5, 1.0),
        CFrame.new(8, 3.1, 17.8) * CFrame.Angles(0, 0, math.rad(-12)),
        Color3.fromRGB(54, 35, 24),
        Enum.Material.WoodPlanks,
        parent,
        true,
        true,
        0,
        true
    )
    props[#props + 1] = stairsRight

    return props
end

local function addFloorProps(parent: Instance)
    local props = {}

    for _, point in ipairs({
        Vector3.new(-8, 0.35, -2),
        Vector3.new(2, 0.35, 1),
        Vector3.new(13, 0.35, -3),
        Vector3.new(6, 0.35, 5),
    }) do
        local plank = createPart(
            "DebrisPlank",
            Vector3.new(3.5, 0.3, 0.35),
            CFrame.new(point) * CFrame.Angles(math.rad(15), math.rad(math.random(-20, 20)), math.rad(math.random(-25, 25))),
            Color3.fromRGB(62, 40, 27),
            Enum.Material.WoodPlanks,
            parent,
            true,
            false,
            0,
            false
        )
        plank.CastShadow = false
        props[#props + 1] = plank
    end

    for _, point in ipairs({
        Vector3.new(-5, 0.55, -6),
        Vector3.new(4, 0.55, 8),
        Vector3.new(17, 0.55, -8),
    }) do
        local tomb = createPart(
            "TombCross",
            Vector3.new(0.8, 3.0, 0.8),
            CFrame.new(point),
            Color3.fromRGB(44, 38, 40),
            Enum.Material.Slate,
            parent,
            true,
            false,
            0,
            true
        )
        tomb.CastShadow = true

        local bar = createPart(
            "TombCrossBar",
            Vector3.new(2.0, 0.5, 0.5),
            CFrame.new(point.X, point.Y + 1.1, point.Z),
            Color3.fromRGB(44, 38, 40),
            Enum.Material.Slate,
            parent,
            true,
            false,
            0,
            true
        )
        bar.CastShadow = true
    end

    return props
end

local function addLanternRows(parent: Instance)
    local lanterns = {}
    for _, zSide in ipairs({-1, 1}) do
        for _, x in ipairs({-28, -10, 8, 26, 42}) do
            local lantern = createLantern(
                parent,
                CFrame.new(x, 9.7, zSide * 18.6) * CFrame.Angles(0, math.rad(90 * zSide), math.rad(6))
            )
            lanterns[#lanterns + 1] = lantern
        end
    end
    return lanterns
end

local function buildLobbyGeometry(spawnLocation: SpawnLocation, leaderboardAnchor: BasePart, matchmakingCircle: BasePart)
    local hallRoot = Instance.new("Folder")
    hallRoot.Name = "LobbyHallGeometry"
    hallRoot.Parent = Workspace

    local hallLength = 88
    local hallWidth = 44
    local hallHeight = 16

    if spawnLocation then
        spawnLocation.CFrame = CFrame.lookAt(Vector3.new(-34, 2.5, 0), Vector3.new(0, 2.5, 0))
        spawnLocation.Size = Vector3.new(12, 1, 12)
    end

    local floor = addFloorPlanks(hallRoot, hallLength, hallWidth)
    local walls = {
        addWall(hallRoot, CFrame.new(0, hallHeight / 2, hallWidth / 2 + 0.5), Vector3.new(hallLength, hallHeight, 1.2)),
        addWall(hallRoot, CFrame.new(0, hallHeight / 2, -(hallWidth / 2 + 0.5)), Vector3.new(hallLength, hallHeight, 1.2)),
    }
    local ceiling = addCeiling(hallRoot, hallLength, hallWidth, hallHeight)
    local columns = addSideColumns(hallRoot, hallLength, hallWidth, hallHeight)
    local balconies = addBalcony(hallRoot, hallLength, hallWidth, hallHeight)
    addStairs(hallRoot, hallHeight, -1)
    addStairs(hallRoot, hallHeight, 1)
    local lanterns = addLanternRows(hallRoot)
    local arch = addArchway(hallRoot)
    local demon = addDemonBackdrop(hallRoot)
    local props = addWallProps(hallRoot)
    local floorProps = addFloorProps(hallRoot)

    matchmakingCircle.CFrame = CFrame.new(38, 0.55, 0)
    matchmakingCircle.Size = Vector3.new(12, 0.9, 12)
    matchmakingCircle.Shape = Enum.PartType.Cylinder
    matchmakingCircle.Orientation = Vector3.new(0, 0, 90)
    matchmakingCircle.Material = Enum.Material.Neon
    matchmakingCircle.CanTouch = true
    matchmakingCircle.Color = GameConfig.COLORS.AccentAlt
    matchmakingCircle.Transparency = 0.2
    matchmakingCircle.CastShadow = false
    matchmakingCircle.Parent = hallRoot

    local portalLight = Instance.new("PointLight")
    portalLight.Color = Color3.fromRGB(255, 130, 60)
    portalLight.Brightness = 4
    portalLight.Range = 26
    portalLight.Shadows = true
    portalLight.Parent = matchmakingCircle

    local totalParts = 0
    for _, descendant in ipairs(hallRoot:GetDescendants()) do
        if descendant:IsA("BasePart") then
            totalParts += 1
        end
    end
    print(`Lobby geometry built: {totalParts} BaseParts`)

    return hallRoot
end

local function applyLobbyLighting()
    Lighting.ClockTime = 0.2
    Lighting.Brightness = 0.8
    Lighting.Ambient = GameConfig.COLORS.PanelSoft
    Lighting.OutdoorAmbient = GameConfig.COLORS.Background
    Lighting.FogColor = Color3.fromRGB(18, 14, 28)
    Lighting.FogEnd = 220
    Lighting.EnvironmentDiffuseScale = 0.35
    Lighting.EnvironmentSpecularScale = 0.1
    Lighting.ExposureCompensation = -0.15

    local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
    if not atmosphere then
        atmosphere = Instance.new("Atmosphere")
        atmosphere.Parent = Lighting
    end

    atmosphere.Color = Color3.fromRGB(15, 11, 24)
    atmosphere.Decay = Color3.fromRGB(56, 29, 64)
    atmosphere.Density = 0.42
    atmosphere.Glare = 0
    atmosphere.Haze = 1.2
    atmosphere.Offset = 0.1

    local correction = Lighting:FindFirstChildOfClass("ColorCorrectionEffect")
    if not correction then
        correction = Instance.new("ColorCorrectionEffect")
        correction.Parent = Lighting
    end

    correction.Brightness = -0.05
    correction.Contrast = 0.2
    correction.Saturation = -0.18
    correction.TintColor = Color3.fromRGB(200, 170, 255)
end

local function prepareLobby()
    local lightingOk, lightingErr = pcall(applyLobbyLighting)
    if not lightingOk then
        warn(`Gateway to Hell lobby lighting setup failed: {lightingErr}`)
    end
    ensureRemoteFolder()
    ensureSignalFolder()

    local leaderboardAnchor = ensureAnchor(
        "LeaderboardAnchor",
        Vector3.new(9.5, 12.5, 0.7),
        CFrame.new(-20.9, 10.2, 7.2) * CFrame.Angles(0, math.rad(90), 0),
        Color3.fromRGB(24, 15, 19)
    )
    local matchmakingCircle = ensureAnchor(
        "MatchmakingCircle",
        Vector3.new(12, 1, 12),
        CFrame.new(20, 1.5, 0),
        Color3.fromRGB(95, 36, 29)
    )
    matchmakingCircle.Shape = Enum.PartType.Cylinder
    matchmakingCircle.Orientation = Vector3.new(0, 0, 90)
    matchmakingCircle.Material = Enum.Material.Neon

    leaderboardAnchor.Material = Enum.Material.SmoothPlastic
    leaderboardAnchor.Transparency = 0.12
    leaderboardAnchor.Color = Color3.fromRGB(25, 17, 21)

    local accentParts = { leaderboardAnchor, matchmakingCircle }
    for _, part in ipairs(accentParts) do
        attachFlickerLight(part, Color3.fromRGB(255, 123, 74))
        attachFlickerLight(part, Color3.fromRGB(176, 49, 39))
    end

    local frame = Instance.new("WedgePart")
    frame.Name = "LeaderboardFrameAccent"
    frame.Anchored = true
    frame.CanCollide = false
    frame.CanQuery = false
    frame.CanTouch = false
    frame.CastShadow = false
    frame.Material = Enum.Material.Metal
    frame.Color = Color3.fromRGB(57, 28, 24)
    frame.Size = Vector3.new(0.4, 12.8, 9.9)
    frame.CFrame = leaderboardAnchor.CFrame * CFrame.new(-0.35, 0, 0)
    frame.Parent = Workspace

    buildLobbyGeometry(
        Workspace:FindFirstChild("SpawnLocation"),
        leaderboardAnchor,
        matchmakingCircle
    )

    -- TODO: Replace placeholder anchors with Blender meshes loaded via InsertService.
    -- The helper below is intentionally lightweight so future FBX assets can be
    -- dropped into place without rewriting the lobby bootstrap code.
    local function loadLobbyMesh(assetId: number)
        return loadAsset(assetId)
    end

    if GameConfig.PLACEHOLDER_ASSET_IDS.LobbyMesh > 0 then
        local model = loadLobbyMesh(GameConfig.PLACEHOLDER_ASSET_IDS.LobbyMesh)
        if model then
            model.Parent = Workspace
        end
    end
end

local bootstrapOk, bootstrapErr = xpcall(prepareLobby, debug.traceback)
if not bootstrapOk then
    warn(`Gateway to Hell lobby bootstrap failed: {bootstrapErr}`)
end

local gameReadyEvent = ReplicatedStorage:WaitForChild(REMOTES_FOLDER_NAME):WaitForChild("GameReady")
local function announceReady(player: Player)
    task.delay(1, function()
        if player.Parent == Players then
            gameReadyEvent:FireClient(player)
        end
    end)
end

for _, player in ipairs(Players:GetPlayers()) do
    announceReady(player)
end

Players.PlayerAdded:Connect(announceReady)
