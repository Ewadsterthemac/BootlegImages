--[[
    CameraController.client.lua
    First-person camera system with ADS, leaning, and effects
    Location: StarterPlayerScripts/CameraController

    This script handles:
    - First-person camera lock
    - ADS (Aim Down Sights) zooming
    - Leaning camera offset
    - Head bob while moving
    - Weapon sway
    - FOV changes
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local RootPart = Character:WaitForChild("HumanoidRootPart")
local Head = Character:WaitForChild("Head")

local Camera = workspace.CurrentCamera

-- Wait for config
local Config = ReplicatedStorage:WaitForChild("Config")
local GameConfig = require(Config:WaitForChild("GameConfig"))
local CameraConfig = GameConfig.Camera

-- ===========================================
-- STATE
-- ===========================================
local CameraState = {
    -- View mode
    IsFirstPerson = true,
    IsADS = false,

    -- Current values (smoothed)
    CurrentFOV = CameraConfig.DefaultFOV,
    CurrentLeanOffset = Vector3.new(0, 0, 0),
    CurrentLeanAngle = 0,

    -- Target values
    TargetFOV = CameraConfig.DefaultFOV,
    TargetLeanOffset = Vector3.new(0, 0, 0),
    TargetLeanAngle = 0,

    -- Head bob
    BobTime = 0,
    CurrentBobOffset = Vector3.new(0, 0, 0),

    -- Weapon sway
    SwayOffset = Vector2.new(0, 0),
    LastMouseDelta = Vector2.new(0, 0),

    -- Breathing
    BreathTime = 0,
    BreathingOffset = Vector3.new(0, 0, 0),

    -- Sensitivity
    CurrentSensitivity = CameraConfig.BaseSensitivity,
}

-- Movement controller reference
local MovementController = nil

-- ===========================================
-- INITIALIZATION
-- ===========================================

local function initializeCamera()
    -- Set camera to scriptable for full control
    Camera.CameraType = Enum.CameraType.Scriptable

    -- Lock mouse
    UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter

    -- Set initial FOV
    Camera.FieldOfView = CameraConfig.DefaultFOV

    -- Hide character in first person
    if CameraState.IsFirstPerson then
        setCharacterTransparency(1)
    end
end

--[[
    Sets character transparency for first-person view
    @param transparency: number - 0 = visible, 1 = invisible
]]
function setCharacterTransparency(transparency: number)
    for _, part in ipairs(Character:GetDescendants()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            part.LocalTransparencyModifier = transparency
        elseif part:IsA("Decal") or part:IsA("Texture") then
            part.Transparency = transparency
        end
    end
end

-- ===========================================
-- FOV MANAGEMENT
-- ===========================================

local function updateTargetFOV()
    local targetFOV = CameraConfig.DefaultFOV

    -- ADS reduces FOV
    if CameraState.IsADS then
        targetFOV = CameraConfig.ADSFOV
    -- Sprint increases FOV slightly
    elseif MovementController and MovementController.GetState().IsSprinting then
        targetFOV = CameraConfig.SprintFOV
    end

    CameraState.TargetFOV = targetFOV
end

-- ===========================================
-- LEAN SYSTEM
-- ===========================================

local function updateLean()
    local leanDirection = 0
    if MovementController then
        leanDirection = MovementController.GetLeanDirection()
    end

    if leanDirection ~= 0 then
        CameraState.TargetLeanAngle = CameraConfig.LeanAngle * leanDirection
        CameraState.TargetLeanOffset = Vector3.new(
            CameraConfig.LeanOffset * leanDirection,
            0,
            0
        )
    else
        CameraState.TargetLeanAngle = 0
        CameraState.TargetLeanOffset = Vector3.new(0, 0, 0)
    end
end

-- ===========================================
-- HEAD BOB
-- ===========================================

local function updateHeadBob(dt: number)
    if not CameraConfig.HeadBobEnabled then return end

    local moveSpeed = Humanoid.MoveDirection.Magnitude

    if moveSpeed > 0.1 and Humanoid:GetState() ~= Enum.HumanoidStateType.Freefall then
        -- Determine bob speed based on movement
        local bobSpeed = CameraConfig.HeadBobSpeed
        local bobIntensity = CameraConfig.HeadBobIntensity

        -- Increase bob when sprinting
        if MovementController and MovementController.GetState().IsSprinting then
            bobSpeed = bobSpeed * 1.5
            bobIntensity = bobIntensity * CameraConfig.SprintBobMultiplier
        end

        -- Reduce bob when ADS
        if CameraState.IsADS then
            bobIntensity = bobIntensity * 0.3
        end

        CameraState.BobTime = CameraState.BobTime + dt * bobSpeed

        -- Calculate bob offset (figure-8 pattern)
        local bobX = math.sin(CameraState.BobTime) * bobIntensity
        local bobY = math.abs(math.cos(CameraState.BobTime)) * bobIntensity * 0.5

        CameraState.CurrentBobOffset = Vector3.new(bobX, bobY, 0)
    else
        -- Smoothly return to center when not moving
        CameraState.CurrentBobOffset = CameraState.CurrentBobOffset:Lerp(Vector3.new(0, 0, 0), dt * 5)
        CameraState.BobTime = 0
    end
end

-- ===========================================
-- WEAPON SWAY
-- ===========================================

local function updateWeaponSway(dt: number)
    -- Get mouse movement
    local mouseDelta = UserInputService:GetMouseDelta()

    -- Calculate sway based on mouse movement
    local targetSwayX = math.clamp(mouseDelta.X * CameraConfig.WeaponSwayAmount, -0.1, 0.1)
    local targetSwayY = math.clamp(mouseDelta.Y * CameraConfig.WeaponSwayAmount, -0.1, 0.1)

    -- Smooth sway
    CameraState.SwayOffset = Vector2.new(
        CameraState.SwayOffset.X + (targetSwayX - CameraState.SwayOffset.X) * dt * CameraConfig.WeaponSwaySpeed,
        CameraState.SwayOffset.Y + (targetSwayY - CameraState.SwayOffset.Y) * dt * CameraConfig.WeaponSwaySpeed
    )

    -- Decay sway back to center
    CameraState.SwayOffset = CameraState.SwayOffset * (1 - dt * 2)

    CameraState.LastMouseDelta = mouseDelta
end

-- ===========================================
-- BREATHING SWAY
-- ===========================================

local function updateBreathing(dt: number)
    CameraState.BreathTime = CameraState.BreathTime + dt

    local breathIntensity = CameraConfig.BreathingSwayAmount

    -- Increase breath when ADS (simulating holding breath would reduce it)
    if CameraState.IsADS then
        breathIntensity = breathIntensity * 0.5
    end

    -- Gentle breathing motion
    local breathX = math.sin(CameraState.BreathTime * 0.8) * breathIntensity
    local breathY = math.sin(CameraState.BreathTime * 1.2) * breathIntensity * 0.5

    CameraState.BreathingOffset = Vector3.new(breathX, breathY, 0)
end

-- ===========================================
-- MAIN CAMERA UPDATE
-- ===========================================

local cameraAngleX = 0 -- Horizontal rotation
local cameraAngleY = 0 -- Vertical rotation (clamped)

local function updateCamera(dt: number)
    -- Get mouse input
    local mouseDelta = UserInputService:GetMouseDelta()

    -- Apply sensitivity
    local sensitivity = CameraState.CurrentSensitivity
    if CameraState.IsADS then
        sensitivity = sensitivity * CameraConfig.ADSSensitivityMultiplier
    end

    -- Update angles
    cameraAngleX = cameraAngleX - mouseDelta.X * sensitivity
    cameraAngleY = math.clamp(cameraAngleY - mouseDelta.Y * sensitivity, -80, 80)

    -- Update subsystems
    updateTargetFOV()
    updateLean()
    updateHeadBob(dt)
    updateWeaponSway(dt)
    updateBreathing(dt)

    -- Smooth FOV transition
    CameraState.CurrentFOV = CameraState.CurrentFOV + (CameraState.TargetFOV - CameraState.CurrentFOV) * dt * CameraConfig.FOVLerpSpeed

    -- Smooth lean transition
    CameraState.CurrentLeanOffset = CameraState.CurrentLeanOffset:Lerp(CameraState.TargetLeanOffset, dt * CameraConfig.LeanSpeed)
    CameraState.CurrentLeanAngle = CameraState.CurrentLeanAngle + (CameraState.TargetLeanAngle - CameraState.CurrentLeanAngle) * dt * CameraConfig.LeanSpeed

    -- Calculate final camera position
    local headPosition = Head.Position

    -- Base camera CFrame from head
    local baseCFrame = CFrame.new(headPosition)
        * CFrame.Angles(0, math.rad(cameraAngleX), 0)
        * CFrame.Angles(math.rad(cameraAngleY), 0, 0)

    -- Apply lean rotation
    local leanCFrame = CFrame.Angles(0, 0, math.rad(-CameraState.CurrentLeanAngle))

    -- Apply offsets
    local totalOffset = CameraState.CurrentLeanOffset + CameraState.CurrentBobOffset + CameraState.BreathingOffset
    local offsetCFrame = CFrame.new(totalOffset)

    -- Final camera CFrame
    local finalCFrame = baseCFrame * leanCFrame * offsetCFrame

    -- Apply to camera
    Camera.CFrame = finalCFrame
    Camera.FieldOfView = CameraState.CurrentFOV

    -- Rotate character to match camera yaw
    if RootPart then
        RootPart.CFrame = CFrame.new(RootPart.Position) * CFrame.Angles(0, math.rad(cameraAngleX), 0)
    end
end

-- ===========================================
-- INPUT HANDLING
-- ===========================================

-- ADS toggle (right mouse button)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        CameraState.IsADS = true
        CameraState.CurrentSensitivity = CameraConfig.BaseSensitivity * CameraConfig.ADSSensitivityMultiplier

        -- Notify movement controller
        if MovementController then
            MovementController.SetADS(true)
        end
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        CameraState.IsADS = false
        CameraState.CurrentSensitivity = CameraConfig.BaseSensitivity

        if MovementController then
            MovementController.SetADS(false)
        end
    end
end)

-- Toggle first/third person (V key)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if input.KeyCode == Enum.KeyCode.V then
        CameraState.IsFirstPerson = not CameraState.IsFirstPerson
        setCharacterTransparency(CameraState.IsFirstPerson and 1 or 0)
    end
end)

-- ===========================================
-- MAIN LOOP
-- ===========================================

RunService.RenderStepped:Connect(function(dt)
    updateCamera(dt)
end)

-- ===========================================
-- CHARACTER RESPAWN HANDLING
-- ===========================================

Player.CharacterAdded:Connect(function(newCharacter)
    Character = newCharacter
    Humanoid = Character:WaitForChild("Humanoid")
    RootPart = Character:WaitForChild("HumanoidRootPart")
    Head = Character:WaitForChild("Head")

    -- Reset camera state
    CameraState.IsADS = false
    CameraState.CurrentFOV = CameraConfig.DefaultFOV
    CameraState.CurrentLeanOffset = Vector3.new(0, 0, 0)
    CameraState.CurrentLeanAngle = 0
    CameraState.BobTime = 0

    -- Reinitialize
    initializeCamera()
end)

-- ===========================================
-- GET MOVEMENT CONTROLLER REFERENCE
-- ===========================================

task.spawn(function()
    -- Wait for movement controller to initialize
    task.wait(0.5)
    MovementController = _G.MovementController
end)

-- ===========================================
-- PUBLIC API
-- ===========================================

local CameraController = {}

function CameraController.SetADS(isAiming: boolean)
    CameraState.IsADS = isAiming
end

function CameraController.GetState()
    return table.clone(CameraState)
end

function CameraController.SetSensitivity(sens: number)
    CameraConfig.BaseSensitivity = sens
    CameraState.CurrentSensitivity = sens
end

function CameraController.ShakeCamera(intensity: number, duration: number)
    -- Camera shake for recoil, explosions, etc.
    task.spawn(function()
        local startTime = tick()
        while tick() - startTime < duration do
            local progress = (tick() - startTime) / duration
            local shake = intensity * (1 - progress)

            local shakeX = (math.random() - 0.5) * shake
            local shakeY = (math.random() - 0.5) * shake

            cameraAngleX = cameraAngleX + shakeX
            cameraAngleY = cameraAngleY + shakeY

            task.wait()
        end
    end)
end

function CameraController.ApplyRecoil(vertical: number, horizontal: number)
    -- Apply recoil to camera angles
    cameraAngleY = cameraAngleY + vertical
    cameraAngleX = cameraAngleX + horizontal
end

_G.CameraController = CameraController

-- Initialize
initializeCamera()

print("[CameraController] Client initialized")
