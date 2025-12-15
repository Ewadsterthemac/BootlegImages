--[[
    HealthSystem.lua
    Manages player health, damage, and healing
    Location: ReplicatedStorage/Modules/HealthSystem
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("GameConfig"))
local HealthConfig = Config.Player.Health

local HealthSystem = {}
HealthSystem.__index = HealthSystem

-- Body part enum
HealthSystem.BodyPart = {
    Head = "Head",
    Torso = "Torso",
    LeftArm = "LeftArm",
    RightArm = "RightArm",
    LeftLeg = "LeftLeg",
    RightLeg = "RightLeg",
}

-- Map Roblox body parts to our system
local BODY_PART_MAP = {
    ["Head"] = HealthSystem.BodyPart.Head,
    ["UpperTorso"] = HealthSystem.BodyPart.Torso,
    ["LowerTorso"] = HealthSystem.BodyPart.Torso,
    ["HumanoidRootPart"] = HealthSystem.BodyPart.Torso,
    ["LeftUpperArm"] = HealthSystem.BodyPart.LeftArm,
    ["LeftLowerArm"] = HealthSystem.BodyPart.LeftArm,
    ["LeftHand"] = HealthSystem.BodyPart.LeftArm,
    ["RightUpperArm"] = HealthSystem.BodyPart.RightArm,
    ["RightLowerArm"] = HealthSystem.BodyPart.RightArm,
    ["RightHand"] = HealthSystem.BodyPart.RightArm,
    ["LeftUpperLeg"] = HealthSystem.BodyPart.LeftLeg,
    ["LeftLowerLeg"] = HealthSystem.BodyPart.LeftLeg,
    ["LeftFoot"] = HealthSystem.BodyPart.LeftLeg,
    ["RightUpperLeg"] = HealthSystem.BodyPart.RightLeg,
    ["RightLowerLeg"] = HealthSystem.BodyPart.RightLeg,
    ["RightFoot"] = HealthSystem.BodyPart.RightLeg,
}

-- Damage multipliers by body part
local DAMAGE_MULTIPLIERS = {
    [HealthSystem.BodyPart.Head] = HealthConfig.HeadMultiplier,
    [HealthSystem.BodyPart.Torso] = HealthConfig.TorsoMultiplier,
    [HealthSystem.BodyPart.LeftArm] = HealthConfig.LimbMultiplier,
    [HealthSystem.BodyPart.RightArm] = HealthConfig.LimbMultiplier,
    [HealthSystem.BodyPart.LeftLeg] = HealthConfig.LimbMultiplier,
    [HealthSystem.BodyPart.RightLeg] = HealthConfig.LimbMultiplier,
}

--[[
    Creates a new HealthSystem instance for a player
    @param player: Player - The player this system belongs to
    @return HealthSystem
]]
function HealthSystem.new(player: Player)
    local self = setmetatable({}, HealthSystem)

    self.Player = player
    self.MaxHealth = HealthConfig.MaxHealth
    self.CurrentHealth = HealthConfig.MaxHealth
    self.IsAlive = true

    -- Status effects
    self.BleedingStacks = 0
    self.IsFractured = {
        LeftArm = false,
        RightArm = false,
        LeftLeg = false,
        RightLeg = false,
    }
    self.PainLevel = 0

    -- Regen tracking
    self.LastDamageTime = 0
    self.RegenConnection = nil

    -- Events (BindableEvents for single-script, RemoteEvents for network)
    self.OnDamaged = Instance.new("BindableEvent")
    self.OnHealed = Instance.new("BindableEvent")
    self.OnDeath = Instance.new("BindableEvent")
    self.OnStatusEffectChanged = Instance.new("BindableEvent")

    -- Start regen loop if enabled
    if HealthConfig.RegenRate > 0 then
        self:_startRegenLoop()
    end

    return self
end

--[[
    Gets the body part category from a Roblox part name
    @param partName: string - The name of the body part hit
    @return string - The body part category
]]
function HealthSystem.GetBodyPartFromName(partName: string): string
    return BODY_PART_MAP[partName] or HealthSystem.BodyPart.Torso
end

--[[
    Calculates damage after applying body part multipliers and armor
    @param baseDamage: number - Raw damage amount
    @param bodyPart: string - Body part hit
    @param armorClass: number? - Armor class (1-6) or nil for no armor
    @param penetration: number? - Bullet penetration value
    @return number - Final damage amount
]]
function HealthSystem:CalculateDamage(baseDamage: number, bodyPart: string, armorClass: number?, penetration: number?): number
    -- Apply body part multiplier
    local multiplier = DAMAGE_MULTIPLIERS[bodyPart] or 1.0
    local damage = baseDamage * multiplier

    -- Apply armor reduction
    if armorClass and armorClass > 0 and Config.Combat.ArmorClasses[armorClass] then
        local armorData = Config.Combat.ArmorClasses[armorClass]
        local protection = armorData.protection

        -- Penetration reduces armor effectiveness
        if penetration then
            protection = protection * math.max(0, 1 - (penetration / 100))
        end

        -- Check for ricochet (complete damage negation)
        if math.random() < armorData.ricochetChance then
            return 0
        end

        damage = damage * (1 - protection)
    end

    return math.floor(damage)
end

--[[
    Applies damage to the player
    @param amount: number - Damage amount
    @param bodyPart: string? - Body part hit (for multipliers)
    @param source: Player? - Who dealt the damage
    @param damageType: string? - Type of damage (bullet, fall, bleed, etc.)
    @return number - Actual damage dealt
]]
function HealthSystem:TakeDamage(amount: number, bodyPart: string?, source: Player?, damageType: string?): number
    if not self.IsAlive then return 0 end

    bodyPart = bodyPart or HealthSystem.BodyPart.Torso
    damageType = damageType or "generic"

    -- Calculate final damage
    local finalDamage = math.min(amount, self.CurrentHealth)

    -- Apply damage
    self.CurrentHealth = math.max(0, self.CurrentHealth - finalDamage)
    self.LastDamageTime = tick()

    -- Fire damaged event
    self.OnDamaged:Fire({
        damage = finalDamage,
        bodyPart = bodyPart,
        source = source,
        damageType = damageType,
        remainingHealth = self.CurrentHealth,
    })

    -- Apply status effects based on body part
    self:_applyDamageEffects(bodyPart, finalDamage, damageType)

    -- Check for death
    if self.CurrentHealth <= 0 then
        self:_onDeath(source, damageType)
    end

    return finalDamage
end

--[[
    Heals the player
    @param amount: number - Heal amount
    @param healType: string? - Type of healing (medkit, surgery, etc.)
    @return number - Actual amount healed
]]
function HealthSystem:Heal(amount: number, healType: string?): number
    if not self.IsAlive then return 0 end

    healType = healType or "generic"

    local actualHeal = math.min(amount, self.MaxHealth - self.CurrentHealth)
    self.CurrentHealth = self.CurrentHealth + actualHeal

    -- Fire healed event
    self.OnHealed:Fire({
        amount = actualHeal,
        healType = healType,
        currentHealth = self.CurrentHealth,
    })

    return actualHeal
end

--[[
    Adds bleeding stacks to the player
    @param stacks: number - Number of stacks to add
]]
function HealthSystem:AddBleeding(stacks: number)
    if not self.IsAlive then return end

    local maxStacks = Config.StatusEffects.Bleeding.MaxStacks
    local oldStacks = self.BleedingStacks
    self.BleedingStacks = math.min(self.BleedingStacks + stacks, maxStacks)

    if self.BleedingStacks ~= oldStacks then
        self.OnStatusEffectChanged:Fire({
            effect = "Bleeding",
            value = self.BleedingStacks,
        })
    end
end

--[[
    Removes bleeding stacks (from bandages, etc.)
    @param stacks: number - Number of stacks to remove
]]
function HealthSystem:RemoveBleeding(stacks: number)
    local oldStacks = self.BleedingStacks
    self.BleedingStacks = math.max(0, self.BleedingStacks - stacks)

    if self.BleedingStacks ~= oldStacks then
        self.OnStatusEffectChanged:Fire({
            effect = "Bleeding",
            value = self.BleedingStacks,
        })
    end
end

--[[
    Sets a limb as fractured
    @param limb: string - The limb to fracture
]]
function HealthSystem:ApplyFracture(limb: string)
    if not self.IsAlive then return end
    if self.IsFractured[limb] == nil then return end

    if not self.IsFractured[limb] then
        self.IsFractured[limb] = true
        self.OnStatusEffectChanged:Fire({
            effect = "Fracture",
            limb = limb,
            value = true,
        })
    end
end

--[[
    Heals a fractured limb (from splint, surgery, etc.)
    @param limb: string - The limb to heal
]]
function HealthSystem:HealFracture(limb: string)
    if self.IsFractured[limb] then
        self.IsFractured[limb] = false
        self.OnStatusEffectChanged:Fire({
            effect = "Fracture",
            limb = limb,
            value = false,
        })
    end
end

--[[
    Checks if player has any leg fractures (affects movement)
    @return boolean
]]
function HealthSystem:HasLegFracture(): boolean
    return self.IsFractured.LeftLeg or self.IsFractured.RightLeg
end

--[[
    Checks if player has any arm fractures (affects aiming)
    @return boolean
]]
function HealthSystem:HasArmFracture(): boolean
    return self.IsFractured.LeftArm or self.IsFractured.RightArm
end

--[[
    Gets the current health percentage
    @return number - Health as percentage (0-1)
]]
function HealthSystem:GetHealthPercent(): number
    return self.CurrentHealth / self.MaxHealth
end

--[[
    Processes bleeding damage tick
    Called internally by the regen/damage loop
]]
function HealthSystem:_processBleedingTick()
    if self.BleedingStacks > 0 and self.IsAlive then
        local bleedConfig = Config.StatusEffects.Bleeding
        local damage = bleedConfig.DamagePerTick * self.BleedingStacks
        self:TakeDamage(damage, nil, nil, "bleeding")
    end
end

--[[
    Applies status effects based on damage taken
    @param bodyPart: string - Body part hit
    @param damage: number - Damage amount
    @param damageType: string - Type of damage
]]
function HealthSystem:_applyDamageEffects(bodyPart: string, damage: number, damageType: string)
    -- Bullets can cause bleeding
    if damageType == "bullet" and damage > 10 then
        local bleedChance = damage / 100
        if math.random() < bleedChance then
            self:AddBleeding(1)
        end
    end

    -- High damage to limbs can cause fractures
    if damage > 30 then
        if bodyPart == HealthSystem.BodyPart.LeftLeg then
            if math.random() < 0.3 then self:ApplyFracture("LeftLeg") end
        elseif bodyPart == HealthSystem.BodyPart.RightLeg then
            if math.random() < 0.3 then self:ApplyFracture("RightLeg") end
        elseif bodyPart == HealthSystem.BodyPart.LeftArm then
            if math.random() < 0.3 then self:ApplyFracture("LeftArm") end
        elseif bodyPart == HealthSystem.BodyPart.RightArm then
            if math.random() < 0.3 then self:ApplyFracture("RightArm") end
        end
    end
end

--[[
    Starts the health regeneration loop
]]
function HealthSystem:_startRegenLoop()
    self.RegenConnection = RunService.Heartbeat:Connect(function(dt)
        if not self.IsAlive then return end

        -- Check if enough time has passed since last damage
        local timeSinceDamage = tick() - self.LastDamageTime
        if timeSinceDamage >= HealthConfig.RegenDelay then
            -- Apply regeneration
            if self.CurrentHealth < self.MaxHealth then
                local regenAmount = HealthConfig.RegenRate * dt
                self:Heal(regenAmount, "regen")
            end
        end
    end)
end

--[[
    Handles player death
    @param killer: Player? - Who killed this player
    @param damageType: string - What killed them
]]
function HealthSystem:_onDeath(killer: Player?, damageType: string)
    self.IsAlive = false

    -- Stop regen
    if self.RegenConnection then
        self.RegenConnection:Disconnect()
        self.RegenConnection = nil
    end

    -- Fire death event
    self.OnDeath:Fire({
        killer = killer,
        damageType = damageType,
    })
end

--[[
    Resets the health system (for respawning)
]]
function HealthSystem:Reset()
    self.CurrentHealth = self.MaxHealth
    self.IsAlive = true
    self.BleedingStacks = 0
    self.PainLevel = 0
    self.LastDamageTime = 0

    for limb, _ in pairs(self.IsFractured) do
        self.IsFractured[limb] = false
    end

    if HealthConfig.RegenRate > 0 and not self.RegenConnection then
        self:_startRegenLoop()
    end
end

--[[
    Cleans up the health system
]]
function HealthSystem:Destroy()
    if self.RegenConnection then
        self.RegenConnection:Disconnect()
    end

    self.OnDamaged:Destroy()
    self.OnHealed:Destroy()
    self.OnDeath:Destroy()
    self.OnStatusEffectChanged:Destroy()
end

return HealthSystem
