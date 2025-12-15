--[[
    WeaponController.client.lua
    Client-side weapon handling - shooting, reloading, ADS
    Location: StarterPlayerScripts/WeaponController
]]

print("[WeaponController] Script starting...")

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Wait for character
local Character = Player.Character or Player.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")

print("[WeaponController] Loading modules...")

-- Load modules
local Modules = ReplicatedStorage:WaitForChild("Modules")
local Config = ReplicatedStorage:WaitForChild("Config")

local WeaponConfig = require(Config:WaitForChild("WeaponConfig"))
local BulletTracer = require(Modules:WaitForChild("BulletTracer"))
local ViewmodelController = require(Modules:WaitForChild("ViewmodelController"))

print("[WeaponController] Modules loaded")

-- Get network events
local Events = ReplicatedStorage:WaitForChild("Events")
local WeaponFireEvent = Events:WaitForChild("WeaponFire", 5) or Instance.new("RemoteEvent", Events)
WeaponFireEvent.Name = "WeaponFire"

-- ===========================================
-- STATE
-- ===========================================
local WeaponState = {
    CurrentWeapon = nil,        -- Current weapon config
    IsEquipped = false,
    IsADS = false,
    IsFiring = false,
    IsReloading = false,

    -- Ammo
    CurrentMag = 0,
    ReserveAmmo = 0,

    -- Spread/Accuracy
    CurrentSpread = 0,

    -- Timing
    LastFireTime = 0,
    FireCooldown = 0,

    -- Recoil accumulation
    RecoilX = 0,                -- Horizontal accumulation
    RecoilY = 0,                -- Vertical accumulation
}

-- Viewmodel instance
local Viewmodel = ViewmodelController.new()

-- ===========================================
-- KEYBINDS
-- ===========================================
local Keybinds = {
    Fire = Enum.UserInputType.MouseButton1,
    ADS = Enum.UserInputType.MouseButton2,
    Reload = Enum.KeyCode.R,
    Equip1 = Enum.KeyCode.One,
    Equip2 = Enum.KeyCode.Two,
}

-- ===========================================
-- WEAPON MANAGEMENT
-- ===========================================

--[[
    Equips a weapon by name
    @param weaponName: string - Name from WeaponConfig
]]
local function equipWeapon(weaponName: string)
    local config = WeaponConfig.GetWeapon(weaponName)
    if not config then
        warn("[WeaponController] Failed to get weapon config:", weaponName)
        return
    end

    -- Unequip current weapon
    if WeaponState.IsEquipped then
        unequipWeapon()
    end

    WeaponState.CurrentWeapon = config
    WeaponState.IsEquipped = true
    WeaponState.CurrentMag = config.magSize
    WeaponState.ReserveAmmo = config.reserveAmmo
    WeaponState.CurrentSpread = config.baseSpread
    WeaponState.FireCooldown = 60 / config.fireRate

    -- Equip viewmodel
    Viewmodel:Equip(config)

    print("[WeaponController] Equipped:", config.displayName)
    print("[WeaponController] Ammo:", WeaponState.CurrentMag, "/", WeaponState.ReserveAmmo)
end

--[[
    Unequips the current weapon
]]
function unequipWeapon()
    Viewmodel:Unequip()

    WeaponState.CurrentWeapon = nil
    WeaponState.IsEquipped = false
    WeaponState.IsADS = false
    WeaponState.IsFiring = false

    print("[WeaponController] Unequipped")
end

-- ===========================================
-- SHOOTING
-- ===========================================

--[[
    Performs a raycast from camera
    @return RaycastResult?, Vector3 - Hit result and end position
]]
local function performRaycast()
    local config = WeaponState.CurrentWeapon
    if not config then return nil, Camera.CFrame.Position end

    -- Calculate spread
    local spreadAngle = math.rad(WeaponState.CurrentSpread)
    local spreadX = (math.random() - 0.5) * 2 * spreadAngle
    local spreadY = (math.random() - 0.5) * 2 * spreadAngle

    -- Apply spread to direction
    local direction = Camera.CFrame.LookVector
    direction = (CFrame.new(Vector3.new(), direction) * CFrame.Angles(spreadY, spreadX, 0)).LookVector

    local origin = Camera.CFrame.Position
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = {Character, Camera}

    local result = workspace:Raycast(origin, direction * config.maxRange, raycastParams)

    local hitPosition = result and result.Position or (origin + direction * config.maxRange)

    return result, hitPosition
end

--[[
    Fires the weapon
]]
local function fireWeapon()
    local config = WeaponState.CurrentWeapon
    if not config then return end
    if WeaponState.IsReloading then return end
    if WeaponState.CurrentMag <= 0 then
        -- Click sound / auto reload
        startReload()
        return
    end

    local currentTime = tick()
    if currentTime - WeaponState.LastFireTime < WeaponState.FireCooldown then
        return
    end

    WeaponState.LastFireTime = currentTime
    WeaponState.CurrentMag = WeaponState.CurrentMag - 1

    -- Handle shotgun pellets
    local pelletCount = config.pelletCount or 1

    for i = 1, pelletCount do
        -- Perform raycast
        local hitResult, hitPosition = performRaycast()

        -- Get muzzle position for tracer
        local muzzlePos, muzzleDir = Viewmodel:GetMuzzlePosition()

        -- Create tracer
        if config.tracerEnabled then
            BulletTracer.Fire(muzzlePos, hitPosition, {
                color = config.tracerColor,
                speed = config.tracerSpeed,
            })
        end

        -- Muzzle flash
        if config.muzzleFlash then
            BulletTracer.MuzzleFlash(muzzlePos, muzzleDir)
        end

        -- Send hit to server
        if hitResult then
            BulletTracer.ImpactEffect(hitResult.Position, hitResult.Normal)

            WeaponFireEvent:FireServer({
                hitPart = hitResult.Instance,
                hitPosition = hitResult.Position,
                hitNormal = hitResult.Normal,
                weaponId = config.id,
                damage = config.damage,
                headshot = hitResult.Instance.Name == "Head",
            })
        end
    end

    -- Apply spread increase
    WeaponState.CurrentSpread = math.min(
        config.maxSpread,
        WeaponState.CurrentSpread + config.spreadIncreasePerShot
    )

    -- Apply recoil to camera
    applyRecoil()

    -- Apply recoil to viewmodel
    Viewmodel:ApplyRecoil(config.recoilVertical * 0.3, (math.random() - 0.5) * config.recoilHorizontal * 0.3)

    -- Update ammo display
    -- print("[Weapon] Ammo:", WeaponState.CurrentMag, "/", WeaponState.ReserveAmmo)
end

--[[
    Applies recoil to the camera
]]
function applyRecoil()
    local config = WeaponState.CurrentWeapon
    if not config then return end

    -- Calculate recoil
    local verticalRecoil = config.recoilVertical
    local horizontalRecoil = (math.random() - 0.5) * 2 * config.recoilHorizontal

    -- Reduce recoil when ADS
    if WeaponState.IsADS then
        verticalRecoil = verticalRecoil * 0.7
        horizontalRecoil = horizontalRecoil * 0.7
    end

    -- Accumulate recoil
    WeaponState.RecoilY = WeaponState.RecoilY + verticalRecoil
    WeaponState.RecoilX = WeaponState.RecoilX + horizontalRecoil

    -- Apply to camera controller if available
    if _G.CameraController then
        _G.CameraController.ApplyRecoil(verticalRecoil, horizontalRecoil)
    end
end

-- ===========================================
-- RELOADING
-- ===========================================

--[[
    Starts the reload process
]]
function startReload()
    local config = WeaponState.CurrentWeapon
    if not config then return end
    if WeaponState.IsReloading then return end
    if WeaponState.CurrentMag >= config.magSize then return end
    if WeaponState.ReserveAmmo <= 0 then
        print("[WeaponController] No ammo!")
        return
    end

    WeaponState.IsReloading = true
    print("[WeaponController] Reloading...")

    -- TODO: Play reload animation

    -- Wait for reload time
    task.delay(config.reloadTime, function()
        if not WeaponState.IsReloading then return end

        local ammoNeeded = config.magSize - WeaponState.CurrentMag
        local ammoToLoad = math.min(ammoNeeded, WeaponState.ReserveAmmo)

        WeaponState.CurrentMag = WeaponState.CurrentMag + ammoToLoad
        WeaponState.ReserveAmmo = WeaponState.ReserveAmmo - ammoToLoad
        WeaponState.IsReloading = false

        print("[WeaponController] Reload complete:", WeaponState.CurrentMag, "/", WeaponState.ReserveAmmo)
    end)
end

-- ===========================================
-- ADS (AIM DOWN SIGHTS)
-- ===========================================

local function setADS(isADS: boolean)
    local config = WeaponState.CurrentWeapon
    if not config then return end

    WeaponState.IsADS = isADS
    Viewmodel:SetADS(isADS)

    -- Adjust spread when ADS
    if isADS then
        WeaponState.CurrentSpread = WeaponState.CurrentSpread * config.adsSpreadMultiplier
    end

    -- Notify movement controller
    if _G.MovementController then
        _G.MovementController.SetADS(isADS)
    end

    -- Adjust FOV
    if _G.CameraController then
        -- CameraController handles FOV changes
    end
end

-- ===========================================
-- INPUT HANDLING
-- ===========================================

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    -- Fire (left click)
    if input.UserInputType == Keybinds.Fire then
        if WeaponState.IsEquipped then
            WeaponState.IsFiring = true
            fireWeapon()
        end
    end

    -- ADS (right click)
    if input.UserInputType == Keybinds.ADS then
        if WeaponState.IsEquipped then
            setADS(true)
        end
    end

    -- Reload
    if input.KeyCode == Keybinds.Reload then
        if WeaponState.IsEquipped then
            startReload()
        end
    end

    -- Equip primary (1)
    if input.KeyCode == Keybinds.Equip1 then
        equipWeapon("AK47")
    end

    -- Equip secondary (2)
    if input.KeyCode == Keybinds.Equip2 then
        equipWeapon("Glock17")
    end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
    -- Stop firing
    if input.UserInputType == Keybinds.Fire then
        WeaponState.IsFiring = false
    end

    -- Stop ADS
    if input.UserInputType == Keybinds.ADS then
        setADS(false)
    end
end)

-- ===========================================
-- UPDATE LOOP
-- ===========================================

RunService.RenderStepped:Connect(function(dt)
    local config = WeaponState.CurrentWeapon
    if not config then return end

    -- Auto fire for automatic weapons
    if WeaponState.IsFiring and config.fireMode == "Auto" then
        fireWeapon()
    end

    -- Spread recovery
    if WeaponState.CurrentSpread > config.baseSpread then
        local recovery = config.spreadRecoveryRate * dt
        local minSpread = WeaponState.IsADS and (config.baseSpread * config.adsSpreadMultiplier) or config.baseSpread
        WeaponState.CurrentSpread = math.max(minSpread, WeaponState.CurrentSpread - recovery)
    end

    -- Recoil recovery
    local recoilRecovery = (config.recoilRecoverySpeed or 5) * dt
    WeaponState.RecoilX = WeaponState.RecoilX * (1 - recoilRecovery * 0.5)
    WeaponState.RecoilY = math.max(0, WeaponState.RecoilY - recoilRecovery)

    -- Update viewmodel sprint state
    if _G.MovementController then
        local moveState = _G.MovementController.GetState()
        Viewmodel:SetSprinting(moveState.IsSprinting)
    end
end)

-- ===========================================
-- CHARACTER RESPAWN
-- ===========================================

Player.CharacterAdded:Connect(function(newCharacter)
    Character = newCharacter
    Humanoid = Character:WaitForChild("Humanoid")

    -- Unequip on death/respawn
    unequipWeapon()
end)

-- ===========================================
-- PUBLIC API
-- ===========================================

local WeaponController = {}

function WeaponController.GetState()
    return {
        isEquipped = WeaponState.IsEquipped,
        weaponName = WeaponState.CurrentWeapon and WeaponState.CurrentWeapon.displayName,
        currentMag = WeaponState.CurrentMag,
        reserveAmmo = WeaponState.ReserveAmmo,
        isReloading = WeaponState.IsReloading,
        isADS = WeaponState.IsADS,
    }
end

function WeaponController.Equip(weaponName: string)
    equipWeapon(weaponName)
end

function WeaponController.Unequip()
    unequipWeapon()
end

_G.WeaponController = WeaponController

print("[WeaponController] ✓ Initialized - Press 1 for AK47, 2 for Glock")
