--[[
    StaminaSystem.lua
    Manages player stamina for sprinting, jumping, etc.
    Location: ReplicatedStorage/Modules/StaminaSystem
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("GameConfig"))
local StaminaConfig = Config.Player.Stamina

local StaminaSystem = {}
StaminaSystem.__index = StaminaSystem

--[[
    Creates a new StaminaSystem instance for a player
    @param player: Player - The player this system belongs to
    @return StaminaSystem
]]
function StaminaSystem.new(player: Player)
    local self = setmetatable({}, StaminaSystem)

    self.Player = player
    self.MaxStamina = StaminaConfig.MaxStamina
    self.CurrentStamina = StaminaConfig.MaxStamina

    -- State tracking
    self.IsSprinting = false
    self.IsRegenerating = true
    self.LastUseTime = 0

    -- Events
    self.OnStaminaChanged = Instance.new("BindableEvent")
    self.OnStaminaDepleted = Instance.new("BindableEvent")
    self.OnStaminaRecovered = Instance.new("BindableEvent")

    -- Update connection
    self.UpdateConnection = nil

    return self
end

--[[
    Starts the stamina update loop
    Should be called after initialization
]]
function StaminaSystem:Start()
    if self.UpdateConnection then return end

    self.UpdateConnection = RunService.Heartbeat:Connect(function(dt)
        self:_update(dt)
    end)
end

--[[
    Internal update function
    @param dt: number - Delta time
]]
function StaminaSystem:_update(dt: number)
    local previousStamina = self.CurrentStamina

    if self.IsSprinting then
        -- Drain stamina while sprinting
        self:Consume(StaminaConfig.SprintDrain * dt)
        self.LastUseTime = tick()
        self.IsRegenerating = false
    else
        -- Check if we can start regenerating
        local timeSinceUse = tick() - self.LastUseTime

        if timeSinceUse >= StaminaConfig.RegenDelay then
            if not self.IsRegenerating and self.CurrentStamina < self.MaxStamina then
                self.IsRegenerating = true
            end

            -- Regenerate stamina
            if self.IsRegenerating then
                self:Restore(StaminaConfig.RegenRate * dt)
            end
        end
    end

    -- Fire changed event if stamina changed significantly
    if math.abs(previousStamina - self.CurrentStamina) > 0.1 then
        self.OnStaminaChanged:Fire({
            current = self.CurrentStamina,
            max = self.MaxStamina,
            percent = self:GetStaminaPercent(),
        })
    end
end

--[[
    Consumes stamina
    @param amount: number - Amount to consume
    @return boolean - True if stamina was successfully consumed
]]
function StaminaSystem:Consume(amount: number): boolean
    if self.CurrentStamina <= 0 then
        return false
    end

    local wasDepleted = self.CurrentStamina > 0
    self.CurrentStamina = math.max(0, self.CurrentStamina - amount)
    self.LastUseTime = tick()
    self.IsRegenerating = false

    -- Check if stamina just depleted
    if wasDepleted and self.CurrentStamina <= 0 then
        self.OnStaminaDepleted:Fire()
    end

    return true
end

--[[
    Restores stamina
    @param amount: number - Amount to restore
]]
function StaminaSystem:Restore(amount: number)
    local wasEmpty = self.CurrentStamina <= 0
    local previousStamina = self.CurrentStamina

    self.CurrentStamina = math.min(self.MaxStamina, self.CurrentStamina + amount)

    -- Fire recovery event when stamina becomes usable again
    if wasEmpty and self.CurrentStamina >= StaminaConfig.MinSprintStamina then
        self.OnStaminaRecovered:Fire()
    end
end

--[[
    Attempts to use stamina for a one-time action (like jumping)
    @param amount: number - Amount required
    @return boolean - True if action can be performed
]]
function StaminaSystem:TryUse(amount: number): boolean
    if self.CurrentStamina >= amount then
        self:Consume(amount)
        return true
    end
    return false
end

--[[
    Attempts to start sprinting
    @return boolean - True if sprinting can start
]]
function StaminaSystem:TryStartSprint(): boolean
    if self.CurrentStamina >= StaminaConfig.MinSprintStamina then
        self.IsSprinting = true
        return true
    end
    return false
end

--[[
    Stops sprinting
]]
function StaminaSystem:StopSprint()
    self.IsSprinting = false
end

--[[
    Checks if player can currently sprint
    @return boolean
]]
function StaminaSystem:CanSprint(): boolean
    return self.CurrentStamina >= StaminaConfig.MinSprintStamina
end

--[[
    Checks if player can jump
    @return boolean
]]
function StaminaSystem:CanJump(): boolean
    return self.CurrentStamina >= StaminaConfig.JumpCost
end

--[[
    Consumes stamina for a jump
    @return boolean - True if jump stamina was consumed
]]
function StaminaSystem:UseJumpStamina(): boolean
    return self:TryUse(StaminaConfig.JumpCost)
end

--[[
    Gets current stamina as a percentage
    @return number - Stamina percentage (0-1)
]]
function StaminaSystem:GetStaminaPercent(): number
    return self.CurrentStamina / self.MaxStamina
end

--[[
    Gets current stamina value
    @return number
]]
function StaminaSystem:GetStamina(): number
    return self.CurrentStamina
end

--[[
    Sets stamina directly (for loading saves, etc.)
    @param amount: number - New stamina value
]]
function StaminaSystem:SetStamina(amount: number)
    self.CurrentStamina = math.clamp(amount, 0, self.MaxStamina)
    self.OnStaminaChanged:Fire({
        current = self.CurrentStamina,
        max = self.MaxStamina,
        percent = self:GetStaminaPercent(),
    })
end

--[[
    Resets stamina to full
]]
function StaminaSystem:Reset()
    self.CurrentStamina = self.MaxStamina
    self.IsSprinting = false
    self.IsRegenerating = true
    self.LastUseTime = 0
end

--[[
    Cleans up the stamina system
]]
function StaminaSystem:Destroy()
    if self.UpdateConnection then
        self.UpdateConnection:Disconnect()
        self.UpdateConnection = nil
    end

    self.OnStaminaChanged:Destroy()
    self.OnStaminaDepleted:Destroy()
    self.OnStaminaRecovered:Destroy()
end

return StaminaSystem
