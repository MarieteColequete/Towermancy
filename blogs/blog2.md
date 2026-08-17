## Introduction
**Towermancy** is a 2D tower defense game[^1]. It features common attributes from the genre, such as wave-based enemy attacks, predetermined enemy paths and tower placement. The main mechanic consists of how towers are acquired and modified: towers have base stats that can be altered by equipping mods, which range from stat changes to conditional triggers that activate during combat.

There are no levels. Instead, the player starts a "run", where they will attempt to achieve the highest score possible by surviving as many enemy waves as they can.

## Mechanics

### Map

#### Structure
The map is generated procedurally and its structure is composed of two square grid patterns: **cells** and **chunks**.

- **Cells** are the smallest unit of scale within a map. Each of them can contain either a tower, empty space, or an enemy path.
- **Chunks** consist of A × A[^2] cell squares and are used to orchestrate render distance and map expansion.

#### Paths
Paths are the predetermined routes enemies follow to reach the player's base. Path generation is driven by a height map: paths extend like rivers, only moving to chunks at equal or lower height. This guarantees that paths always have at least one direction to expand, regardless of how many branches exist.

Paths can fork and end, but there will always be at least one open path ("open" meaning capable of being expanded). Towers cannot be placed over path cells.

#### Ghost chunks
When a path expands into a chunk, it registers its potential next steps as ghost chunks: slots that do not exist yet but are marked as reserved. This prevents two paths from walking into each other's future space without requiring any global lookahead. As long as at least one ghost chunk exists, the generation is guaranteed to continue.

#### Expansion
The map grows as the run progresses. At the start of the run, an initial chunk is generated along with the player's base. After each wave, the map expands by X additional chunks. Each newly generated chunk includes a continuation of an existing path. Additionally, a new chunk may introduce a fork, provided the token economy allows it.

### Enemies & Health points

#### Enemy behavior
Enemies appear in numbered waves (e.g., **"Wave 0"**, **"Wave 1"**, **"Wave 2"**, etc.), following a predetermined path that leads from either a dead end or the furthest point of an active path to the player's base, removing health points (HP) on arrival. Each wave, enemies are stronger and come in higher quantities. After a wave, enemies stop spawning until the player starts the next wave.

- Every **10 waves**, an **Elite Wave** occurs. One **Boss** enemy spawns alongside the regular wave, at the farthest spawn point.
- Every **100 waves**, an **Ultimate Wave** occurs. One **Uber Boss** enemy spawns alongside the regular wave, at the farthest spawn point.

#### Enemy types
There are six enemy types, each with distinct stats and behavior:

- **Normie**: Baseline enemy. Average stats across the board.
- **Rogue**: Fast and fragile. Low HP, high movement speed.
- **Warrior**: Durable frontliner. Higher HP, armor and plating, lower speed.
- **Wizard**: Moderate speed, no armor, but applies plating that reduces incoming damage.
- **Boss**: Elite enemy. High HP, armor and plating. Spawns only on Elite Waves.
- **Uber Boss**: Ultimate enemy. Very high HP and defenses. Spawns only on Ultimate Waves.

#### Enemy stats
Enemies possess the following stats:

- **Health points (HP)**: The amount of damage the enemy can endure before dying.
- **Movement speed**: How fast the enemy traverses paths.
- **Armor**: Reduces incoming damage by a percentage, applied after plating.
- **Plating**: Reduces incoming damage by a flat amount per hit, applied before armor. Each hit is reduced by the plating value, to a minimum of 1.
- **Damage**: The amount of HP removed from the player's base on arrival.
- **Gold reward**: The amount of gold given to the player when the enemy is killed.

#### Wave scaling
Enemy HP increases every 10 waves by a fixed multiplier. Enemy speed and spawn rate also increase linearly up to wave 200, reaching three times the base values. The number of enemies per wave scales using a token economy: each wave grants a token budget, which is spent on enemy groups. Costlier enemy types produce smaller groups.

#### Health points
The player starts the run with D[^2] Health Points (HP). Each time an enemy successfully reaches the base, HP are reduced according to the enemy's damage stat. If the player's HP reach **0 or below**, the run ends immediately.

### Towers & Economy

#### Tower structure
Towers are constructs placed by the player on empty chunks. Each tower is composed of three nodes with distinct responsibilities:

- **Tower**: Holds stats, level scaling, and targeting logic. Exposes getters used by all other components.
- **TowerVisuals**: Handles all visual behavior, including cannon rotation and animations.
- **TowerWeapon**: Handles firing logic using an accumulator-based attack rate. Spawns a projectile scene on each shot.

Stats scale with level using a base value plus a per-level increment. The tower's level equals the current wave at the time of placement.

#### Projectiles
Each tower type fires a projectile scene. The projectile handles its own movement, lifetime, and collision. On instantiation it receives the tower's stats via `setup()`. The base projectile class exposes virtual hooks (`on_spawn`, `on_hit`, `on_lifetime_expired`) for subclass extension without modifying base behavior.

#### Mods
Towers can be equipped with mods. Mods are modifiers that alter tower behavior, ranging from stat changes to conditional triggers. Stat mods use four keywords:

- **Increased** / **Reduced**: Additive with other sources of the same keyword.
- **More** / **Less**: Multiplicative, applied after all additive modifiers.

Trigger mods activate under specific conditions (e.g., on hit, on kill) and can alter targeting, projectile behavior, or other tower properties.

#### Shop
The shop is available between waves. It displays a fixed set of tower slots, each configured with a base price and a price increment. Each time a tower of a given type is purchased, its price increases permanently for the rest of the run.

Tower stats shown in the shop reflect the level the tower would have if bought at the current wave. Placing a tower enters a placement mode: the tower's icon follows the cursor, and a circle preview shows the optics range. Valid placement requires an empty chunk. Confirming placement spends the gold and registers the chunk as built.

## Milestones

### M1: Map generation & basic interface
To achieve this milestone, the game must be able to:

- Generate paths procedurally using a height map.
- Expand the map after each wave.
- Show basic UI elements: HP, wave counter, enemy counter, gold counter, "Next wave" button, notification system.

### M2: Enemies & HP
To achieve this milestone, the game must be able to:

- Spawn enemies from dead ends and active path frontiers.
- Manage and display wave logic, including elite and ultimate waves.
- Manage HP logic and end the run on death.

### M3: Towers & shop
To achieve this milestone, the game must be able to:

- Place towers on valid chunks via the shop.
- Fire projectiles at enemies within range.
- Manage the shop, pricing, and gold economy.

[^1]: _Tower defense_. (2020, July 20). Wikipedia. https://en.wikipedia.org/wiki/Tower_defense

[^2]: Capital letters represent values to be determined during development.
