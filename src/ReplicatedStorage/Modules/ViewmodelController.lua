--[[
    ViewmodelController.lua
    Handles first-person viewmodel (arms + weapon)
    Location: ReplicatedStorage/Modules/ViewmodelController

    WEAPON MODEL SETUP:
    1. Create your gun model with all parts welded to a PrimaryPart
    2. Add an Attachment named "Muzzle" where bullets come from
    3. Add an Attachment named "RightHand" where right hand grips
    4. Add an Attachment named "LeftHand" where left hand grips (foregrip)
    5. Place model in ReplicatedStorage/Weapons/[WeaponName]
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

    -- Arm colors (customize or load from character)
    armColor = Color3.fromRGB(255, 204, 153),
    sleeveColor = Color3.fromRGB(60, 60, 60),
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
    self.WeaponPartOffsets = {} -- Stores relative CFrame offsets for each part

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
    @return Model - The viewmodel model
]]
function ViewmodelController:CreateArmsModel()
    local viewmodel = Instance.new("Model")
    viewmodel.Name = "Viewmodel"

    -- Weapon holder (where gun attaches)
    local weaponHolder = Instance.new("Part")
    weaponHolder.Name = "WeaponHolder"
    weaponHolder.Size = Vector3.new(0.1, 0.1, 0.1)
    weaponHolder.Transparency = 1
    weaponHolder.CanCollide = false
    weaponHolder.Anchored = true
    weaponHolder.Parent = viewmodel

    -- Create right hand (small, positioned at grip)
    local rightHand = Instance.new("Part")
    rightHand.Name = "RightHand"
    rightHand.Size = Vector3.new(0.15, 0.2, 0.15)
    rightHand.Color = CONFIG.armColor
    rightHand.Material = Enum.Material.SmoothPlastic
    rightHand.CanCollide = false
    rightHand.Anchored = true
    rightHand.CastShadow = false
    rightHand.Parent = viewmodel

    -- Create right arm (thin, extends down from hand)
    local rightArm = Instance.new("Part")
    rightArm.Name = "RightArm"
    rightArm.Size = Vector3.new(0.12, 0.5, 0.12)
    rightArm.Color = CONFIG.sleeveColor
    rightArm.Material = Enum.Material.Fabric
    rightArm.CanCollide = false
    rightArm.Anchored = true
    rightArm.CastShadow = false
    rightArm.Parent = viewmodel

    -- Create left hand
    local leftHand = Instance.new("Part")
    leftHand.Name = "LeftHand"
    leftHand.Size = Vector3.new(0.15, 0.2, 0.15)
    leftHand.Color = CONFIG.armColor
    leftHand.Material = Enum.Material.SmoothPlastic
    leftHand.CanCollide = false
    leftHand.Anchored = true
    leftHand.CastShadow = false
    leftHand.Parent = viewmodel

    -- Create left arm
    local leftArm = Instance.new("Part")
    leftArm.Name = "LeftArm"
    leftArm.Size = Vector3.new(0.12, 0.5, 0.12)
    leftArm.Color = CONFIG.sleeveColor
    leftArm.Material = Enum.Material.Fabric
    leftArm.CanCollide = false
    leftArm.Anchored = true
    leftArm.CastShadow = false
    leftArm.Parent = viewmodel

    viewmodel.PrimaryPart = weaponHolder

    return viewmodel
end

--[[
    Loads a weapon model from ReplicatedStorage/Weapons
    @param weaponConfig: table - Weapon configuration
    @return Model, Attachment - The weapon model and muzzle attachment
]]
function ViewmodelController:LoadWeaponModel(weaponConfig)
    local weaponsFolder = ReplicatedStorage:FindFirstChild("Weapons")

    if weaponsFolder then
        local modelTemplate = weaponsFolder:FindFirstChild(weaponConfig.id)
        if modelTemplate then
            -- Clone the model
            local weapon = modelTemplate:Clone()
            weapon.Name = weaponConfig.id

            -- Make all parts non-collidable and anchored for viewmodel
            -- Also store relative offsets from PrimaryPart
            local partOffsets = {}
            local primaryPart = weapon.PrimaryPart

            for _, part in ipairs(weapon:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                    part.Anchored = true
                    part.CastShadow = false

                    -- Store offset relative to PrimaryPart
                    if primaryPart and part ~= primaryPart then
                        partOffsets[part] = primaryPart.CFrame:ToObjectSpace(part.CFrame)
                    end
                end
            end

            self.WeaponPartOffsets = partOffsets

            -- Find muzzle attachment
            local muzzle = weapon:FindFirstChild("Muzzle", true)
            if not muzzle then
                -- Create default muzzle at front of gun
                muzzle = Instance.new("Attachment")
                muzzle.Name = "Muzzle"
                if weapon.PrimaryPart then
                    muzzle.Parent = weapon.PrimaryPart
                    muzzle.Position = Vector3.new(0, 0, -weapon.PrimaryPart.Size.Z/2 - 0.5)
                end
            end

            print("[Viewmodel] Loaded weapon model:", weaponConfig.id)
            return weapon, muzzle
        end
    end

    -- Fallback to procedural model if no model found
    print("[Viewmodel] No model found for", weaponConfig.id, "- using placeholder")
    return self:CreateProceduralWeapon(weaponConfig)
end

--[[
    Creates a procedural placeholder weapon
    @param weaponConfig: table - Weapon configuration
    @return Model, Attachment - The weapon model and muzzle attachment
]]
function ViewmodelController:CreateProceduralWeapon(weaponConfig)
    local weapon = Instance.new("Model")
    weapon.Name = weaponConfig.id or "Weapon"

    -- Determine size based on weapon type
    local bodySize = Vector3.new(0.15, 0.2, 0.9)
    local barrelLength = 0.4

    if weaponConfig.weaponType == "Secondary" then
        bodySize = Vector3.new(0.12, 0.18, 0.5)
        barrelLength = 0.2
    elseif weaponConfig.template == "SniperRifle" then
        bodySize = Vector3.new(0.15, 0.22, 1.3)
        barrelLength = 0.6
    elseif weaponConfig.template == "Shotgun" then
        bodySize = Vector3.new(0.18, 0.22, 1.1)
        barrelLength = 0.5
    end

    -- Create gun body
    local body = Instance.new("Part")
    body.Name = "Body"
    body.Size = bodySize
    body.Color = Color3.fromRGB(45, 45, 48)
    body.Material = Enum.Material.Metal
    body.CanCollide = false
    body.Anchored = true
    body.CastShadow = false
    body.Parent = weapon

    -- Create barrel
    local barrel = Instance.new("Part")
    barrel.Name = "Barrel"
    barrel.Size = Vector3.new(0.1, 0.1, barrelLength)
    barrel.Color = Color3.fromRGB(35, 35, 38)
    barrel.Material = Enum.Material.Metal
    barrel.CanCollide = false
    barrel.Anchored = true
    barrel.CastShadow = false
    barrel.Parent = weapon

    -- Create muzzle attachment
    local muzzle = Instance.new("Attachment")
    muzzle.Name = "Muzzle"
    muzzle.Position = Vector3.new(0, 0, -barrelLength/2)
    muzzle.Parent = barrel

    -- Create grip
    local grip = Instance.new("Part")
    grip.Name = "Grip"
    grip.Size = Vector3.new(0.12, 0.3, 0.18)
    grip.Color = Color3.fromRGB(55, 45, 35)
    grip.Material = Enum.Material.Wood
    grip.CanCollide = false
    grip.Anchored = true
    grip.CastShadow = false
    grip.Parent = weapon

    -- Create magazine
    local mag = Instance.new("Part")
    mag.Name = "Magazine"
    mag.Size = Vector3.new(0.08, 0.3, 0.2)
    mag.Color = Color3.fromRGB(40, 40, 42)
    mag.Material = Enum.Material.Metal
    mag.CanCollide = false
    mag.Anchored = true
    mag.CastShadow = false
    mag.Parent = weapon

    -- Create hand grip attachments
    local rightHandGrip = Instance.new("Attachment")
    rightHandGrip.Name = "RightHand"
    rightHandGrip.Position = Vector3.new(0, -0.15, 0.1)
    rightHandGrip.Parent = body

    local leftHandGrip = Instance.new("Attachment")
    leftHandGrip.Name = "LeftHand"
    leftHandGrip.Position = Vector3.new(0, 0, -0.3)
    leftHandGrip.Parent = body

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

    -- Always create viewmodel with arms
    self.ViewmodelModel = self:CreateArmsModel()
    self.ViewmodelModel.Parent = self.Camera

    -- Check if real weapon model exists
    local weaponsFolder = ReplicatedStorage:FindFirstChild("Weapons")
    self.UseRealModel = weaponsFolder and weaponsFolder:FindFirstChild(weaponConfig.id) ~= nil

    -- Load or create weapon model
    self.WeaponModel, self.MuzzleAttachment = self:LoadWeaponModel(weaponConfig)
    self.WeaponModel.Parent = self.ViewmodelModel

    -- Set offsets from config
    self.BaseOffset = weaponConfig.viewmodelOffset or CFrame.new(0.4, -0.4, -1.0)
    self.AdsOffset = weaponConfig.adsOffset or CFrame.new(0, -0.3, -0.7)
    self.CurrentOffset = self.BaseOffset

    -- Gun model offset (for ACS-style models that need rotation)
    self.GunOffset = weaponConfig.gunOffset or CFrame.new()

    -- Arm offsets from config
    self.RightArmOffset = weaponConfig.rightArmOffset
    self.LeftArmOffset = weaponConfig.leftArmOffset
    self.SprintRightArm = weaponConfig.sprintRightArm
    self.SprintLeftArm = weaponConfig.sprintLeftArm

    -- Store hand grip positions from weapon
    self.RightHandGrip = self.WeaponModel:FindFirstChild("RightHand", true)
    self.LeftHandGrip = self.WeaponModel:FindFirstChild("LeftHand", true)

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
    self.WeaponPartOffsets = {}
    self.GunOffset = nil
    self.UseRealModel = false
    self.RightArmOffset = nil
    self.LeftArmOffset = nil
    self.SprintRightArm = nil
    self.SprintLeftArm = nil
    self.RightHandGrip = nil
    self.LeftHandGrip = nil
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
    local recoilCFrame = CFrame.Angles(
        math.rad(-vertical),
        math.rad(horizontal),
        0
    ) * CFrame.new(0, 0, 0.05)

    self.RecoilOffset = self.RecoilOffset * recoilCFrame
end

--[[
    Gets the muzzle world position
    @return Vector3, Vector3 - Position and forward direction
]]
function ViewmodelController:GetMuzzlePosition(): (Vector3, Vector3)
    if self.MuzzleAttachment then
        local cf
        -- Handle both Attachments (WorldCFrame) and Parts (CFrame)
        if self.MuzzleAttachment:IsA("Attachment") then
            cf = self.MuzzleAttachment.WorldCFrame
        else
            cf = self.MuzzleAttachment.CFrame
        end
        return cf.Position, cf.LookVector
    end

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

    self:UpdateSway(dt)
    self:UpdateBob(dt)
    self:UpdateBreathing(dt)
    self:UpdateRecoilRecovery(dt)

    local targetOffset = self.IsADS and self.AdsOffset or self.BaseOffset
    self.CurrentOffset = self.CurrentOffset:Lerp(targetOffset, dt * CONFIG.adsSpeed)

    local baseCFrame = self.Camera.CFrame * self.CurrentOffset
    local finalCFrame = baseCFrame * self.SwayOffset * self.BobOffset * self.RecoilOffset * self.BreathingOffset

    self:UpdateViewmodelParts(finalCFrame)
end

--[[
    Updates camera sway effect
]]
function ViewmodelController:UpdateSway(dt: number)
    local currentRot = Vector2.new(
        self.Camera.CFrame:ToEulerAnglesYXZ()
    )

    local rotDelta = currentRot - self.LastCameraRot
    self.LastCameraRot = currentRot

    local swayX = math.clamp(rotDelta.Y * CONFIG.swayAmount, -CONFIG.maxSway, CONFIG.maxSway)
    local swayY = math.clamp(rotDelta.X * CONFIG.swayAmount, -CONFIG.maxSway, CONFIG.maxSway)

    local targetSway = CFrame.Angles(swayY * 0.1, swayX * 0.1, -swayX * 0.05)
    self.SwayOffset = self.SwayOffset:Lerp(targetSway, dt * CONFIG.swaySpeed)
    self.SwayOffset = self.SwayOffset:Lerp(CFrame.new(), dt * CONFIG.swaySpeed * 0.5)
end

--[[
    Updates movement bob effect
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
]]
function ViewmodelController:UpdateBreathing(dt: number)
    self.BreathTime = self.BreathTime + dt * CONFIG.breathingSpeed

    local amount = CONFIG.breathingAmount
    if self.IsADS then
        amount = amount * 0.3
    end

    local breathX = math.sin(self.BreathTime * 0.8) * amount
    local breathY = math.sin(self.BreathTime * 1.2) * amount * 0.5

    self.BreathingOffset = CFrame.new(breathX, breathY, 0)
end

--[[
    Recovers recoil over time
]]
function ViewmodelController:UpdateRecoilRecovery(dt: number)
    self.RecoilOffset = self.RecoilOffset:Lerp(CFrame.new(), dt * 8)
end

--[[
    Updates all viewmodel parts to follow the calculated CFrame
]]
function ViewmodelController:UpdateViewmodelParts(baseCFrame: CFrame)
    if not self.ViewmodelModel then return end

    local holder = self.ViewmodelModel:FindFirstChild("WeaponHolder")
    if holder then
        holder.CFrame = baseCFrame
    end

    -- Update weapon model position (for real weapon models)
    if self.WeaponModel and self.WeaponModel.PrimaryPart then
        -- Apply gun offset (for ACS-style models that need rotation)
        local gunCFrame = baseCFrame * (self.GunOffset or CFrame.new())
        self.WeaponModel.PrimaryPart.CFrame = gunCFrame

        -- Update all parts using stored offsets
        for part, offset in pairs(self.WeaponPartOffsets) do
            if part and part.Parent then
                part.CFrame = gunCFrame * offset
            end
        end
    end

    -- Position weapon parts (for procedural weapons only - skip if using real model)
    local isProceduralWeapon = next(self.WeaponPartOffsets) == nil
    if self.WeaponModel and isProceduralWeapon then
        local body = self.WeaponModel:FindFirstChild("Body")
        local barrel = self.WeaponModel:FindFirstChild("Barrel")
        local grip = self.WeaponModel:FindFirstChild("Grip")
        local mag = self.WeaponModel:FindFirstChild("Magazine")

        if body then
            body.CFrame = baseCFrame * CFrame.new(0, 0, -0.15)
        end
        if barrel then
            barrel.CFrame = baseCFrame * CFrame.new(0, 0.02, -0.6)
        end
        if grip then
            grip.CFrame = baseCFrame * CFrame.new(0, -0.22, 0.08)
        end
        if mag then
            mag.CFrame = baseCFrame * CFrame.new(0, -0.28, -0.05)
        end
    end

    -- Position arms
    local rightArm = self.ViewmodelModel:FindFirstChild("RightArm")
    local rightHand = self.ViewmodelModel:FindFirstChild("RightHand")
    local leftArm = self.ViewmodelModel:FindFirstChild("LeftArm")
    local leftHand = self.ViewmodelModel:FindFirstChild("LeftHand")

    -- Get gun CFrame for positioning arms relative to weapon
    local gunCFrame = baseCFrame * (self.GunOffset or CFrame.new())

    -- Default grip positions (relative to viewmodel base, not gun)
    -- Right hand at pistol grip area, left hand at foregrip
    local rightGripPos = CFrame.new(0.08, -0.15, 0.1)
    local leftGripPos = CFrame.new(-0.08, -0.12, -0.3)

    -- Use grip attachments from weapon if available
    if self.RightHandGrip then
        if self.RightHandGrip:IsA("Attachment") then
            rightGripPos = CFrame.new(self.RightHandGrip.Position)
        elseif self.WeaponModel.PrimaryPart then
            local relPos = self.WeaponModel.PrimaryPart.CFrame:ToObjectSpace(self.RightHandGrip.CFrame)
            rightGripPos = CFrame.new(relPos.Position)
        end
    end
    if self.LeftHandGrip then
        if self.LeftHandGrip:IsA("Attachment") then
            leftGripPos = CFrame.new(self.LeftHandGrip.Position)
        elseif self.WeaponModel.PrimaryPart then
            local relPos = self.WeaponModel.PrimaryPart.CFrame:ToObjectSpace(self.LeftHandGrip.CFrame)
            leftGripPos = CFrame.new(relPos.Position)
        end
    end

    -- Position hands at grip points
    if rightHand then
        rightHand.CFrame = baseCFrame * rightGripPos
    end
    -- Right arm extends down and back from hand
    if rightArm then
        rightArm.CFrame = baseCFrame * rightGripPos * CFrame.new(0.05, -0.35, 0.15) * CFrame.Angles(math.rad(20), 0, math.rad(-10))
    end

    if leftHand then
        leftHand.CFrame = baseCFrame * leftGripPos
    end
    -- Left arm extends down and back from hand
    if leftArm then
        leftArm.CFrame = baseCFrame * leftGripPos * CFrame.new(-0.05, -0.35, 0.1) * CFrame.Angles(math.rad(15), 0, math.rad(10))
    end
end

--[[
    Cleans up the controller
]]
function ViewmodelController:Destroy()
    self:Unequip()
end

return ViewmodelController
