local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local wind = Instance.new("Sound")
wind.Name = "LobbyWindLoop"
wind.SoundId = GameConfig.PLACEHOLDER_ASSET_IDS.WindLoop > 0 and `rbxassetid://{GameConfig.PLACEHOLDER_ASSET_IDS.WindLoop}` or ""
wind.Volume = 0.35
wind.Looped = true
wind.RollOffMode = Enum.RollOffMode.InverseTapered
wind.Parent = SoundService

local music = Instance.new("Sound")
music.Name = "LobbyAmbientMusic"
music.SoundId = GameConfig.PLACEHOLDER_ASSET_IDS.LobbyMusic > 0 and `rbxassetid://{GameConfig.PLACEHOLDER_ASSET_IDS.LobbyMusic}` or ""
music.Volume = 0.2
music.Looped = true
music.RollOffMode = Enum.RollOffMode.InverseTapered
music.Parent = SoundService

if wind.SoundId ~= "" then
    wind:Play()
end

if music.SoundId ~= "" then
    music:Play()
end

local player = Players.LocalPlayer
local cameraOffset = Vector3.zero
local cameraConnection: RBXScriptConnection? = nil

local function bindCharacter(character)
    local humanoid = character:WaitForChild("Humanoid", 5)
    if not humanoid or not humanoid:IsA("Humanoid") then
        return
    end

    if cameraConnection then
        cameraConnection:Disconnect()
        cameraConnection = nil
    end

    cameraConnection = RunService.RenderStepped:Connect(function()
        if humanoid.Parent == nil then
            return
        end

        local swayX = math.sin(os.clock() * 0.6) * 0.08
        local swayY = math.cos(os.clock() * 0.45) * 0.04
        local target = Vector3.new(swayX, swayY, 0)
        cameraOffset = cameraOffset:Lerp(target, 0.08)
        humanoid.CameraOffset = cameraOffset
    end)
end

if player.Character then
    bindCharacter(player.Character)
end

player.CharacterAdded:Connect(bindCharacter)
