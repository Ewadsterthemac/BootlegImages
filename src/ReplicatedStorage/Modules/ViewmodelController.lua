--[[
    ViewmodelController.lua
    Handles first-person viewmodel (arms + weapon)
    Location: ReplicatedStorage/Modules/ViewmodelController
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ViewmodelController = {}
ViewmodelController.__index = ViewmodelController

-- ===========================================
-- CONFIGURATION
-- ===========================================
local CONFIG = {
    -- Sway settings
    swayAmount = 0.3,
    swaySpeed = 8,
    maxSway = 5,

    -- Bob settings
    bobSpeed = 8,
    bobAmount = 0.02,
    sprintBobMultiplier = 1.8,

    -- ADS transition
    adsSpeed = 10,

    -- Breathing
    breathingAmount = 0.003,
    breathingSpeed = 1.5,
}

--[[
    Creates a new ViewmodelController
    @return ViewmodelController
]]
function ViewmodelController.new()
    local self = setmetatable({}, ViewmodelController)

    self.Camera = workspace.CurrentCamera
    self.Player = Players.LocalPlayer

    -- Current viewmodel
    self.ViewmodelModel = nil
    self.WeaponModel = nil
    self.MuzzleAttachment = nil

    -- Offsets
    self.BaseOffset = CFrame.new()
    self.AdsOffset = CFrame.new()
    self.CurrentOffset = CFrame.new()

    -- State
    self.IsADS = false
    self.IsEquipped = false
    self.IsSprinting = false

    -- Animation values
    self.SwayOffset = CFrame.new()
    self.BobOffset = CFrame.new()
    self.RecoilOffset = CFrame.new()
    self.BreathingOffset = CFrame.new()

    -- Tracking
    self.BobTime = 0
    self.BreathTime = 0
    self.LastCameraRot = Vector2.new()

    -- Update connection
    self.UpdateConnection = nil

    return self
end

--[[
    Creates the viewmodel arms
    This creates basic arm models - replace with custom arms model
    @return Model - The viewmodel model
]]
function ViewmodelController:CreateArmsModel()
    local viewmodel = Instance.new("Model")
    viewmodel.Name = "Viewmodel"

    -- Create right arm
    local rightArm = Instance.new("Part")
    rightArm.Name = "RightArm"
    rightArm.Size = Vector3.new(0.4, 1.2, 0.4)
    rightArm.Color = Color3.fromRGB(255, 204, 153) -- Skin color
    rightArm.Material = Enum.Material.SmoothPlastic
    rightArm.CanCollide = false
    rightArm.Anchored = true
    rightArm.CastShadow = false
    rightArm.Parent = viewmodel

    -- Create right hand
    local rightHand = Instance.new("Part")
    rightHand.Name = "RightHand"
    rightHand.Size = Vector3.new(0.35, 0.3, 0.5)
    rightHand.Color = Color3.fromRGB(255, 204, 153)
    rightHand.Material = Enum.Material.SmoothPlastic
    rightHand.CanCollide = false
    rightHand.Anchored = true
    rightHand.CastShadow = false
    rightHand.Parent = viewmodel

    -- Create left arm
    local leftArm = Instance.new("Part")
    leftArm.Name = "LeftArm"
    leftArm.Size = Vector3.new(0.4, 1.2, 0.4)
    leftArm.Color = Color3.fromRGB(255, 204, 153)
    leftArm.Material = Enum.Material.SmoothPlastic
    leftArm.CanCollide = false
    leftArm.Anchored = true
    leftArm.CastShadow = false
    leftArm.Parent = viewmodel

    -- Create left hand
    local leftHand = Instance.new("Part")
    leftHand.Name = "LeftHand"
    leftHand.Size = Vector3.new(0.35, 0.3, 0.5)
    leftHand.Color = Color3.fromRGB(255, 204, 153)
    leftHand.Material = Enum.Material.SmoothPlastic
    leftHand.CanCollide = false
    leftHand.Anchored = true
    leftHand.CastShadow = false
    leftHand.Parent = viewmodel

    -- Weapon holder (where gun attaches)
    local weaponHolder = Instance.new("Part")
    weaponHolder.Name = "WeaponHolder"
    weaponHolder.Size = Vector3.new(0.1, 0.1, 0.1)
    weaponHolder.Transparency = 1
    weaponHolder.CanCollide = false
    weaponHolder.Anchored = true
    weaponHolder.Parent = viewmodel

    viewmodel.PrimaryPart = weaponHolder

    return viewmodel
end

--[[
    Creates a basic weapon model
    Replace this with actual weapon models from your assets
    @param weaponConfig: table - Weapon configuration
    @return Model - The weapon model
]]
function ViewmodelController:CreateWeaponModel(weaponConfig)
    local weapon = Instance.new("Model")
    weapon.Name = weaponConfig.id or "Weapon"

    -- Create gun body (placeholder - replace with mesh)
    local body = Instance.new("Part")
    body.Name = "Body"
    body.Size = Vector3.new(0.2, 0.25, 1.2)
    body.Color = Color3.fromRGB(40, 40, 40)
    body.Material = Enum.Material.Metal
    body.CanCollide = false
    body.Anchored = true
    body.CastShadow = false
    body.Parent = weapon

    -- Create barrel
    local barrel = Instance.new("Part")
    barrel.Name = "Barrel"
    barrel.Size = Vector3.new(0.12, 0.12, 0.6)
    barrel.Color = Color3.fromRGB(30, 30, 30)
    barrel.Material = Enum.Material.Metal
    barrel.CanCollide = false
    barrel.Anchored = true
    barrel.CastShadow = false
    barrel.Parent = weapon

    -- Create muzzle attachment
    local muzzle = Instance.new("Attachment")
    muzzle.Name = "Muzzle"
    muzzle.Position = Vector3.new(0, 0, -0.3)
    muzzle.Parent = barrel

    -- Create grip
    local grip = Instance.new("Part")
    grip.Name = "Grip"
    grip.Size = Vector3.new(0.15, 0.35, 0.2)
    grip.Color = Color3.fromRGB(50, 40, 30)
    grip.Material = Enum.Material.Wood
    grip.CanCollide = false
    grip.Anchored = true
    grip.CastShadow = false
    grip.Parent = weapon

    -- Create magazine
    local mag = Instance.new("Part")
    mag.Name = "Magazine"
    mag.Size = Vector3.new(0.1, 0.4, 0.25)
    mag.Color = Color3.fromRGB(35, 35, 35)
    mag.Material = Enum.Material.Metal
    mag.CanCollide = false
    mag.Anchored = true
    mag.CastShadow = false
    mag.Parent = weapon

    weapon.PrimaryPart = body

    return weapon, muzzle
end

--[[
    Equips a weapon and shows the viewmodel
    @param weaponConfig: table - Weapon configuration
]]
function ViewmodelController:Equip(weaponConfig)
    -- Clean up existing viewmodel
    self:Unequip()

    -- Create viewmodel
    self.ViewmodelModel = self:CreateArmsModel()
    self.ViewmodelModel.Parent = self.Camera

    -- Create weapon model
    self.WeaponModel, self.MuzzleAttachment = self:CreateWeaponModel(weaponConfig)
    self.WeaponModel.Parent = self.ViewmodelModel

    -- Set offsets from config
    self.BaseOffset = weaponConfig.viewmodelOffset or CFrame.new(0.5, -0.5, -1.2)
    self.AdsOffset = weaponConfig.adsOffset or CFrame.new(0, -0.35, -0.8)
    self.CurrentOffset = self.BaseOffset

    self.IsEquipped = true

    -- Start update loop
    self:StartUpdate()

    print("[Viewmodel] Equipped:", weaponConfig.displayName or weaponConfig.id)
end

--[[
    Unequips the current weapon and hides viewmodel
]]
function ViewmodelController:Unequip()
    if self.ViewmodelModel then
        self.ViewmodelModel:Destroy()
        self.ViewmodelModel = nil
    end

    self.WeaponModel = nil
    self.MuzzleAttachment = nil
    self.IsEquipped = false
    self.IsADS = false

    if self.UpdateConnection then
        self.UpdateConnection:Disconnect()
        self.UpdateConnection = nil
    end

    print("[Viewmodel] Unequipped")
end

--[[
    Sets ADS (Aim Down Sights) state
    @param isADS: boolean
]]
function ViewmodelController:SetADS(isADS: boolean)
    self.IsADS = isADS
end

--[[
    Sets sprinting state (affects bob)
    @param isSprinting: boolean
]]
function ViewmodelController:SetSprinting(isSprinting: boolean)
    self.IsSprinting = isSprinting
end

--[[
    Applies recoil to viewmodel
    @param vertical: number - Vertical recoil (degrees)
    @param horizontal: number - Horizontal recoil (degrees)
]]
function ViewmodelController:ApplyRecoil(vertical: number, horizontal: number)
    -- Add to recoil offset
    local recoilCFrame = CFrame.Angles(
        math.rad(-vertical),
        math.rad(horizontal),
        0
    ) * CFrame.new(0, 0, 0.05) -- Slight backwards kick

    self.RecoilOffset = self.RecoilOffset * recoilCFrame
end

--[[
    Gets the muzzle world position
    @return Vector3, Vector3 - Position and forward direction
]]
function ViewmodelController:GetMuzzlePosition(): (Vector3, Vector3)
    if self.MuzzleAttachment then
        local cf = self.MuzzleAttachment.WorldCFrame
        return cf.Position, cf.LookVector
    end

    -- Fallback to camera
    local cf = self.Camera.CFrame
    return cf.Position, cf.LookVector
end

--[[
    Starts the viewmodel update loop
]]
function ViewmodelController:StartUpdate()
    if self.UpdateConnection then return end

    self.UpdateConnection = RunService.RenderStepped:Connect(function(dt)
        self:Update(dt)
    end)
end

--[[
    Main update function
    @param dt: number - Delta time
]]
function ViewmodelController:Update(dt: number)
    if not self.IsEquipped or not self.ViewmodelModel then return end

    -- Update sway based on camera movement
    self:UpdateSway(dt)

    -- Update bob based on movement
    self:UpdateBob(dt)

    -- Update breathing
    self:UpdateBreathing(dt)

    -- Recover recoil
    self:UpdateRecoilRecovery(dt)

    -- Interpolate ADS offset
    local targetOffset = self.IsADS and self.AdsOffset or self.BaseOffset
    self.CurrentOffset = self.CurrentOffset:Lerp(targetOffset, dt * CONFIG.adsSpeed)

    -- Calculate final viewmodel CFrame
    local baseCFrame = self.Camera.CFrame * self.CurrentOffset
    local finalCFrame = baseCFrame * self.SwayOffset * self.BobOffset * self.RecoilOffset * self.BreathingOffset

    -- Update viewmodel position
    self:UpdateViewmodelParts(finalCFrame)
end

--[[
    Updates camera sway effect
    @param dt: number - Delta time
]]
function ViewmodelController:UpdateSway(dt: number)
    -- Get camera rotation delta
    local currentRot = Vector2.new(
        self.Camera.CFrame:ToEulerAnglesYXZ()
    )

    local rotDelta = currentRot - self.LastCameraRot
    self.LastCameraRot = currentRot

    -- Calculate sway
    local swayX = math.clamp(rotDelta.Y * CONFIG.swayAmount, -CONFIG.maxSway, CONFIG.maxSway)
    local swayY = math.clamp(rotDelta.X * CONFIG.swayAmount, -CONFIG.maxSway, CONFIG.maxSway)

    -- Smooth sway
    local targetSway = CFrame.Angles(swayY * 0.1, swayX * 0.1, -swayX * 0.05)
    self.SwayOffset = self.SwayOffset:Lerp(targetSway, dt * CONFIG.swaySpeed)

    -- Return to neutral
    self.SwayOffset = self.SwayOffset:Lerp(CFrame.new(), dt * CONFIG.swaySpeed * 0.5)
end

--[[
    Updates movement bob effect
    @param dt: number - Delta time
]]
function ViewmodelController:UpdateBob(dt: number)
    local character = self.Player.Character
    if not character then return end

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end

    local moveSpeed = humanoid.MoveDirection.Magnitude

    if moveSpeed > 0.1 and humanoid:GetState() ~= Enum.HumanoidStateType.Freefall then
        local bobMultiplier = self.IsSprinting and CONFIG.sprintBobMultiplier or 1
        local bobSpeed = CONFIG.bobSpeed * (self.IsSprinting and 1.5 or 1)

        -- Reduce bob when ADS
        if self.IsADS then
            bobMultiplier = bobMultiplier * 0.2
        end

        self.BobTime = self.BobTime + dt * bobSpeed

        local bobX = math.sin(self.BobTime) * CONFIG.bobAmount * bobMultiplier
        local bobY = math.abs(math.cos(self.BobTime)) * CONFIG.bobAmount * 0.5 * bobMultiplier

        self.BobOffset = CFrame.new(bobX, bobY, 0)
    else
        self.BobOffset = self.BobOffset:Lerp(CFrame.new(), dt * 5)
        self.BobTime = 0
    end
end

--[[
    Updates breathing sway effect
    @param dt: number - Delta time
]]
function ViewmodelController:UpdateBreathing(dt: number)
    self.BreathTime = self.BreathTime + dt * CONFIG.breathingSpeed

    local amount = CONFIG.breathingAmount
    if self.IsADS then
        amount = amount * 0.3 -- Less breathing when ADS
    end

    local breathX = math.sin(self.BreathTime * 0.8) * amount
    local breathY = math.sin(self.BreathTime * 1.2) * amount * 0.5

    self.BreathingOffset = CFrame.new(breathX, breathY, 0)
end

--[[
    Recovers recoil over time
    @param dt: number - Delta time
]]
function ViewmodelController:UpdateRecoilRecovery(dt: number)
    self.RecoilOffset = self.RecoilOffset:Lerp(CFrame.new(), dt * 8)
end

--[[
    Updates all viewmodel parts to follow the calculated CFrame
    @param baseCFrame: CFrame - The base viewmodel position
]]
function ViewmodelController:UpdateViewmodelParts(baseCFrame: CFrame)
    if not self.ViewmodelModel then return end

    local holder = self.ViewmodelModel:FindFirstChild("WeaponHolder")
    if holder then
        holder.CFrame = baseCFrame
    end

    -- Position arms relative to weapon holder
    local rightArm = self.ViewmodelModel:FindFirstChild("RightArm")
    local rightHand = self.ViewmodelModel:FindFirstChild("RightHand")
    local leftArm = self.ViewmodelModel:FindFirstChild("LeftArm")
    local leftHand = self.ViewmodelModel:FindFirstChild("LeftHand")

    if rightArm then
        rightArm.CFrame = baseCFrame * CFrame.new(0.3, 0.1, 0.3) * CFrame.Angles(math.rad(-80), 0, 0)
    end
    if rightHand then
        rightHand.CFrame = baseCFrame * CFrame.new(0.25, -0.15, -0.1) * CFrame.Angles(math.rad(-10), 0, 0)
    end
    if leftArm then
        leftArm.CFrame = baseCFrame * CFrame.new(-0.25, 0.05, 0.1) * CFrame.Angles(math.rad(-75), 0, 0)
    end
    if leftHand then
        leftHand.CFrame = baseCFrame * CFrame.new(-0.2, -0.2, -0.4) * CFrame.Angles(math.rad(-5), 0, 0)
    end

    -- Position weapon
    if self.WeaponModel then
        local body = self.WeaponModel:FindFirstChild("Body")
        local barrel = self.WeaponModel:FindFirstChild("Barrel")
        local grip = self.WeaponModel:FindFirstChild("Grip")
        local mag = self.WeaponModel:FindFirstChild("Magazine")

        if body then
            body.CFrame = baseCFrame * CFrame.new(0, 0, -0.2)
        end
        if barrel then
            barrel.CFrame = baseCFrame * CFrame.new(0, 0.05, -0.8)
        end
        if grip then
            grip.CFrame = baseCFrame * CFrame.new(0, -0.25, 0.1)
        end
        if mag then
            mag.CFrame = baseCFrame * CFrame.new(0, -0.35, -0.1)
        end
    end
end

--[[
    Cleans up the controller
]]
function ViewmodelController:Destroy()
    self:Unequip()
end

return ViewmodelController
