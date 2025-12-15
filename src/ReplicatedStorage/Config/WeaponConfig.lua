--[[
    WeaponConfig.lua
    Modular weapon configuration system
    Location: ReplicatedStorage/Config/WeaponConfig

    To add a new weapon:
    1. Copy an existing weapon template
    2. Adjust the stats
    3. Reference it by name in the weapon system
]]

local WeaponConfig = {}

-- ===========================================
-- WEAPON TEMPLATES (base stats to inherit from)
-- ===========================================
WeaponConfig.Templates = {
    AssaultRifle = {
        weaponType = "Primary",
        fireMode = "Auto",          -- Auto, Semi, Burst
        damage = 30,
        headshotMultiplier = 2.0,
        fireRate = 600,             -- Rounds per minute
        magSize = 30,
        reserveAmmo = 120,
        reloadTime = 2.5,

        -- Accuracy
        baseSpread = 0.5,           -- Degrees
        maxSpread = 4.0,
        spreadIncreasePerShot = 0.3,
        spreadRecoveryRate = 5.0,   -- Degrees per second
        adsSpreadMultiplier = 0.3,

        -- Recoil
        recoilVertical = 1.5,       -- Degrees per shot
        recoilHorizontal = 0.4,     -- Random range +/-
        recoilRecoverySpeed = 8.0,  -- How fast crosshair returns

        -- ADS
        adsTime = 0.25,             -- Seconds to aim
        adsZoom = 1.2,              -- FOV multiplier (lower = more zoom)

        -- Movement
        moveSpeedMultiplier = 0.9,
        adsSpeedMultiplier = 0.7,

        -- Range
        effectiveRange = 100,       -- Full damage up to this range
        maxRange = 500,             -- Bullet disappears after this
        damageDropoff = 0.5,        -- Minimum damage multiplier at max range

        -- Penetration
        penetration = 30,           -- Armor penetration value (0-100)

        -- Audio/Visual
        fireSound = "rbxassetid://0", -- Replace with actual sound ID
        reloadSound = "rbxassetid://0",
        equipSound = "rbxassetid://0",
        muzzleFlash = true,
        tracerEnabled = true,
        tracerColor = Color3.fromRGB(255, 200, 100),
        tracerSpeed = 500,          -- Studs per second (visual only)
    },

    SMG = {
        weaponType = "Primary",
        fireMode = "Auto",
        damage = 22,
        headshotMultiplier = 1.8,
        fireRate = 900,
        magSize = 25,
        reserveAmmo = 150,
        reloadTime = 2.0,

        baseSpread = 0.8,
        maxSpread = 5.0,
        spreadIncreasePerShot = 0.25,
        spreadRecoveryRate = 7.0,
        adsSpreadMultiplier = 0.4,

        recoilVertical = 0.8,
        recoilHorizontal = 0.6,
        recoilRecoverySpeed = 10.0,

        adsTime = 0.2,
        adsZoom = 1.1,

        moveSpeedMultiplier = 0.95,
        adsSpeedMultiplier = 0.8,

        effectiveRange = 50,
        maxRange = 200,
        damageDropoff = 0.4,

        penetration = 15,

        fireSound = "rbxassetid://0",
        reloadSound = "rbxassetid://0",
        equipSound = "rbxassetid://0",
        muzzleFlash = true,
        tracerEnabled = true,
        tracerColor = Color3.fromRGB(255, 220, 150),
        tracerSpeed = 450,
    },

    Pistol = {
        weaponType = "Secondary",
        fireMode = "Semi",
        damage = 35,
        headshotMultiplier = 2.0,
        fireRate = 400,
        magSize = 12,
        reserveAmmo = 60,
        reloadTime = 1.5,

        baseSpread = 0.3,
        maxSpread = 3.0,
        spreadIncreasePerShot = 0.5,
        spreadRecoveryRate = 6.0,
        adsSpreadMultiplier = 0.25,

        recoilVertical = 2.5,
        recoilHorizontal = 0.3,
        recoilRecoverySpeed = 6.0,

        adsTime = 0.15,
        adsZoom = 1.15,

        moveSpeedMultiplier = 1.0,
        adsSpeedMultiplier = 0.9,

        effectiveRange = 40,
        maxRange = 150,
        damageDropoff = 0.5,

        penetration = 20,

        fireSound = "rbxassetid://0",
        reloadSound = "rbxassetid://0",
        equipSound = "rbxassetid://0",
        muzzleFlash = true,
        tracerEnabled = true,
        tracerColor = Color3.fromRGB(255, 200, 100),
        tracerSpeed = 400,
    },

    Shotgun = {
        weaponType = "Primary",
        fireMode = "Semi",
        damage = 15,                -- Per pellet
        pelletCount = 8,
        headshotMultiplier = 1.5,
        fireRate = 70,
        magSize = 6,
        reserveAmmo = 36,
        reloadTime = 0.5,           -- Per shell
        reloadType = "Single",      -- Single shell reload

        baseSpread = 3.0,
        maxSpread = 5.0,
        spreadIncreasePerShot = 0,
        spreadRecoveryRate = 0,
        adsSpreadMultiplier = 0.7,
        pelletSpread = 4.0,         -- Additional spread per pellet

        recoilVertical = 5.0,
        recoilHorizontal = 1.0,
        recoilRecoverySpeed = 4.0,

        adsTime = 0.3,
        adsZoom = 1.1,

        moveSpeedMultiplier = 0.85,
        adsSpeedMultiplier = 0.65,

        effectiveRange = 20,
        maxRange = 50,
        damageDropoff = 0.2,

        penetration = 5,

        fireSound = "rbxassetid://0",
        reloadSound = "rbxassetid://0",
        equipSound = "rbxassetid://0",
        muzzleFlash = true,
        tracerEnabled = false,
    },

    SniperRifle = {
        weaponType = "Primary",
        fireMode = "Semi",
        damage = 90,
        headshotMultiplier = 2.5,
        fireRate = 40,
        magSize = 5,
        reserveAmmo = 30,
        reloadTime = 3.5,

        baseSpread = 0.1,
        maxSpread = 1.0,
        spreadIncreasePerShot = 0.8,
        spreadRecoveryRate = 2.0,
        adsSpreadMultiplier = 0.05,

        recoilVertical = 6.0,
        recoilHorizontal = 0.5,
        recoilRecoverySpeed = 2.0,

        adsTime = 0.4,
        adsZoom = 0.3,              -- High zoom

        moveSpeedMultiplier = 0.8,
        adsSpeedMultiplier = 0.5,

        effectiveRange = 300,
        maxRange = 1000,
        damageDropoff = 0.8,

        penetration = 80,

        fireSound = "rbxassetid://0",
        reloadSound = "rbxassetid://0",
        equipSound = "rbxassetid://0",
        muzzleFlash = true,
        tracerEnabled = true,
        tracerColor = Color3.fromRGB(255, 100, 100),
        tracerSpeed = 800,
    },
}

-- ===========================================
-- ACTUAL WEAPONS (inherit from templates)
-- ===========================================
WeaponConfig.Weapons = {
    -- Assault Rifles
    AK47 = {
        template = "AssaultRifle",
        displayName = "AK-47",
        description = "Reliable assault rifle with high damage but strong recoil",

        -- Override template values
        damage = 35,
        fireRate = 550,
        recoilVertical = 2.0,
        recoilHorizontal = 0.6,

        -- Viewmodel settings
        viewmodelOffset = CFrame.new(0.5, -0.5, -1.2),
        adsOffset = CFrame.new(0, -0.35, -0.8),
    },

    M4A1 = {
        template = "AssaultRifle",
        displayName = "M4A1",
        description = "Versatile assault rifle with moderate stats",

        damage = 28,
        fireRate = 700,
        recoilVertical = 1.2,
        recoilHorizontal = 0.35,

        viewmodelOffset = CFrame.new(0.5, -0.5, -1.2),
        adsOffset = CFrame.new(0, -0.35, -0.8),
    },

    -- SMGs
    MP5 = {
        template = "SMG",
        displayName = "MP5",
        description = "Classic SMG with good accuracy",

        damage = 24,
        fireRate = 800,
        magSize = 30,

        -- Viewmodel positioning
        viewmodelOffset = CFrame.new(0.3, -0.4, -1.0),
        adsOffset = CFrame.new(0, -0.3, -0.6),

        -- Gun model offset (no extra rotation needed if model is oriented correctly)
        gunOffset = CFrame.new(0, 0, 0),
    },

    -- Pistols
    Glock17 = {
        template = "Pistol",
        displayName = "Glock 17",
        description = "Reliable sidearm with fast fire rate",

        damage = 32,
        fireRate = 450,
        magSize = 17,

        viewmodelOffset = CFrame.new(0.3, -0.4, -0.8),
        adsOffset = CFrame.new(0, -0.25, -0.6),
    },

    Deagle = {
        template = "Pistol",
        displayName = "Desert Eagle",
        description = "High-powered pistol with massive recoil",

        damage = 55,
        fireRate = 200,
        magSize = 7,
        recoilVertical = 5.0,
        recoilHorizontal = 0.8,

        viewmodelOffset = CFrame.new(0.3, -0.4, -0.8),
        adsOffset = CFrame.new(0, -0.25, -0.6),
    },

    -- Shotguns
    Remington870 = {
        template = "Shotgun",
        displayName = "Remington 870",
        description = "Pump-action shotgun, devastating at close range",

        damage = 18,
        pelletCount = 8,

        viewmodelOffset = CFrame.new(0.5, -0.5, -1.3),
        adsOffset = CFrame.new(0, -0.35, -0.9),
    },

    -- Sniper Rifles
    AWP = {
        template = "SniperRifle",
        displayName = "AWP",
        description = "Bolt-action sniper rifle, one-shot potential",

        damage = 115,
        fireRate = 30,

        viewmodelOffset = CFrame.new(0.5, -0.55, -1.5),
        adsOffset = CFrame.new(0, -0.4, -1.0),
    },
}

-- ===========================================
-- HELPER FUNCTIONS
-- ===========================================

--[[
    Gets a weapon's full configuration (template + overrides)
    @param weaponName: string - Name of the weapon
    @return table - Complete weapon config
]]
function WeaponConfig.GetWeapon(weaponName: string): table?
    local weapon = WeaponConfig.Weapons[weaponName]
    if not weapon then
        warn("[WeaponConfig] Weapon not found:", weaponName)
        return nil
    end

    -- Get template
    local template = WeaponConfig.Templates[weapon.template]
    if not template then
        warn("[WeaponConfig] Template not found:", weapon.template)
        return nil
    end

    -- Merge template with weapon overrides
    local config = {}

    -- Copy template values
    for key, value in pairs(template) do
        config[key] = value
    end

    -- Override with weapon-specific values
    for key, value in pairs(weapon) do
        if key ~= "template" then
            config[key] = value
        end
    end

    config.id = weaponName

    return config
end

--[[
    Gets list of all weapon names
    @return table - Array of weapon names
]]
function WeaponConfig.GetAllWeaponNames(): {string}
    local names = {}
    for name, _ in pairs(WeaponConfig.Weapons) do
        table.insert(names, name)
    end
    return names
end

--[[
    Gets weapons by type
    @param weaponType: string - "Primary" or "Secondary"
    @return table - Array of weapon configs
]]
function WeaponConfig.GetWeaponsByType(weaponType: string): {table}
    local weapons = {}
    for name, _ in pairs(WeaponConfig.Weapons) do
        local config = WeaponConfig.GetWeapon(name)
        if config and config.weaponType == weaponType then
            table.insert(weapons, config)
        end
    end
    return weapons
end

return WeaponConfig
