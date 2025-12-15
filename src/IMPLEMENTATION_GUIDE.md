# Implementation Guide - Roblox Extraction Shooter

This guide explains how to properly implement the foundation scripts in Roblox Studio.

---

## Project Structure

```
src/
├── ServerScriptService/
│   └── PlayerController.server.lua      -- Server-side player management
├── StarterPlayerScripts/
│   ├── MovementController.client.lua    -- Client movement handling
│   └── CameraController.client.lua      -- First-person camera system
├── ReplicatedStorage/
│   ├── Config/
│   │   └── GameConfig.lua               -- All game configuration
│   ├── Modules/
│   │   ├── HealthSystem.lua             -- Health/damage system
│   │   ├── StaminaSystem.lua            -- Stamina management
│   │   └── NetworkManager.lua           -- Network communication
│   └── Events/                          -- (Created automatically)
└── ServerStorage/
    ├── GameData/                        -- Item databases, etc.
    └── Modules/                         -- Server-only modules
```

---

## Step-by-Step Setup in Roblox Studio

### Step 1: Create the Folder Structure

1. Open Roblox Studio and create a new Baseplate or open your project
2. In the Explorer panel, create these folders:

**In ReplicatedStorage:**
```
ReplicatedStorage
├── Config (Folder)
└── Modules (Folder)
```

**In ServerStorage:**
```
ServerStorage
├── GameData (Folder)
└── Modules (Folder)
```

### Step 2: Add the Scripts

#### Configuration (ReplicatedStorage/Config)
1. Right-click on `Config` folder → Insert Object → ModuleScript
2. Rename it to `GameConfig`
3. Copy contents from `src/ReplicatedStorage/Config/GameConfig.lua`

#### Shared Modules (ReplicatedStorage/Modules)
1. Right-click on `Modules` folder → Insert Object → ModuleScript
2. Create these modules and copy their contents:
   - `HealthSystem`
   - `StaminaSystem`
   - `NetworkManager`

#### Server Script (ServerScriptService)
1. Right-click on `ServerScriptService` → Insert Object → Script
2. Rename it to `PlayerController`
3. Copy contents from `src/ServerScriptService/PlayerController.server.lua`

#### Client Scripts (StarterPlayerScripts)
1. Right-click on `StarterPlayer` → `StarterPlayerScripts`
2. Insert Object → LocalScript for each:
   - `MovementController`
   - `CameraController`
3. Copy the respective contents

---

## Configuration Guide

### Adjusting Game Feel

All gameplay values are in `GameConfig.lua`. Key sections:

#### Movement Speed
```lua
Movement = {
    WalkSpeed = 12,        -- Normal walking
    SprintSpeed = 20,      -- While holding Shift
    CrouchSpeed = 6,       -- While crouching
    ProneSpeed = 2,        -- While prone
}
```

#### Health & Damage
```lua
Health = {
    MaxHealth = 100,
    HeadMultiplier = 2.0,  -- Headshots deal 2x
    TorsoMultiplier = 1.0,
    LimbMultiplier = 0.7,  -- Reduced limb damage
}
```

#### Stamina
```lua
Stamina = {
    MaxStamina = 100,
    SprintDrain = 15,      -- Drain per second
    JumpCost = 20,         -- Cost per jump
    RegenRate = 25,        -- Recovery per second
}
```

#### Camera
```lua
Camera = {
    DefaultFOV = 70,
    SprintFOV = 80,        -- Wider FOV when sprinting
    ADSFOV = 50,           -- Zoomed FOV when aiming
    HeadBobEnabled = true,
    HeadBobIntensity = 0.03,
}
```

---

## Controls Reference

| Key | Action |
|-----|--------|
| W/A/S/D | Movement |
| Shift | Sprint (hold) |
| Ctrl | Toggle Crouch |
| Z | Toggle Prone |
| Space | Jump |
| Q | Lean Left (hold) |
| E | Lean Right (hold) |
| Right Mouse | Aim Down Sights (hold) |
| V | Toggle First/Third Person |

---

## System Architecture

### Health System Flow
```
Client fires weapon
       ↓
Server receives DamageEvent
       ↓
Server validates (distance, rate limit)
       ↓
HealthSystem.CalculateDamage() → applies body part multiplier + armor
       ↓
HealthSystem.TakeDamage() → updates health, triggers status effects
       ↓
HealthUpdateEvent fired to client
       ↓
Client updates UI
```

### Movement System Flow
```
Client input (WASD, Shift, etc.)
       ↓
MovementController processes input
       ↓
StaminaSystem checks/consumes stamina
       ↓
Humanoid.WalkSpeed updated
       ↓
Server validates position periodically
```

### Network Events

| Event | Direction | Purpose |
|-------|-----------|---------|
| `DamageEvent` | Client → Server | Report weapon hits |
| `HealthUpdateEvent` | Server → Client | Sync health changes |
| `StaminaUpdateEvent` | Server → Client | Sync stamina (optional) |
| `StatusEffectEvent` | Server → Client | Bleeding, fractures, etc. |
| `DeathEvent` | Server → Client | Notify player death |
| `MovementValidation` | Client → Server | Anti-cheat position check |

---

## Adding New Features

### Adding a New Weapon

1. Create weapon config in `GameConfig.lua`:
```lua
GameConfig.Weapons = {
    AK47 = {
        damage = 35,
        fireRate = 600, -- RPM
        recoilVertical = 2.5,
        recoilHorizontal = 0.8,
        magSize = 30,
        reloadTime = 2.5,
    }
}
```

2. Create a weapon module (future implementation)

### Adding a New Status Effect

1. Add config in `GameConfig.lua`:
```lua
StatusEffects = {
    NewEffect = {
        damagePerTick = 5,
        duration = 10,
        -- etc.
    }
}
```

2. Add handling in `HealthSystem.lua`

---

## Common Issues & Solutions

### Issue: Character not becoming invisible in first person
**Solution:** Ensure `setCharacterTransparency()` is called after character loads. The function sets `LocalTransparencyModifier` on all parts.

### Issue: Movement feels sluggish
**Solution:** Adjust `WalkSpeed` and `SprintSpeed` in GameConfig. Also check `Humanoid.WalkSpeed` isn't being overwritten elsewhere.

### Issue: Stamina drains too fast
**Solution:** Reduce `SprintDrain` value or increase `MaxStamina` in config.

### Issue: Health not syncing
**Solution:** Ensure `PlayerController.server.lua` is in ServerScriptService (not StarterPlayerScripts). Health is server-authoritative.

### Issue: Camera jittery
**Solution:** Check for conflicting camera scripts. Disable any default Roblox camera scripts. Ensure only one camera controller is active.

---

## Testing Checklist

- [ ] Character spawns correctly
- [ ] Movement (WASD) works
- [ ] Sprint (Shift) increases speed and drains stamina
- [ ] Crouch (Ctrl) lowers camera and slows movement
- [ ] Jump (Space) consumes stamina
- [ ] Camera follows mouse input smoothly
- [ ] ADS (Right-click) zooms FOV
- [ ] Lean (Q/E) tilts camera
- [ ] Health displays correctly
- [ ] Taking damage updates health
- [ ] Death triggers correctly at 0 HP

---

## Next Steps

After implementing the foundation, continue with:

1. **Weapon System** - Shooting, reloading, recoil
2. **Inventory System** - Grid-based item management
3. **Loot System** - Spawning and pickup
4. **AI System** - Enemy NPCs
5. **Map** - First playable area
6. **Extraction** - Win condition

---

## File Naming Convention

- `.server.lua` - Server scripts (ServerScriptService)
- `.client.lua` - Client scripts (StarterPlayerScripts)
- `.lua` - ModuleScripts (can be required by either)

---

*Guide Version: 1.0*
