# Boss Rush Asset Pipeline Skill

Use this skill whenever generating, organizing, or integrating visual assets for Boss Rush.

## Visual Direction

Boss Rush uses:
- dark cinematic
- noir
- low saturation
- warm amber light
- oppressive office/tabletop duel mood
- clean readable UI overlays

Avoid:
- bright mobile game UI
- sci-fi blue hologram UI
- flat admin dashboard look
- cute cartoon style
- over-detailed UI backgrounds
- baked-in text unless explicitly requested

## Asset Categories

Always keep assets separated by category.

Recommended paths:

- Backgrounds:
  assets/battle/backgrounds/

- Boss sprites:
  assets/battle/boss/

- Table textures:
  assets/battle/table/

- Card backs:
  assets/battle/cards/backs/

- Card frames:
  assets/battle/cards/frames/

- Card overlays:
  assets/battle/cards/overlays/

- Card portraits:
  assets/battle/cards/portraits/

- Chips:
  assets/battle/chips/

- UI buttons:
  assets/ui/buttons/

- UI panels:
  assets/ui/panels/

- UI badges:
  assets/ui/badges/

- UI broadcast:
  assets/ui/broadcast/

## Transparency Rules

- Character sprites: transparent background required.
- UI textures: transparent background required unless explicitly stated otherwise.
- Card portraits: usually rectangular image, no transparent background required.
- Background images: no transparency required.
- Card frames and overlays: transparent background required.

## Naming Rules

Use lowercase snake_case.

Examples:
- button_primary.png
- panel_dark.png
- badge_hp.png
- broadcast_base.png
- frame_aggression.png
- overlay_selected.png
- card_aggression_01.png
- boss_default_idle.png

## Generation Rules

When generating assets by script:
- Use Python + Pillow if available.
- Do not require network.
- Do not overwrite existing files unless explicitly asked.
- Generate only the requested batch.
- Keep output dimensions stable.
- Do not generate Godot .import files manually.

## UI Readability

UI textures must:
- leave central areas clean for text
- avoid noisy patterns under labels
- use subtle borders
- support NinePatchRect or TextureRect usage
- avoid strong contrast inside the text area

## Batch Discipline

Generate assets in small batches.

Recommended batch size:
- 4 images per batch

Do not mix categories in one batch unless explicitly requested.