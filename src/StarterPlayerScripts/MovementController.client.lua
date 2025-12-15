--[[
    MovementController.client.lua
    Client-side movement handling
    Location: StarterPlayerScripts/MovementController

    This script handles:
    - Sprint/Walk toggling
    - Crouch/Prone states
    - Leaning
    - Jump stamina cost
    - Movement speed modifications
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local RootPart = Character:WaitForChild("HumanoidRootPart")

-- Wait for modules
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Config = ReplicatedStorage:WaitForChild("Config")

local StaminaSystem = require(Modules:WaitForChild("StaminaSystem"))
local GameConfig = require(Config:WaitForChild("GameConfig"))

local MovementConfig = GameConfig.Player.Movement
local JumpConfig = GameConfig.Player.Jump
local StaminaConfig = GameConfig.Player.Stamina

-- ===========================================
-- STATE
-- ===========================================
local MovementState = {
    IsSprinting = false,
    IsCrouching = false,
    IsProne = false,
    IsADS = false,
    LeanDirection = 0, -- -1 left, 0 none, 1 right
    IsMovingBackward = false,
}

-- Initialize stamina system
local Stamina = StaminaSystem.new(Player)
Stamina:Start()

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
    local baseSpeed = MovementConfig.WalkSpeed

    -- Apply state modifiers
    if MovementState.IsProne then
        baseSpeed = MovementConfig.ProneSpeed
    elseif MovementState.IsCrouching then
        baseSpeed = MovementConfig.CrouchSpeed
    elseif MovementState.IsSprinting and Stamina:CanSprint() then
        baseSpeed = MovementConfig.SprintSpeed
    end

    -- Apply ADS modifier
    if MovementState.IsADS then
        baseSpeed = baseSpeed * MovementConfig.ADSSpeedMultiplier
    end

    -- Apply backpedal modifier
    if MovementState.IsMovingBackward then
        baseSpeed = baseSpeed * MovementConfig.BackpedalMultiplier
    end

    -- Apply to humanoid
    Humanoid.WalkSpeed = baseSpeed
end

local function startSprint()
    if MovementState.IsCrouching or MovementState.IsProne then return end
    if not Stamina:TryStartSprint() then return end

    MovementState.IsSprinting = true
    updateMovementSpeed()
end

local function stopSprint()
    MovementState.IsSprinting = false
    Stamina:StopSprint()
    updateMovementSpeed()
end

local function toggleCrouch()
    if MovementState.IsProne then
        -- Stand up from prone to crouch
        MovementState.IsProne = false
        MovementState.IsCrouching = true
    elseif MovementState.IsCrouching then
        -- Stand up from crouch
        MovementState.IsCrouching = false
    else
        -- Go to crouch
        MovementState.IsCrouching = true
        if MovementState.IsSprinting then
            stopSprint()
        end
    end
    updateMovementSpeed()
    updateCrouchVisuals()
end

local function toggleProne()
    if MovementState.IsProne then
        -- Get up from prone
        MovementState.IsProne = false
    else
        -- Go prone
        MovementState.IsProne = true
        MovementState.IsCrouching = false
        if MovementState.IsSprinting then
            stopSprint()
        end
    end
    updateMovementSpeed()
    updateProneVisuals()
end

local function setLean(direction: number)
    MovementState.LeanDirection = direction
    -- Lean visuals handled by CameraController
end

--[[
    Updates crouch visuals (camera height, hitbox)
]]
function updateCrouchVisuals()
    -- Adjust camera offset and character scale for crouch
    -- This is a simplified version - full implementation would modify HumanoidDescription
    local crouchScale = MovementState.IsCrouching and 0.6 or 1.0

    -- You can adjust HipHeight for crouching effect
    if Humanoid then
        Humanoid.HipHeight = MovementState.IsCrouching and 0.5 or 2.0
    end
end

--[[
    Updates prone visuals
]]
function updateProneVisuals()
    -- Prone is more complex - would need custom animations
    -- For now, use a very low hip height
    if Humanoid then
        Humanoid.HipHeight = MovementState.IsProne and 0.1 or
                            (MovementState.IsCrouching and 0.5 or 2.0)
    end
end

-- ===========================================
-- INPUT CONNECTIONS
-- ===========================================

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
        -- Check if we have stamina to jump
        if not Stamina:CanJump() then
            -- Block the jump by setting JumpPower to 0 temporarily
            Humanoid.JumpPower = 0
        else
            Stamina:UseJumpStamina()
            Humanoid.JumpPower = JumpConfig.JumpPower

            -- Crouch jump boost
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
        -- Restore jump power
        Humanoid.JumpPower = JumpConfig.JumpPower
    end
end)

-- ===========================================
-- MOVEMENT DIRECTION DETECTION
-- ===========================================

RunService.RenderStepped:Connect(function(dt)
    -- Detect if moving backward
    local moveDirection = Humanoid.MoveDirection
    if moveDirection.Magnitude > 0.1 then
        local lookVector = RootPart.CFrame.LookVector
        local dot = moveDirection:Dot(lookVector)
        MovementState.IsMovingBackward = dot < -0.5
    else
        MovementState.IsMovingBackward = false
    end

    -- Stop sprint if stamina depleted
    if MovementState.IsSprinting and not Stamina:CanSprint() then
        stopSprint()
    end

    -- Update speed based on current state
    updateMovementSpeed()
end)

-- ===========================================
-- STAMINA UI UPDATES
-- ===========================================

Stamina.OnStaminaChanged.Event:Connect(function(data)
    -- Fire to UI system
    -- TODO: Connect to UI module
    -- print(string.format("Stamina: %.0f/%.0f", data.current, data.max))
end)

Stamina.OnStaminaDepleted.Event:Connect(function()
    -- Force stop sprinting
    stopSprint()
    -- Play exhausted sound/effect
    -- TODO: Add exhaustion effects
end)

-- ===========================================
-- FALL DAMAGE
-- ===========================================

local lastYPosition = RootPart.Position.Y
local isFalling = false
local fallStartY = 0

Humanoid.StateChanged:Connect(function(oldState, newState)
    if newState == Enum.HumanoidStateType.Freefall then
        isFalling = true
        fallStartY = RootPart.Position.Y
    elseif oldState == Enum.HumanoidStateType.Freefall then
        if isFalling then
            local fallDistance = fallStartY - RootPart.Position.Y
            if fallDistance > JumpConfig.FallDamageThreshold then
                local damage = (fallDistance - JumpConfig.FallDamageThreshold) * JumpConfig.FallDamageMultiplier
                -- Send fall damage to server
                local Events = ReplicatedStorage:WaitForChild("Events")
                local DamageEvent = Events:WaitForChild("DamageEvent")
                -- Note: Self-damage for falls is handled server-side
                -- We notify the server of the fall
            end
        end
        isFalling = false
    end
end)

-- ===========================================
-- CHARACTER RESPAWN HANDLING
-- ===========================================

Player.CharacterAdded:Connect(function(newCharacter)
    Character = newCharacter
    Humanoid = Character:WaitForChild("Humanoid")
    RootPart = Character:WaitForChild("HumanoidRootPart")

    -- Reset states
    MovementState.IsSprinting = false
    MovementState.IsCrouching = false
    MovementState.IsProne = false
    MovementState.IsADS = false
    MovementState.LeanDirection = 0

    -- Reset stamina
    Stamina:Reset()

    updateMovementSpeed()
end)

-- ===========================================
-- PUBLIC API (for other scripts)
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

-- Store in ReplicatedStorage for access by other scripts
local controllerValue = Instance.new("ObjectValue")
controllerValue.Name = "MovementController"
controllerValue.Parent = Player:WaitForChild("PlayerScripts")

-- Make API accessible
_G.MovementController = MovementController

print("[MovementController] Client initialized")
