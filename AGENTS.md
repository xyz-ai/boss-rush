# Boss Rush Codex Agent Rules

This is a Godot 4.x indie card-battle project.

Core design:
- Single-player PvE
- Card-based battle
- Information inference
- Psychological duel
- Dark cinematic tabletop scene
- Data-driven architecture
- MVP stage

General rules:
1. Do not rewrite combat logic unless explicitly asked.
2. Do not delete BossDeckView or BossBattleDeckView.
3. Do not remove existing assets.
4. Keep asset paths stable.
5. Keep UI readable above all.
6. Prefer small, reversible changes.
7. Do not bake text into UI images.
8. Separate image categories clearly:
   - backgrounds
   - UI textures
   - card portraits
   - card frames
   - card overlays
   - character sprites
9. Character sprites must use transparent background.
10. UI textures should usually use transparent background.
11. Background images should not include UI elements.
12. Card portraits should not include card frames unless explicitly requested.
13. Do not turn the game into a backend/tool interface.
14. Preserve the current playable battle loop.