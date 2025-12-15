--[[
    MovementController.client.lua
    Client-side movement handling
    Location: StarterPlayerScripts/MovementController
]]

print("[MovementController] Script starting...")

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("[MovementController] Services loaded")

local Player = Players.LocalPlayer
print("[MovementController] Got LocalPlayer:", Player.Name)

local Character = Player.Character or Player.CharacterAdded:Wait()
print("[MovementController] Got Character")

local Humanoid = Character:WaitForChild("Humanoid", 10)
if not Humanoid then
    warn("[MovementController] ERROR: Could not find Humanoid!")
    return
end
print("[MovementController] Got Humanoid")

local RootPart = Character:WaitForChild("HumanoidRootPart", 10)
if not RootPart then
    warn("[MovementController] ERROR: Could not find HumanoidRootPart!")
    return
end
print("[MovementController] Got RootPart")

-- Wait for modules
print("[MovementController] Loading modules...")

local Modules = ReplicatedStorage:WaitForChild("Modules", 10)
if not Modules then
    warn("[MovementController] ERROR: Could not find Modules folder!")
    return
end

local Config = ReplicatedStorage:WaitForChild("Config", 10)
if not Config then
    warn("[MovementController] ERROR: Could not find Config folder!")
    return
end

print("[MovementController] Found folders, requiring modules...")

local success, StaminaSystem = pcall(function()
    return require(Modules:WaitForChild("StaminaSystem"))
end)
if not success then
    warn("[MovementController] ERROR loading StaminaSystem:", StaminaSystem)
    return
end
print("[MovementController] StaminaSystem loaded")

local success2, GameConfig = pcall(function()
    return require(Config:WaitForChild("GameConfig"))
end)
if not success2 then
    warn("[MovementController] ERROR loading GameConfig:", GameConfig)
    return
end
print("[MovementController] GameConfig loaded")

local MovementConfig = GameConfig.Player.Movement
local JumpConfig = GameConfig.Player.Jump
local StaminaConfig = GameConfig.Player.Stamina

print("[MovementController] Config values loaded")
print("[MovementController] WalkSpeed:", MovementConfig.WalkSpeed)
print("[MovementController] SprintSpeed:", MovementConfig.SprintSpeed)

-- ===========================================
-- STATE
-- ===========================================
local MovementState = {
    IsSprinting = false,
    IsCrouching = false,
    IsProne = false,
    IsADS = false,
    LeanDirection = 0,
    IsMovingBackward = false,
}

-- Initialize stamina system
print("[MovementController] Creating StaminaSystem...")
local Stamina = StaminaSystem.new(Player)
Stamina:Start()
print("[MovementController] StaminaSystem started")

-- ===========================================
-- KEYBINDS
-- ===========================================
local Keybinds = {
    Sprint = Enum.KeyCode.LeftShift,
    Crouch = Enum.KeyCode.LeftControl,
    Prone = Enum.KeyCode.Z,
    LeanLeft = Enum.KeyCode.Q,
    LeanRight = Enum.KeyCode.E,
    Jump = Enum.KeyCode.Space,
}

-- ===========================================
-- INPUT HANDLING
-- ===========================================

local function updateMovementSpeed()
    if not Humanoid then return end

    local baseSpeed = MovementConfig.WalkSpeed

    if MovementState.IsProne then
        baseSpeed = MovementConfig.ProneSpeed
    elseif MovementState.IsCrouching then
        baseSpeed = MovementConfig.CrouchSpeed
    elseif MovementState.IsSprinting and Stamina:CanSprint() then
        baseSpeed = MovementConfig.SprintSpeed
    end

    if MovementState.IsADS then
        baseSpeed = baseSpeed * MovementConfig.ADSSpeedMultiplier
    end

    if MovementState.IsMovingBackward then
        baseSpeed = baseSpeed * MovementConfig.BackpedalMultiplier
    end

    Humanoid.WalkSpeed = baseSpeed
end

local function startSprint()
    if MovementState.IsCrouching or MovementState.IsProne then return end
    if not Stamina:TryStartSprint() then return end

    MovementState.IsSprinting = true
    updateMovementSpeed()
    print("[MovementController] Sprint ON")
end

local function stopSprint()
    MovementState.IsSprinting = false
    Stamina:StopSprint()
    updateMovementSpeed()
    print("[MovementController] Sprint OFF")
end

local function toggleCrouch()
    if MovementState.IsProne then
        MovementState.IsProne = false
        MovementState.IsCrouching = true
    elseif MovementState.IsCrouching then
        MovementState.IsCrouching = false
    else
        MovementState.IsCrouching = true
        if MovementState.IsSprinting then
            stopSprint()
        end
    end
    updateMovementSpeed()

    -- Update hip height for crouch visual
    if Humanoid then
        Humanoid.HipHeight = MovementState.IsCrouching and 0.5 or 2.0
    end
    print("[MovementController] Crouch:", MovementState.IsCrouching)
end

local function toggleProne()
    if MovementState.IsProne then
        MovementState.IsProne = false
    else
        MovementState.IsProne = true
        MovementState.IsCrouching = false
        if MovementState.IsSprinting then
            stopSprint()
        end
    end
    updateMovementSpeed()

    if Humanoid then
        if MovementState.IsProne then
            Humanoid.HipHeight = 0.1
        elseif MovementState.IsCrouching then
            Humanoid.HipHeight = 0.5
        else
            Humanoid.HipHeight = 2.0
        end
    end
    print("[MovementController] Prone:", MovementState.IsProne)
end

local function setLean(direction: number)
    MovementState.LeanDirection = direction
end

-- ===========================================
-- INPUT CONNECTIONS
-- ===========================================

print("[MovementController] Connecting input handlers...")

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if input.KeyCode == Keybinds.Sprint then
        startSprint()
    elseif input.KeyCode == Keybinds.Crouch then
        toggleCrouch()
    elseif input.KeyCode == Keybinds.Prone then
        toggleProne()
    elseif input.KeyCode == Keybinds.LeanLeft then
        setLean(-1)
    elseif input.KeyCode == Keybinds.LeanRight then
        setLean(1)
    elseif input.KeyCode == Keybinds.Jump then
        if not Stamina:CanJump() then
            Humanoid.JumpPower = 0
        else
            Stamina:UseJumpStamina()
            Humanoid.JumpPower = JumpConfig.JumpPower
            if MovementState.IsCrouching then
                Humanoid.JumpPower = JumpConfig.JumpPower * JumpConfig.CrouchJumpBoost
            end
        end
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if input.KeyCode == Keybinds.Sprint then
        stopSprint()
    elseif input.KeyCode == Keybinds.LeanLeft then
        if MovementState.LeanDirection == -1 then
            setLean(0)
        end
    elseif input.KeyCode == Keybinds.LeanRight then
        if MovementState.LeanDirection == 1 then
            setLean(0)
        end
    elseif input.KeyCode == Keybinds.Jump then
        Humanoid.JumpPower = JumpConfig.JumpPower
    end
end)

-- ===========================================
-- MOVEMENT DIRECTION DETECTION
-- ===========================================

RunService.RenderStepped:Connect(function(dt)
    if not Humanoid or not RootPart then return end

    local moveDirection = Humanoid.MoveDirection
    if moveDirection.Magnitude > 0.1 then
        local lookVector = RootPart.CFrame.LookVector
        local dot = moveDirection:Dot(lookVector)
        MovementState.IsMovingBackward = dot < -0.5
    else
        MovementState.IsMovingBackward = false
    end

    if MovementState.IsSprinting and not Stamina:CanSprint() then
        stopSprint()
    end

    updateMovementSpeed()
end)

-- ===========================================
-- STAMINA EVENTS
-- ===========================================

Stamina.OnStaminaDepleted.Event:Connect(function()
    stopSprint()
end)

-- ===========================================
-- CHARACTER RESPAWN HANDLING
-- ===========================================

Player.CharacterAdded:Connect(function(newCharacter)
    Character = newCharacter
    Humanoid = Character:WaitForChild("Humanoid")
    RootPart = Character:WaitForChild("HumanoidRootPart")

    MovementState.IsSprinting = false
    MovementState.IsCrouching = false
    MovementState.IsProne = false
    MovementState.IsADS = false
    MovementState.LeanDirection = 0

    Stamina:Reset()
    updateMovementSpeed()

    print("[MovementController] Character respawned - Ready")
end)

-- ===========================================
-- PUBLIC API
-- ===========================================

local MovementController = {}

function MovementController.GetState()
    return table.clone(MovementState)
end

function MovementController.SetADS(isAiming: boolean)
    MovementState.IsADS = isAiming
    if isAiming and MovementState.IsSprinting then
        stopSprint()
    end
    updateMovementSpeed()
end

function MovementController.GetStamina()
    return Stamina
end

function MovementController.GetLeanDirection()
    return MovementState.LeanDirection
end

_G.MovementController = MovementController

-- Set initial speed
updateMovementSpeed()

print("[MovementController] ✓ Fully initialized - Hold SHIFT to sprint!")
