# Devlog 04: Wrapping up

---

# What got built

Towermancy started as a question about map generation and ended up as a surprisingly solid technical foundation. The core systems are all there and talking to each other: procedural path generation with guaranteed expansion, a wave system with token-based enemy composition and adaptive spawn rates, a tower placement system with range preview and a shop, and an enemy pathfinding approach that scales to any map size in constant time.

The architecture held up throughout development. Separating WorldData from MapDirector, keeping WaveDirector decoupled from world state, and splitting towers into three nodes with distinct responsibilities all paid off when adding new features. Nothing had to be rewritten from scratch mid-project, which for a solo project in this timeframe is the best outcome I could have hoped for.

# What I am happy with

The map generation is the piece I am most proud of. The proof that paths cannot fully block, the ghost chunk system, the depth-based pathfinding: these are elegant solutions to problems that could have gotten ugly fast. The wave system also turned out well: token budgets, group cycling, adaptive intervals and elite waves are all working and feel like a real system rather than a prototype.

Overall, what exists right now is a technical base that could be expanded into a complete game. The architecture supports it.

# What did not make it

Enemy types are the weakest part of the codebase. They are hardcoded in a match statement inside WaveDirector instead of being data-driven resources. It works, but it is a proof of concept, not a real system. That would be the first thing to fix before adding more content.

The UI is functional but not pretty. That was a deliberate call: the point of this project was the systems, not the interface, but it is worth acknowledging.

Web export and full controller support did not make the deadline. Camera movement with a controller works, but navigating the shop and placement UI with it does not. Web builds would have required additional testing time that was not available.

# What comes next

The foundation is there. Building on top of it would mean implementing mods (stat modifiers and triggers), a proper enemy type system driven by resources, a main menu and settings screen, save files, a Steam leaderboard, full controller support, and eventually a Steam release. The scope is clear and the codebase is ready for it.
