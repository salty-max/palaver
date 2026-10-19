# Palaver artwork

Generated with the built-in image_gen tool on 19 October 2026, matching the
painted inventory-item style of Lorekeeper's Codex, Keyring and Second Wind.
The exact generation prompt and consulted style references are recorded in
[logo-prompts.json](logo-prompts.json).

- `logo-master.png`: original generated master, 1254px square.
- `logo-1024.png`: 1024px square for store and project artwork.
- `logo.png`: 512px square for general use.
- `../addon/Palaver/Media/Logo.tga`: uncompressed 256px RGBA game texture,
  with the family's rounded corners (radius 34).

The PNGs retain the full opaque navy square. Resize from the master for
future exports. ImageMagick produces the smaller files and the game texture.
The TGA's mask is a white `roundrectangle 0,0 255,255 34,34` on black,
composited with CopyOpacity with the mask's alpha disabled, so its grayscale
values supply the opacity. The addon listing uses this texture.
