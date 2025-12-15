# Roblox Extraction Shooter - Game Plan

## Game Concept
An extraction-style looter shooter where players deploy into hostile zones, collect valuable loot, fight AI enemies and other players, and must successfully extract to keep their gains. Death means losing everything brought into the raid.

---

## Core Gameplay Loop

```
LOBBY → LOADOUT → DEPLOY → LOOT/FIGHT → EXTRACT (or DIE)
                                ↓
                    SUCCESS: Keep loot, gain XP/currency
                    FAILURE: Lose gear brought in
```

---

## Phase 1: Foundation Systems

### 1.1 Player Character System
- [ ] First-person/Third-person camera toggle
- [ ] Health system (head/torso/limbs with different damage multipliers)
- [ ] Stamina system (sprinting, jumping consumes stamina)
- [ ] Hunger/Thirst (optional - adds survival element)
- [ ] Status effects (bleeding, fractures, pain)

### 1.2 Movement System
- [ ] Walking/Running/Sprinting
- [ ] Crouching/Prone
- [ ] Leaning (left/right peek)
- [ ] Vaulting over obstacles
- [ ] Climbing ladders
- [ ] Jumping
- [ ] Fall damage

### 1.3 Basic Networking
- [ ] Server-authoritative movement
- [ ] Client-side prediction
- [ ] Lag compensation for gunplay
- [ ] Anti-cheat measures

---

## Phase 2: Combat Systems

### 2.1 Weapon System
- [ ] Weapon categories:
  - Pistols
  - SMGs
  - Assault Rifles
  - Shotguns
  - Sniper Rifles
  - Melee weapons
- [ ] Weapon stats:
  - Damage
  - Fire rate
  - Recoil pattern
  - Accuracy/spread
  - Range/falloff
  - Ergonomics
  - Reload speed

### 2.2 Gunplay Mechanics
- [ ] Hitscan or projectile-based bullets
- [ ] Bullet penetration (materials)
- [ ] Bullet drop (for snipers)
- [ ] Recoil patterns (vertical + horizontal)
- [ ] ADS (Aim Down Sights) system
- [ ] Hip-fire accuracy penalty
- [ ] Point-firing (laser accuracy)

### 2.3 Attachment System
- [ ] Optics (red dots, holographic, scopes)
- [ ] Muzzle devices (suppressors, compensators, flash hiders)
- [ ] Grips (vertical, angled, handstops)
- [ ] Stocks
- [ ] Magazines (extended, drum mags)
- [ ] Tactical devices (flashlights, lasers)

### 2.4 Armor System
- [ ] Helmet (head protection + ricochet chance)
- [ ] Body armor (chest rig/plate carrier)
- [ ] Armor classes (1-6 rating system)
- [ ] Armor durability (degrades when hit)
- [ ] Armor penetration mechanics

---

## Phase 3: Inventory & Loot

### 3.1 Inventory System
- [ ] Grid-based inventory (Tetris-style)
- [ ] Container types:
  - Pockets (limited slots)
  - Backpacks (various sizes)
  - Chest rigs (quick-access slots)
  - Secure container (keeps items on death)
- [ ] Item rotation in inventory
- [ ] Quick-slot bar for consumables

### 3.2 Loot Categories
- [ ] Weapons & Ammo
- [ ] Armor & Gear
- [ ] Medical supplies
- [ ] Food & Drink
- [ ] Valuables (for selling)
- [ ] Keys & Keycards
- [ ] Quest items
- [ ] Crafting materials

### 3.3 Loot Spawning
- [ ] Static spawn points with random loot tables
- [ ] Loot tiers (common → rare → legendary)
- [ ] High-value loot zones (high risk/reward)
- [ ] Dynamic loot economy

---

## Phase 4: Map & Environment

### 4.1 Map Design Principles
- [ ] Multiple extraction points
- [ ] Chokepoints and open areas
- [ ] Verticality (buildings, rooftops)
- [ ] Cover objects throughout
- [ ] Loot hotspots
- [ ] Spawn zones (spread out)

### 4.2 First Map: "Industrial Zone"
- [ ] Abandoned factory complex
- [ ] Warehouse buildings
- [ ] Office areas
- [ ] Underground sections
- [ ] Outdoor courtyards
- [ ] Size: Medium (10-15 min traversal)

### 4.3 Environmental Features
- [ ] Locked doors (require keys)
- [ ] Breakable doors
- [ ] Searchable containers (crates, filing cabinets, safes)
- [ ] Interactive objects (switches, levers)
- [ ] Ambient audio (footsteps, distant gunfire)

### 4.4 Extraction System
- [ ] Multiple extract points per map
- [ ] Extract timers (7-15 seconds)
- [ ] Conditional extracts (need key, money, etc.)
- [ ] Extract camping deterrents
- [ ] Extract notification/countdown

---

## Phase 5: AI & PvE

### 5.1 AI Enemy Types
- [ ] Scavengers (basic enemies, light gear)
- [ ] Raiders (mid-tier, decent AI)
- [ ] Bosses (unique, heavy gear, patrol routes)
- [ ] Roaming groups

### 5.2 AI Behavior
- [ ] Patrol patterns
- [ ] Alert states (idle, suspicious, combat)
- [ ] Cover usage
- [ ] Flanking behavior
- [ ] Communication (calling out player position)
- [ ] Suppression response
- [ ] Healing/retreating when hurt

### 5.3 AI Difficulty Scaling
- [ ] Accuracy based on distance
- [ ] Reaction time variations
- [ ] Decision-making delays
- [ ] Aggression levels

---

## Phase 6: Progression & Economy

### 6.1 Player Progression
- [ ] Account level (XP-based)
- [ ] Skill system (optional):
  - Combat skills
  - Survival skills
  - Technical skills
- [ ] Reputation with traders
- [ ] Unlockable items

### 6.2 Economy System
- [ ] Primary currency (earned in-raid)
- [ ] Traders (buy/sell items)
- [ ] Flea Market (player-to-player trading)
- [ ] Insurance system (chance to recover gear)
- [ ] Dynamic pricing based on supply/demand

### 6.3 Hideout/Stash
- [ ] Personal stash (stores items between raids)
- [ ] Stash upgrades (more space)
- [ ] Hideout modules:
  - Workbench (craft weapons/mods)
  - Medstation (craft medical items)
  - Generator (powers modules)
  - Bitcoin farm (passive income - optional)

---

## Phase 7: UI/UX

### 7.1 In-Raid UI
- [ ] Health/stamina indicators
- [ ] Ammo counter
- [ ] Compass/bearing
- [ ] Extraction timer
- [ ] Status effects display
- [ ] Minimal HUD option

### 7.2 Menus
- [ ] Main menu
- [ ] Character screen (loadout)
- [ ] Stash/inventory
- [ ] Traders
- [ ] Map selection
- [ ] Settings
- [ ] Social (friends, party)

### 7.3 Audio Design
- [ ] Positional 3D audio
- [ ] Footstep sounds by surface
- [ ] Gunshot audio with distance falloff
- [ ] Environmental ambient sounds
- [ ] Music (menu, extraction, etc.)

---

## Phase 8: Multiplayer & Sessions

### 8.1 Raid System
- [ ] Server instances (8-12 players per raid)
- [ ] AI filling (if player count low)
- [ ] Raid timer (25-45 minutes)
- [ ] Late spawn option
- [ ] Map voting or random selection

### 8.2 Grouping
- [ ] Solo queue
- [ ] Duo/Squad (2-4 players)
- [ ] In-game VOIP (proximity)
- [ ] Team identification (armbands)

### 8.3 Matchmaking
- [ ] Skill-based (optional)
- [ ] Gear-based (PMC rating)
- [ ] Region selection
- [ ] Queue time management

---

## Technical Architecture (Roblox-Specific)

### Server Structure
```
ReplicatedStorage/
├── Modules/
│   ├── WeaponSystem
│   ├── InventorySystem
│   ├── CombatSystem
│   └── NetworkingUtils

ServerStorage/
├── GameData/
│   ├── WeaponConfigs
│   ├── ItemDatabase
│   ├── MapData
│   └── AIConfigs

ServerScriptService/
├── GameManager
├── RaidController
├── LootSpawner
├── AIController
├── CombatHandler
└── DataService

StarterPlayerScripts/
├── ClientController
├── InputHandler
├── UIController
├── WeaponClient
└── CameraController
```

### Data Storage
- [ ] DataStore for player progression
- [ ] ProfileService or similar for robust saves
- [ ] Session locking to prevent data loss
- [ ] Inventory serialization

---

## Development Priorities (MVP)

### Minimum Viable Product Checklist:
1. **Week 1-2**: Basic character controller + FPS camera
2. **Week 3-4**: Simple weapon system (1-2 guns)
3. **Week 5-6**: Basic inventory (backpack + pockets)
4. **Week 7-8**: First map with loot spawns
5. **Week 9-10**: Extraction system
6. **Week 11-12**: Basic AI enemies
7. **Week 13-14**: Data persistence + stash
8. **Week 15-16**: Polish, testing, balancing

---

## Future Content Ideas

### Additional Maps
- Urban city streets
- Forest/wilderness area
- Military base
- Shoreline/coastal area
- Underground bunker complex

### Additional Features
- Seasonal events
- Battle pass system
- Clans/guilds
- Tournaments
- Prestige system

---

## Risk Assessment

| Risk | Mitigation |
|------|------------|
| Performance issues | LOD systems, streaming, optimization passes |
| Exploits/cheating | Server authority, sanity checks, moderation |
| Data loss | Backup systems, session locking |
| Player retention | Regular updates, events, balancing |
| Scope creep | Stick to MVP, iterate based on feedback |

---

## Success Metrics

- Daily Active Users (DAU)
- Average session length
- Retention rates (D1, D7, D30)
- Raid survival rate
- Player feedback/ratings

---

*Document Version: 1.0*
*Created: December 2024*
