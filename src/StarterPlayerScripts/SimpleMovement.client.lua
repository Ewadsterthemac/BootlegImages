--[[
    SimpleMovement.client.lua
    Standalone movement script - no dependencies
    Location: StarterPlayerScripts/SimpleMovement
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer

-- ===========================================
-- SETTINGS (edit these directly)
-- ===========================================
local WALK_SPEED = 16
local SPRINT_SPEED = 28
local CROUCH_SPEED = 8

local MAX_STAMINA = 100
local SPRINT_DRAIN = 12        -- per second
local STAMINA_REGEN = 20       -- per second
local MIN_SPRINT_STAMINA = 10

-- ===========================================
-- STATE
-- ===========================================
local currentStamina = MAX_STAMINA
local isSprinting = false
local isCrouching = false
local sprintKeyDown = false

-- ===========================================
-- GET CHARACTER REFERENCES
-- ===========================================
local function getCharacter()
    local character = Player.Character
    if not character then return nil, nil end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    return character, humanoid
end

-- ===========================================
-- SPRINT LOGIC
-- ===========================================
local function updateSpeed()
    local character, humanoid = getCharacter()
    if not humanoid then return end

    if isSprinting and currentStamina > 0 then
        humanoid.WalkSpeed = SPRINT_SPEED
    elseif isCrouching then
        humanoid.WalkSpeed = CROUCH_SPEED
    else
        humanoid.WalkSpeed = WALK_SPEED
    end
end

local function startSprint()
    if currentStamina >= MIN_SPRINT_STAMINA and not isCrouching then
        isSprinting = true
        updateSpeed()
        print("[Movement] Sprint ON - Stamina:", math.floor(currentStamina))
    end
end

local function stopSprint()
    isSprinting = false
    updateSpeed()
    print("[Movement] Sprint OFF - Stamina:", math.floor(currentStamina))
end

local function toggleCrouch()
    isCrouching = not isCrouching
    if isCrouching then
        isSprinting = false
    end
    updateSpeed()
    print("[Movement] Crouch:", isCrouching)
end

-- ===========================================
-- INPUT HANDLING
-- ===========================================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if input.KeyCode == Enum.KeyCode.LeftShift then
        sprintKeyDown = true
        startSprint()
    elseif input.KeyCode == Enum.KeyCode.LeftControl then
        toggleCrouch()
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if input.KeyCode == Enum.KeyCode.LeftShift then
        sprintKeyDown = false
        stopSprint()
    end
end)

-- ===========================================
-- STAMINA UPDATE LOOP
-- ===========================================
RunService.Heartbeat:Connect(function(dt)
    local character, humanoid = getCharacter()
    if not humanoid then return end

    -- Drain stamina while sprinting
    if isSprinting and humanoid.MoveDirection.Magnitude > 0.1 then
        currentStamina = math.max(0, currentStamina - SPRINT_DRAIN * dt)

        -- Stop sprint if out of stamina
        if currentStamina <= 0 then
            stopSprint()
        end
    else
        -- Regenerate stamina when not sprinting
        if not isSprinting then
            currentStamina = math.min(MAX_STAMINA, currentStamina + STAMINA_REGEN * dt)
        end
    end

    -- Re-enable sprint if key still held and stamina recovered
    if sprintKeyDown and not isSprinting and currentStamina >= MIN_SPRINT_STAMINA then
        startSprint()
    end
end)

-- ===========================================
-- CHARACTER RESPAWN
-- ===========================================
Player.CharacterAdded:Connect(function(newCharacter)
    currentStamina = MAX_STAMINA
    isSprinting = false
    isCrouching = false

    -- Wait for humanoid and set initial speed
    local humanoid = newCharacter:WaitForChild("Humanoid")
    humanoid.WalkSpeed = WALK_SPEED

    print("[Movement] Character loaded - Ready")
end)

-- Initial setup
local character, humanoid = getCharacter()
if humanoid then
    humanoid.WalkSpeed = WALK_SPEED
end

print("[Movement] SimpleMovement loaded - Hold SHIFT to sprint, CTRL to crouch")
