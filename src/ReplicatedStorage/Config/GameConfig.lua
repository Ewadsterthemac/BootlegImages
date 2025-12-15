--[[
    GameConfig.lua
    Central configuration for all game systems
    Location: ReplicatedStorage/Config/GameConfig
]]

local GameConfig = {}

-- ===========================================
-- PLAYER SETTINGS
-- ===========================================
GameConfig.Player = {
    -- Health Configuration
    Health = {
        MaxHealth = 100,
        HeadMultiplier = 2.0,      -- Headshots deal 2x damage
        TorsoMultiplier = 1.0,
        LimbMultiplier = 0.7,      -- Arms/legs deal reduced damage
        RegenRate = 0,             -- HP per second (0 = no regen)
        RegenDelay = 5,            -- Seconds before regen starts
    },

    -- Stamina Configuration
    Stamina = {
        MaxStamina = 100,
        SprintDrain = 15,          -- Per second while sprinting
        JumpCost = 20,             -- Per jump
        RegenRate = 25,            -- Per second when not using
        RegenDelay = 1,            -- Seconds before regen starts
        MinSprintStamina = 10,     -- Minimum to start sprinting
    },

    -- Movement Speeds (studs per second)
    Movement = {
        WalkSpeed = 12,
        SprintSpeed = 20,
        CrouchSpeed = 6,
        ProneSpeed = 2,
        ADSSpeedMultiplier = 0.7,  -- Speed while aiming
        BackpedalMultiplier = 0.8, -- Moving backwards
    },

    -- Jump Configuration
    Jump = {
        JumpPower = 50,
        CrouchJumpBoost = 1.1,     -- Slightly higher crouch jump
        FallDamageThreshold = 30,  -- Studs before taking damage
        FallDamageMultiplier = 0.5,-- Damage per stud over threshold
    },
}

-- ===========================================
-- CAMERA SETTINGS
-- ===========================================
GameConfig.Camera = {
    -- Field of View
    DefaultFOV = 70,
    SprintFOV = 80,
    ADSFOV = 50,                   -- Overridden by scope
    FOVLerpSpeed = 10,

    -- Camera Positions
    FirstPersonOffset = Vector3.new(0, 0, 0),
    ThirdPersonOffset = Vector3.new(2, 2, 8),

    -- Sensitivity
    BaseSensitivity = 0.5,
    ADSSensitivityMultiplier = 0.5,

    -- Lean System
    LeanAngle = 15,               -- Degrees
    LeanOffset = 1.5,             -- Studs to side
    LeanSpeed = 10,

    -- Head Bob
    HeadBobEnabled = true,
    HeadBobIntensity = 0.03,
    HeadBobSpeed = 10,
    SprintBobMultiplier = 1.5,

    -- Sway
    WeaponSwayAmount = 0.02,
    WeaponSwaySpeed = 3,
    BreathingSwayAmount = 0.01,
}

-- ===========================================
-- COMBAT SETTINGS
-- ===========================================
GameConfig.Combat = {
    -- Hit Registration
    MaxBulletDistance = 1000,
    BulletDropEnabled = false,    -- Enable for snipers
    PenetrationEnabled = true,

    -- Damage Falloff
    FalloffStartRange = 50,
    FalloffEndRange = 150,
    MinDamageMultiplier = 0.5,

    -- Armor
    ArmorClasses = {
        [1] = { protection = 0.10, ricochetChance = 0.05 },
        [2] = { protection = 0.20, ricochetChance = 0.10 },
        [3] = { protection = 0.35, ricochetChance = 0.15 },
        [4] = { protection = 0.50, ricochetChance = 0.20 },
        [5] = { protection = 0.65, ricochetChance = 0.30 },
        [6] = { protection = 0.80, ricochetChance = 0.40 },
    },
}

-- ===========================================
-- RAID SETTINGS
-- ===========================================
GameConfig.Raid = {
    MaxPlayers = 12,
    MinPlayers = 1,
    RaidDuration = 45 * 60,       -- 45 minutes in seconds
    ExtractionTime = 10,          -- Seconds to extract
    LateSpawnWindow = 10 * 60,    -- Can spawn late up to 10 min
    DeployCountdown = 10,         -- Pre-raid countdown
}

-- ===========================================
-- STATUS EFFECTS
-- ===========================================
GameConfig.StatusEffects = {
    Bleeding = {
        DamagePerTick = 2,
        TickInterval = 1,
        MaxStacks = 3,
    },
    Fracture = {
        SpeedReduction = 0.5,
        AimPenalty = 2.0,         -- Sway multiplier
    },
    Pain = {
        BlurIntensity = 0.3,
        TremorAmount = 0.5,
    },
    Dehydration = {
        DamagePerTick = 1,
        TickInterval = 5,
    },
}

-- ===========================================
-- NETWORK SETTINGS
-- ===========================================
GameConfig.Network = {
    TickRate = 20,                -- Server updates per second
    InterpDelay = 0.1,            -- Interpolation buffer
    MaxPing = 300,                -- Kick threshold
    PositionTolerance = 5,        -- Anti-cheat tolerance
}

return GameConfig
