--[[
    WeaponServer.server.lua
    Server-side weapon hit validation and damage application
    Location: ServerScriptService/WeaponServer
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("[WeaponServer] Starting...")

-- Wait for modules
local Config = ReplicatedStorage:WaitForChild("Config")
local WeaponConfig = require(Config:WaitForChild("WeaponConfig"))

-- Get/create events
local Events = ReplicatedStorage:WaitForChild("Events")
local WeaponFireEvent = Events:FindFirstChild("WeaponFire")
if not WeaponFireEvent then
    WeaponFireEvent = Instance.new("RemoteEvent")
    WeaponFireEvent.Name = "WeaponFire"
    WeaponFireEvent.Parent = Events
end

-- ===========================================
-- CONFIGURATION
-- ===========================================
local VALIDATION_CONFIG = {
    maxShootDistance = 1000,        -- Max distance player can shoot
    maxFireRate = 1200,             -- Max RPM allowed (anti-cheat)
    positionTolerance = 10,         -- Tolerance for hit position validation
}

-- Player fire tracking for rate limiting
local PlayerFireTimes = {} -- [Player] = { lastFireTime, fireCount }

-- ===========================================
-- HELPER FUNCTIONS
-- ===========================================

--[[
    Gets the player who owns a body part
    @param part: BasePart
    @return Player?
]]
local function getPlayerFromPart(part: BasePart): Player?
    -- Check for owner tag
    local ownerTag = part:FindFirstChild("OwnerPlayer")
    if ownerTag and ownerTag.Value and ownerTag.Value:IsA("Player") then
        return ownerTag.Value
    end

    -- Check parent hierarchy for player character
    local character = part:FindFirstAncestorOfClass("Model")
    if character then
        local player = Players:GetPlayerFromCharacter(character)
        if player then
            return player
        end
    end

    return nil
end

--[[
    Validates a weapon fire request
    @param attacker: Player
    @param data: table
    @return boolean, string? - Valid, error message
]]
local function validateFire(attacker: Player, data: table): (boolean, string?)
    -- Check attacker has character
    if not attacker.Character then
        return false, "No character"
    end

    local attackerRoot = attacker.Character:FindFirstChild("HumanoidRootPart")
    if not attackerRoot then
        return false, "No root part"
    end

    -- Validate weapon exists
    local weaponConfig = WeaponConfig.GetWeapon(data.weaponId)
    if not weaponConfig then
        return false, "Invalid weapon"
    end

    -- Rate limit check
    local now = tick()
    local fireData = PlayerFireTimes[attacker]
    if fireData then
        local timeSinceLastFire = now - fireData.lastFireTime
        local minFireInterval = 60 / VALIDATION_CONFIG.maxFireRate

        if timeSinceLastFire < minFireInterval then
            fireData.fireCount = fireData.fireCount + 1
            if fireData.fireCount > 10 then
                return false, "Fire rate exceeded"
            end
        else
            fireData.fireCount = 0
        end
        fireData.lastFireTime = now
    else
        PlayerFireTimes[attacker] = {
            lastFireTime = now,
            fireCount = 0
        }
    end

    -- Distance check
    if data.hitPosition then
        local distance = (attackerRoot.Position - data.hitPosition).Magnitude
        if distance > VALIDATION_CONFIG.maxShootDistance then
            return false, "Shot too far"
        end
    end

    return true
end

--[[
    Calculates final damage with modifiers
    @param baseDamage: number
    @param hitPart: BasePart
    @param weaponConfig: table
    @param distance: number
    @return number
]]
local function calculateDamage(baseDamage: number, hitPart: BasePart, weaponConfig: table, distance: number): number
    local damage = baseDamage

    -- Headshot multiplier
    if hitPart.Name == "Head" then
        damage = damage * weaponConfig.headshotMultiplier
    end

    -- Distance falloff
    if distance > weaponConfig.effectiveRange then
        local falloffRange = weaponConfig.maxRange - weaponConfig.effectiveRange
        local falloffProgress = math.min(1, (distance - weaponConfig.effectiveRange) / falloffRange)
        local falloffMultiplier = 1 - (1 - weaponConfig.damageDropoff) * falloffProgress
        damage = damage * falloffMultiplier
    end

    return math.floor(damage)
end

-- ===========================================
-- WEAPON FIRE HANDLER
-- ===========================================

WeaponFireEvent.OnServerEvent:Connect(function(attacker: Player, data: table)
    -- Validate request
    local valid, errorMsg = validateFire(attacker, data)
    if not valid then
        warn("[WeaponServer] Invalid fire from", attacker.Name, ":", errorMsg)
        return
    end

    -- Get weapon config
    local weaponConfig = WeaponConfig.GetWeapon(data.weaponId)
    if not weaponConfig then return end

    -- Check if hit part exists
    local hitPart = data.hitPart
    if not hitPart or not hitPart:IsA("BasePart") then
        return -- Missed shot, no damage
    end

    -- Get target player
    local targetPlayer = getPlayerFromPart(hitPart)
    if not targetPlayer then
        -- Hit world geometry, not a player
        return
    end

    -- Don't allow self-damage
    if targetPlayer == attacker then
        return
    end

    -- Get target character
    local targetCharacter = targetPlayer.Character
    if not targetCharacter then return end

    local targetHumanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
    if not targetHumanoid or targetHumanoid.Health <= 0 then return end

    -- Calculate distance
    local attackerRoot = attacker.Character:FindFirstChild("HumanoidRootPart")
    local distance = attackerRoot and (attackerRoot.Position - data.hitPosition).Magnitude or 0

    -- Calculate final damage
    local finalDamage = calculateDamage(weaponConfig.damage, hitPart, weaponConfig, distance)

    -- Apply damage
    targetHumanoid:TakeDamage(finalDamage)

    -- Log hit
    local hitType = hitPart.Name == "Head" and "HEADSHOT" or "hit"
    print(string.format("[WeaponServer] %s %s %s for %d damage (%s)",
        attacker.Name, hitType, targetPlayer.Name, finalDamage, weaponConfig.displayName))

    -- Check for kill
    if targetHumanoid.Health <= 0 then
        print(string.format("[WeaponServer] %s killed %s with %s",
            attacker.Name, targetPlayer.Name, weaponConfig.displayName))

        -- TODO: Fire kill event for killfeed, stats, etc.
    end
end)

-- ===========================================
-- CLEANUP
-- ===========================================

Players.PlayerRemoving:Connect(function(player)
    PlayerFireTimes[player] = nil
end)

print("[WeaponServer] ✓ Initialized")
