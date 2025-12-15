--[[
    PlayerController.server.lua
    Server-side player management and validation
    Location: ServerScriptService/PlayerController

    This script handles:
    - Player join/leave events
    - Health/damage on the server (authoritative)
    - Movement validation
    - Data persistence hooks
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

-- Wait for modules to load
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Config = ReplicatedStorage:WaitForChild("Config")

local HealthSystem = require(Modules:WaitForChild("HealthSystem"))
local GameConfig = require(Config:WaitForChild("GameConfig"))

-- ===========================================
-- REMOTE EVENTS SETUP
-- ===========================================
local Events = ReplicatedStorage:FindFirstChild("Events") or Instance.new("Folder")
Events.Name = "Events"
Events.Parent = ReplicatedStorage

-- Create RemoteEvents
local function createRemoteEvent(name: string): RemoteEvent
    local event = Events:FindFirstChild(name)
    if not event then
        event = Instance.new("RemoteEvent")
        event.Name = name
        event.Parent = Events
    end
    return event
end

local function createRemoteFunction(name: string): RemoteFunction
    local func = Events:FindFirstChild(name)
    if not func then
        func = Instance.new("RemoteFunction")
        func.Name = name
        func.Parent = Events
    end
    return func
end

-- Remote Events
local DamageEvent = createRemoteEvent("DamageEvent")
local HealthUpdateEvent = createRemoteEvent("HealthUpdateEvent")
local StaminaUpdateEvent = createRemoteEvent("StaminaUpdateEvent")
local StatusEffectEvent = createRemoteEvent("StatusEffectEvent")
local DeathEvent = createRemoteEvent("DeathEvent")
local RespawnEvent = createRemoteEvent("RespawnEvent")
local MovementValidationEvent = createRemoteEvent("MovementValidation")

-- Remote Functions
local GetPlayerDataFunction = createRemoteFunction("GetPlayerData")

-- ===========================================
-- PLAYER DATA STORAGE
-- ===========================================
local PlayerData = {} -- [Player] = { health, stamina, inventory, etc. }
local PlayerHealthSystems = {} -- [Player] = HealthSystem instance

-- ===========================================
-- PLAYER MANAGEMENT
-- ===========================================

--[[
    Initializes a player when they join
    @param player: Player
]]
local function initializePlayer(player: Player)
    print("[PlayerController] Initializing player:", player.Name)

    -- Create player data entry
    PlayerData[player] = {
        isInRaid = false,
        spawnTime = 0,
        kills = 0,
        deaths = 0,
        extractionCount = 0,
    }

    -- Wait for character
    player.CharacterAdded:Connect(function(character)
        onCharacterAdded(player, character)
    end)

    -- Handle existing character
    if player.Character then
        onCharacterAdded(player, player.Character)
    end
end

--[[
    Called when a player's character spawns
    @param player: Player
    @param character: Model
]]
function onCharacterAdded(player: Player, character: Model)
    print("[PlayerController] Character added for:", player.Name)

    -- Wait for humanoid
    local humanoid = character:WaitForChild("Humanoid", 10)
    if not humanoid then
        warn("[PlayerController] Humanoid not found for:", player.Name)
        return
    end

    -- Create health system for this player
    local healthSystem = HealthSystem.new(player)
    PlayerHealthSystems[player] = healthSystem

    -- Connect health system events
    healthSystem.OnDamaged.Event:Connect(function(data)
        -- Send health update to client
        HealthUpdateEvent:FireClient(player, {
            health = healthSystem.CurrentHealth,
            maxHealth = healthSystem.MaxHealth,
            damage = data.damage,
            bodyPart = data.bodyPart,
        })

        -- Update Roblox humanoid health (for death handling)
        humanoid.Health = healthSystem.CurrentHealth
    end)

    healthSystem.OnHealed.Event:Connect(function(data)
        HealthUpdateEvent:FireClient(player, {
            health = healthSystem.CurrentHealth,
            maxHealth = healthSystem.MaxHealth,
            healed = data.amount,
        })
        humanoid.Health = healthSystem.CurrentHealth
    end)

    healthSystem.OnStatusEffectChanged.Event:Connect(function(data)
        StatusEffectEvent:FireClient(player, data)
    end)

    healthSystem.OnDeath.Event:Connect(function(data)
        onPlayerDeath(player, data.killer, data.damageType)
    end)

    -- Configure humanoid
    humanoid.MaxHealth = GameConfig.Player.Health.MaxHealth
    humanoid.Health = GameConfig.Player.Health.MaxHealth
    humanoid.WalkSpeed = GameConfig.Player.Movement.WalkSpeed
    humanoid.JumpPower = GameConfig.Player.Jump.JumpPower

    -- Disable default Roblox damage
    humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)

    -- Handle humanoid death (fallback)
    humanoid.Died:Connect(function()
        if healthSystem.IsAlive then
            healthSystem:TakeDamage(healthSystem.CurrentHealth, nil, nil, "killed")
        end
    end)

    -- Set up hit detection on body parts
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            setupHitDetection(player, part)
        end
    end
end

--[[
    Sets up hit detection on a body part
    @param player: Player - Owner of this body part
    @param part: BasePart - The body part
]]
function setupHitDetection(player: Player, part: BasePart)
    -- Tag the part with the owner for damage attribution
    local ownerTag = Instance.new("ObjectValue")
    ownerTag.Name = "OwnerPlayer"
    ownerTag.Value = player
    ownerTag.Parent = part
end

--[[
    Handles player death
    @param player: Player
    @param killer: Player?
    @param damageType: string
]]
function onPlayerDeath(player: Player, killer: Player?, damageType: string)
    print("[PlayerController] Player died:", player.Name, "by", damageType)

    -- Update stats
    if PlayerData[player] then
        PlayerData[player].deaths = PlayerData[player].deaths + 1
    end

    -- Credit kill to killer
    if killer and killer ~= player and PlayerData[killer] then
        PlayerData[killer].kills = PlayerData[killer].kills + 1
    end

    -- Notify client
    DeathEvent:FireClient(player, {
        killer = killer and killer.Name or nil,
        damageType = damageType,
    })

    -- Kill the humanoid
    local character = player.Character
    if character then
        local humanoid = character:FindFirstChild("Humanoid")
        if humanoid then
            humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, true)
            humanoid.Health = 0
        end
    end

    -- TODO: Handle loot dropping, inventory loss, etc.
end

--[[
    Cleans up when player leaves
    @param player: Player
]]
local function cleanupPlayer(player: Player)
    print("[PlayerController] Cleaning up player:", player.Name)

    -- Destroy health system
    if PlayerHealthSystems[player] then
        PlayerHealthSystems[player]:Destroy()
        PlayerHealthSystems[player] = nil
    end

    -- Clear player data
    PlayerData[player] = nil
end

-- ===========================================
-- DAMAGE HANDLING
-- ===========================================

--[[
    Processes damage from client (with validation)
    Called via RemoteEvent from weapon systems
]]
DamageEvent.OnServerEvent:Connect(function(attacker: Player, targetPart: BasePart, damage: number, weaponData: table?)
    -- Validate inputs
    if not targetPart or not targetPart:IsA("BasePart") then return end
    if type(damage) ~= "number" or damage <= 0 or damage > 1000 then return end

    -- Get target player from hit part
    local ownerTag = targetPart:FindFirstChild("OwnerPlayer")
    if not ownerTag or not ownerTag.Value then return end

    local targetPlayer = ownerTag.Value
    if not targetPlayer:IsA("Player") then return end

    -- Prevent self-damage (optional - remove for friendly fire)
    if targetPlayer == attacker then return end

    -- Validate distance (anti-cheat)
    local attackerCharacter = attacker.Character
    if attackerCharacter then
        local attackerRoot = attackerCharacter:FindFirstChild("HumanoidRootPart")
        if attackerRoot then
            local distance = (attackerRoot.Position - targetPart.Position).Magnitude
            if distance > GameConfig.Combat.MaxBulletDistance then
                warn("[PlayerController] Suspicious damage distance from:", attacker.Name)
                return
            end
        end
    end

    -- Get health system and apply damage
    local healthSystem = PlayerHealthSystems[targetPlayer]
    if not healthSystem then return end

    -- Determine body part
    local bodyPart = HealthSystem.GetBodyPartFromName(targetPart.Name)

    -- Get armor class from target (TODO: implement armor inventory)
    local armorClass = 0

    -- Calculate and apply damage
    local finalDamage = healthSystem:CalculateDamage(damage, bodyPart, armorClass, weaponData and weaponData.penetration)
    healthSystem:TakeDamage(finalDamage, bodyPart, attacker, "bullet")

    print(string.format("[Damage] %s -> %s: %d damage to %s",
        attacker.Name, targetPlayer.Name, finalDamage, bodyPart))
end)

-- ===========================================
-- MOVEMENT VALIDATION
-- ===========================================

local LastKnownPositions = {} -- [Player] = {position, timestamp}

--[[
    Validates player movement (anti-cheat)
    Called periodically from client
]]
MovementValidationEvent.OnServerEvent:Connect(function(player: Player, position: Vector3, timestamp: number)
    if not player.Character then return end

    local root = player.Character:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local lastData = LastKnownPositions[player]
    local currentTime = tick()

    if lastData then
        local timeDelta = currentTime - lastData.timestamp
        local distance = (position - lastData.position).Magnitude
        local maxSpeed = GameConfig.Player.Movement.SprintSpeed * 1.5 -- Allow some tolerance

        local maxPossibleDistance = maxSpeed * timeDelta + GameConfig.Network.PositionTolerance

        if distance > maxPossibleDistance then
            warn("[Anti-Cheat] Suspicious movement from:", player.Name,
                "Distance:", distance, "Max:", maxPossibleDistance)
            -- TODO: Implement punishment (teleport back, kick, etc.)
        end
    end

    LastKnownPositions[player] = {
        position = position,
        timestamp = currentTime,
    }
end)

-- ===========================================
-- REMOTE FUNCTIONS
-- ===========================================

--[[
    Returns player data to client
]]
GetPlayerDataFunction.OnServerInvoke = function(player: Player)
    local healthSystem = PlayerHealthSystems[player]
    local data = PlayerData[player]

    return {
        health = healthSystem and healthSystem.CurrentHealth or 100,
        maxHealth = healthSystem and healthSystem.MaxHealth or 100,
        isAlive = healthSystem and healthSystem.IsAlive or true,
        bleeding = healthSystem and healthSystem.BleedingStacks or 0,
        fractures = healthSystem and healthSystem.IsFractured or {},
        stats = data and {
            kills = data.kills,
            deaths = data.deaths,
            extractions = data.extractionCount,
        } or {},
    }
end

-- ===========================================
-- BLEEDING TICK PROCESSING
-- ===========================================

-- Process bleeding damage every second
local bleedTickTime = 0
RunService.Heartbeat:Connect(function(dt)
    bleedTickTime = bleedTickTime + dt
    if bleedTickTime >= 1.0 then
        bleedTickTime = 0

        for player, healthSystem in pairs(PlayerHealthSystems) do
            if healthSystem.IsAlive then
                healthSystem:_processBleedingTick()
            end
        end
    end
end)

-- ===========================================
-- INITIALIZATION
-- ===========================================

-- Connect player events
Players.PlayerAdded:Connect(initializePlayer)
Players.PlayerRemoving:Connect(cleanupPlayer)

-- Initialize existing players (for Studio testing)
for _, player in ipairs(Players:GetPlayers()) do
    task.spawn(initializePlayer, player)
end

print("[PlayerController] Server initialized")
