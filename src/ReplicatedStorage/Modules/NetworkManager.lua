--[[
    NetworkManager.lua
    Handles client-server communication and network optimization
    Location: ReplicatedStorage/Modules/NetworkManager

    This module provides:
    - Centralized RemoteEvent/Function management
    - Rate limiting
    - Data serialization helpers
    - Network latency tracking
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local IsServer = RunService:IsServer()
local IsClient = RunService:IsClient()

local NetworkManager = {}
NetworkManager.__index = NetworkManager

-- ===========================================
-- CONFIGURATION
-- ===========================================
local Config = {
    -- Rate limiting (requests per second)
    DefaultRateLimit = 30,
    DamageRateLimit = 10,
    MovementRateLimit = 20,

    -- Ping tracking
    PingInterval = 2,
    MaxStoredPings = 10,

    -- Data compression threshold (bytes)
    CompressionThreshold = 1000,
}

-- ===========================================
-- EVENT REGISTRY
-- ===========================================
local Events = {}
local Functions = {}
local RateLimiters = {} -- [Player] = { [eventName] = lastCallTime }

-- ===========================================
-- INITIALIZATION
-- ===========================================

--[[
    Initializes the NetworkManager
    Creates the Events folder if it doesn't exist
]]
function NetworkManager.Initialize()
    local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
    if not eventsFolder then
        eventsFolder = Instance.new("Folder")
        eventsFolder.Name = "Events"
        eventsFolder.Parent = ReplicatedStorage
    end

    return eventsFolder
end

-- ===========================================
-- EVENT CREATION
-- ===========================================

--[[
    Gets or creates a RemoteEvent
    @param name: string - Event name
    @return RemoteEvent
]]
function NetworkManager.GetEvent(name: string): RemoteEvent
    if Events[name] then
        return Events[name]
    end

    local eventsFolder = NetworkManager.Initialize()
    local event = eventsFolder:FindFirstChild(name)

    if not event and IsServer then
        event = Instance.new("RemoteEvent")
        event.Name = name
        event.Parent = eventsFolder
    elseif not event and IsClient then
        event = eventsFolder:WaitForChild(name, 10)
    end

    Events[name] = event
    return event
end

--[[
    Gets or creates a RemoteFunction
    @param name: string - Function name
    @return RemoteFunction
]]
function NetworkManager.GetFunction(name: string): RemoteFunction
    if Functions[name] then
        return Functions[name]
    end

    local eventsFolder = NetworkManager.Initialize()
    local func = eventsFolder:FindFirstChild(name)

    if not func and IsServer then
        func = Instance.new("RemoteFunction")
        func.Name = name
        func.Parent = eventsFolder
    elseif not func and IsClient then
        func = eventsFolder:WaitForChild(name, 10)
    end

    Functions[name] = func
    return func
end

-- ===========================================
-- RATE LIMITING (Server-side)
-- ===========================================

--[[
    Checks if a player can make a request (rate limiting)
    @param player: Player
    @param eventName: string
    @param limit: number? - Custom rate limit
    @return boolean - True if request is allowed
]]
function NetworkManager.CheckRateLimit(player: Player, eventName: string, limit: number?): boolean
    if not IsServer then return true end

    limit = limit or Config.DefaultRateLimit

    if not RateLimiters[player] then
        RateLimiters[player] = {}
    end

    local playerLimits = RateLimiters[player]
    local lastCall = playerLimits[eventName] or 0
    local now = tick()
    local minInterval = 1 / limit

    if now - lastCall < minInterval then
        return false
    end

    playerLimits[eventName] = now
    return true
end

--[[
    Clears rate limit data for a player
    @param player: Player
]]
function NetworkManager.ClearRateLimits(player: Player)
    RateLimiters[player] = nil
end

-- ===========================================
-- SERVER-SIDE HELPERS
-- ===========================================

--[[
    Fires an event to all players
    @param eventName: string
    @param ... - Data to send
]]
function NetworkManager.FireAllClients(eventName: string, ...)
    if not IsServer then return end

    local event = NetworkManager.GetEvent(eventName)
    if event then
        event:FireAllClients(...)
    end
end

--[[
    Fires an event to a specific player
    @param eventName: string
    @param player: Player
    @param ... - Data to send
]]
function NetworkManager.FireClient(eventName: string, player: Player, ...)
    if not IsServer then return end

    local event = NetworkManager.GetEvent(eventName)
    if event then
        event:FireClient(player, ...)
    end
end

--[[
    Fires an event to all players except one
    @param eventName: string
    @param excludePlayer: Player
    @param ... - Data to send
]]
function NetworkManager.FireAllClientsExcept(eventName: string, excludePlayer: Player, ...)
    if not IsServer then return end

    local event = NetworkManager.GetEvent(eventName)
    if event then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= excludePlayer then
                event:FireClient(player, ...)
            end
        end
    end
end

--[[
    Fires an event to players within a radius
    @param eventName: string
    @param position: Vector3
    @param radius: number
    @param ... - Data to send
]]
function NetworkManager.FireClientsInRadius(eventName: string, position: Vector3, radius: number, ...)
    if not IsServer then return end

    local event = NetworkManager.GetEvent(eventName)
    if not event then return end

    for _, player in ipairs(Players:GetPlayers()) do
        local character = player.Character
        if character then
            local root = character:FindFirstChild("HumanoidRootPart")
            if root and (root.Position - position).Magnitude <= radius then
                event:FireClient(player, ...)
            end
        end
    end
end

-- ===========================================
-- CLIENT-SIDE HELPERS
-- ===========================================

--[[
    Fires an event to the server
    @param eventName: string
    @param ... - Data to send
]]
function NetworkManager.FireServer(eventName: string, ...)
    if not IsClient then return end

    local event = NetworkManager.GetEvent(eventName)
    if event then
        event:FireServer(...)
    end
end

--[[
    Invokes a server function
    @param functionName: string
    @param ... - Arguments
    @return any - Server response
]]
function NetworkManager.InvokeServer(functionName: string, ...): any
    if not IsClient then return nil end

    local func = NetworkManager.GetFunction(functionName)
    if func then
        return func:InvokeServer(...)
    end
    return nil
end

-- ===========================================
-- CONNECTION HELPERS
-- ===========================================

--[[
    Connects a callback to a RemoteEvent (server-side)
    @param eventName: string
    @param callback: function(player, ...)
    @param rateLimit: number? - Optional rate limit
    @return RBXScriptConnection
]]
function NetworkManager.OnServerEvent(eventName: string, callback: (Player, ...any) -> (), rateLimit: number?): RBXScriptConnection
    if not IsServer then return end

    local event = NetworkManager.GetEvent(eventName)
    if not event then return end

    return event.OnServerEvent:Connect(function(player, ...)
        -- Check rate limit
        if rateLimit and not NetworkManager.CheckRateLimit(player, eventName, rateLimit) then
            warn("[NetworkManager] Rate limited:", player.Name, eventName)
            return
        end

        callback(player, ...)
    end)
end

--[[
    Connects a callback to a RemoteEvent (client-side)
    @param eventName: string
    @param callback: function(...)
    @return RBXScriptConnection
]]
function NetworkManager.OnClientEvent(eventName: string, callback: (...any) -> ()): RBXScriptConnection
    if not IsClient then return end

    local event = NetworkManager.GetEvent(eventName)
    if not event then return end

    return event.OnClientEvent:Connect(callback)
end

--[[
    Sets the callback for a RemoteFunction (server-side)
    @param functionName: string
    @param callback: function(player, ...) -> any
]]
function NetworkManager.OnServerInvoke(functionName: string, callback: (Player, ...any) -> any)
    if not IsServer then return end

    local func = NetworkManager.GetFunction(functionName)
    if func then
        func.OnServerInvoke = callback
    end
end

-- ===========================================
-- PING TRACKING (Client-side)
-- ===========================================

local PingHistory = {}
local CurrentPing = 0

--[[
    Gets the current estimated ping
    @return number - Ping in milliseconds
]]
function NetworkManager.GetPing(): number
    return CurrentPing
end

--[[
    Gets the average ping from history
    @return number - Average ping in milliseconds
]]
function NetworkManager.GetAveragePing(): number
    if #PingHistory == 0 then return 0 end

    local sum = 0
    for _, ping in ipairs(PingHistory) do
        sum = sum + ping
    end
    return sum / #PingHistory
end

-- Initialize ping tracking on client
if IsClient then
    local pingEvent = NetworkManager.GetEvent("PingEvent")

    -- Ping request handler
    if pingEvent then
        pingEvent.OnClientEvent:Connect(function(serverTime: number)
            local clientTime = tick()
            local roundTrip = (clientTime - serverTime) * 1000
            CurrentPing = roundTrip

            table.insert(PingHistory, roundTrip)
            if #PingHistory > Config.MaxStoredPings then
                table.remove(PingHistory, 1)
            end
        end)
    end
end

-- ===========================================
-- DATA SERIALIZATION HELPERS
-- ===========================================

--[[
    Serializes a Vector3 to a compact format
    @param vec: Vector3
    @return table
]]
function NetworkManager.SerializeVector3(vec: Vector3): table
    return {vec.X, vec.Y, vec.Z}
end

--[[
    Deserializes a Vector3 from compact format
    @param data: table
    @return Vector3
]]
function NetworkManager.DeserializeVector3(data: table): Vector3
    return Vector3.new(data[1], data[2], data[3])
end

--[[
    Serializes a CFrame to a compact format
    @param cf: CFrame
    @return table
]]
function NetworkManager.SerializeCFrame(cf: CFrame): table
    local components = {cf:GetComponents()}
    return components
end

--[[
    Deserializes a CFrame from compact format
    @param data: table
    @return CFrame
]]
function NetworkManager.DeserializeCFrame(data: table): CFrame
    return CFrame.new(unpack(data))
end

-- ===========================================
-- CLEANUP
-- ===========================================

-- Clean up rate limiters when players leave
if IsServer then
    Players.PlayerRemoving:Connect(function(player)
        NetworkManager.ClearRateLimits(player)
    end)
end

-- ===========================================
-- PREDEFINED EVENTS SETUP
-- ===========================================

-- Create standard game events
local StandardEvents = {
    "DamageEvent",
    "HealthUpdateEvent",
    "StaminaUpdateEvent",
    "StatusEffectEvent",
    "DeathEvent",
    "RespawnEvent",
    "MovementValidation",
    "PingEvent",
    "LootPickup",
    "InventoryUpdate",
    "ExtractionStart",
    "ExtractionComplete",
    "WeaponFire",
    "WeaponReload",
    "AIAlert",
}

local StandardFunctions = {
    "GetPlayerData",
    "GetInventory",
    "GetRaidInfo",
}

-- Pre-create events on server
if IsServer then
    for _, eventName in ipairs(StandardEvents) do
        NetworkManager.GetEvent(eventName)
    end
    for _, funcName in ipairs(StandardFunctions) do
        NetworkManager.GetFunction(funcName)
    end
end

return NetworkManager
