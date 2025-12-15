--[[
    BulletTracer.lua
    Creates visual bullet tracers
    Location: ReplicatedStorage/Modules/BulletTracer
]]

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local BulletTracer = {}

-- ===========================================
-- CONFIGURATION
-- ===========================================
local DEFAULT_CONFIG = {
    color = Color3.fromRGB(255, 200, 100),
    thickness = 0.05,
    speed = 500,            -- Studs per second
    length = 3,             -- Tracer length in studs
    fadeTime = 0.1,         -- Fade out duration
    glowEnabled = true,
    glowSize = 0.15,
}

-- Pool of tracer parts for reuse
local tracerPool = {}
local MAX_POOL_SIZE = 50

-- ===========================================
-- TRACER POOL MANAGEMENT
-- ===========================================

local function getTracerFromPool()
    if #tracerPool > 0 then
        return table.remove(tracerPool)
    end
    return nil
end

local function returnTracerToPool(tracer)
    if #tracerPool < MAX_POOL_SIZE then
        tracer.Parent = nil
        table.insert(tracerPool, tracer)
    else
        tracer:Destroy()
    end
end

-- ===========================================
-- TRACER CREATION
-- ===========================================

--[[
    Creates a tracer part
    @param config: table - Tracer configuration
    @return Part - The tracer part
]]
local function createTracerPart(config)
    local tracer = getTracerFromPool()

    if not tracer then
        tracer = Instance.new("Part")
        tracer.Name = "BulletTracer"
        tracer.Anchored = true
        tracer.CanCollide = false
        tracer.CanQuery = false
        tracer.CanTouch = false
        tracer.CastShadow = false
        tracer.Material = Enum.Material.Neon

        -- Add attachment for beam (optional glow effect)
        local attachment = Instance.new("Attachment")
        attachment.Name = "TracerAttachment"
        attachment.Parent = tracer
    end

    tracer.Size = Vector3.new(config.thickness, config.thickness, config.length)
    tracer.Color = config.color
    tracer.Transparency = 0

    return tracer
end

-- ===========================================
-- PUBLIC API
-- ===========================================

--[[
    Fires a bullet tracer from origin to target
    @param origin: Vector3 - Start position (muzzle)
    @param target: Vector3 - End position (hit point)
    @param config: table? - Optional configuration overrides
]]
function BulletTracer.Fire(origin: Vector3, target: Vector3, config: table?)
    -- Merge config with defaults
    local cfg = {}
    for key, value in pairs(DEFAULT_CONFIG) do
        cfg[key] = config and config[key] or value
    end

    local direction = (target - origin).Unit
    local distance = (target - origin).Magnitude

    -- Create tracer
    local tracer = createTracerPart(cfg)

    -- Calculate travel time
    local travelTime = distance / cfg.speed

    -- Initial position (at muzzle)
    local startCFrame = CFrame.new(origin, origin + direction) * CFrame.new(0, 0, -cfg.length / 2)
    tracer.CFrame = startCFrame
    tracer.Parent = workspace.CurrentCamera -- Parent to camera for local visibility

    -- Animate tracer
    local startTime = tick()
    local connection

    connection = RunService.RenderStepped:Connect(function()
        local elapsed = tick() - startTime
        local progress = math.min(elapsed / travelTime, 1)

        -- Calculate current position
        local currentDistance = distance * progress
        local currentPos = origin + direction * currentDistance

        -- Update tracer CFrame
        tracer.CFrame = CFrame.new(currentPos, currentPos + direction) * CFrame.new(0, 0, -cfg.length / 2)

        -- Fade out near the end
        if progress > 0.8 then
            local fadeProgress = (progress - 0.8) / 0.2
            tracer.Transparency = fadeProgress
        end

        -- Complete
        if progress >= 1 then
            connection:Disconnect()

            -- Quick fade out
            local fadeTween = TweenService:Create(tracer, TweenInfo.new(cfg.fadeTime), {
                Transparency = 1
            })
            fadeTween:Play()
            fadeTween.Completed:Connect(function()
                returnTracerToPool(tracer)
            end)
        end
    end)
end

--[[
    Fires an instant tracer (no travel time, just visual line)
    @param origin: Vector3 - Start position
    @param target: Vector3 - End position
    @param config: table? - Optional configuration
]]
function BulletTracer.FireInstant(origin: Vector3, target: Vector3, config: table?)
    local cfg = {}
    for key, value in pairs(DEFAULT_CONFIG) do
        cfg[key] = config and config[key] or value
    end

    local direction = (target - origin).Unit
    local distance = (target - origin).Magnitude

    -- Create a line from origin to target
    local tracer = Instance.new("Part")
    tracer.Name = "InstantTracer"
    tracer.Anchored = true
    tracer.CanCollide = false
    tracer.CanQuery = false
    tracer.CanTouch = false
    tracer.CastShadow = false
    tracer.Material = Enum.Material.Neon
    tracer.Color = cfg.color
    tracer.Size = Vector3.new(cfg.thickness, cfg.thickness, distance)

    local midpoint = origin + direction * (distance / 2)
    tracer.CFrame = CFrame.new(midpoint, target)
    tracer.Parent = workspace.CurrentCamera

    -- Fade out
    local fadeTween = TweenService:Create(tracer, TweenInfo.new(0.15), {
        Transparency = 1,
        Size = Vector3.new(cfg.thickness * 0.5, cfg.thickness * 0.5, distance)
    })
    fadeTween:Play()
    fadeTween.Completed:Connect(function()
        tracer:Destroy()
    end)
end

--[[
    Creates a muzzle flash effect
    @param position: Vector3 - Muzzle position
    @param direction: Vector3 - Forward direction
    @param config: table? - Optional configuration
]]
function BulletTracer.MuzzleFlash(position: Vector3, direction: Vector3, config: table?)
    local flash = Instance.new("Part")
    flash.Name = "MuzzleFlash"
    flash.Anchored = true
    flash.CanCollide = false
    flash.CanQuery = false
    flash.CanTouch = false
    flash.CastShadow = false
    flash.Material = Enum.Material.Neon
    flash.Color = Color3.fromRGB(255, 200, 100)
    flash.Size = Vector3.new(0.3, 0.3, 0.5)
    flash.Transparency = 0.3

    flash.CFrame = CFrame.new(position, position + direction)
    flash.Parent = workspace.CurrentCamera

    -- Add point light
    local light = Instance.new("PointLight")
    light.Color = Color3.fromRGB(255, 180, 80)
    light.Brightness = 3
    light.Range = 8
    light.Parent = flash

    -- Quick flash animation
    local flashTween = TweenService:Create(flash, TweenInfo.new(0.05), {
        Size = Vector3.new(0.5, 0.5, 0.8),
        Transparency = 1
    })
    flashTween:Play()
    flashTween.Completed:Connect(function()
        flash:Destroy()
    end)
end

--[[
    Creates an impact effect at hit position
    @param position: Vector3 - Hit position
    @param normal: Vector3 - Surface normal
    @param material: string? - Hit material for different effects
]]
function BulletTracer.ImpactEffect(position: Vector3, normal: Vector3, material: string?)
    -- Spark/debris part
    local impact = Instance.new("Part")
    impact.Name = "ImpactEffect"
    impact.Anchored = true
    impact.CanCollide = false
    impact.CanQuery = false
    impact.CanTouch = false
    impact.CastShadow = false
    impact.Material = Enum.Material.Neon
    impact.Color = Color3.fromRGB(255, 200, 150)
    impact.Size = Vector3.new(0.2, 0.2, 0.2)
    impact.Transparency = 0

    impact.CFrame = CFrame.new(position, position + normal)
    impact.Parent = workspace.CurrentCamera

    -- Expand and fade
    local impactTween = TweenService:Create(impact, TweenInfo.new(0.15), {
        Size = Vector3.new(0.8, 0.8, 0.1),
        Transparency = 1
    })
    impactTween:Play()
    impactTween.Completed:Connect(function()
        impact:Destroy()
    end)

    -- TODO: Add particle emitter for sparks/debris based on material
end

return BulletTracer
