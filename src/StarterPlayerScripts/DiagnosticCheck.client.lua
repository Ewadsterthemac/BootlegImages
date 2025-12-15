--[[
    DiagnosticCheck.client.lua
    Run this to check if modules are set up correctly
    Location: StarterPlayerScripts/DiagnosticCheck
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

print("========== DIAGNOSTIC CHECK ==========")

-- Check folder structure
local function checkExists(parent, name, expectedClass)
    local child = parent:FindFirstChild(name)
    if child then
        local classMatch = child:IsA(expectedClass)
        if classMatch then
            print("✓ " .. parent.Name .. "/" .. name .. " (" .. expectedClass .. ")")
            return child
        else
            warn("✗ " .. parent.Name .. "/" .. name .. " exists but is " .. child.ClassName .. ", expected " .. expectedClass)
            return nil
        end
    else
        warn("✗ MISSING: " .. parent.Name .. "/" .. name)
        return nil
    end
end

-- Check ReplicatedStorage structure
print("\n-- Checking ReplicatedStorage --")
local configFolder = checkExists(ReplicatedStorage, "Config", "Folder")
local modulesFolder = checkExists(ReplicatedStorage, "Modules", "Folder")

-- Check Config folder contents
if configFolder then
    print("\n-- Checking Config folder --")
    local gameConfig = checkExists(configFolder, "GameConfig", "ModuleScript")

    if gameConfig then
        local success, result = pcall(function()
            return require(gameConfig)
        end)
        if success then
            print("✓ GameConfig loads successfully")
        else
            warn("✗ GameConfig FAILED to load: " .. tostring(result))
        end
    end
end

-- Check Modules folder contents
if modulesFolder then
    print("\n-- Checking Modules folder --")

    local modules = {"HealthSystem", "StaminaSystem", "NetworkManager"}
    for _, moduleName in ipairs(modules) do
        local mod = checkExists(modulesFolder, moduleName, "ModuleScript")

        if mod then
            local success, result = pcall(function()
                return require(mod)
            end)
            if success then
                print("✓ " .. moduleName .. " loads successfully")
            else
                warn("✗ " .. moduleName .. " FAILED to load: " .. tostring(result))
            end
        end
    end
end

-- Check Events folder (created by server)
print("\n-- Checking Events folder --")
local eventsFolder = ReplicatedStorage:FindFirstChild("Events")
if eventsFolder then
    print("✓ Events folder exists")
else
    print("○ Events folder not yet created (server creates this)")
end

print("\n========== END DIAGNOSTIC ==========")
