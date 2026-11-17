# Xenon 2: Megablast remake

![Xenon 2: Megablast remake](images/poster.png)

A tribute to the legendary **[Bitmap Brothers](https://en.wikipedia.org/wiki/The_Bitmap_Brothers)**.

In 1989 **[Xenon 2: Megablast](https://en.wikipedia.org/wiki/Xenon_2:_Megablast)** arrived on the [Amiga](https://en.wikipedia.org/wiki/Amiga) and the PC and changed what a shoot-'em-up could look and sound like: hand-crafted metallic graphics full of detail, organic levels that seemed alive, a shop where you traded with a grinning alien, and [Bomb the Bass](https://en.wikipedia.org/wiki/Bomb_the_Bass)'s *Megablast* pumping out of a home computer. It was a programming miracle of its era, smooth, fast and beautiful on machines with a fraction of the power of a phone today, and it is still remembered as one of the great games of the 16-bit years.

This project brings it back with love and respect: a faithful remake for modern computers, made with [Godot](https://godotengine.org/), that plays exactly as the original did, together with an **ENHANCED** edition that brings the game to high resolution screens.

## Play online

### [Play Xenon 2: Megablast remake in the browser](https://vpapanik.github.io/xenon-2-remake/)

## Download

Latest release: **[1.0.7](https://github.com/vpapanik/xenon-2-remake/releases/latest)**

| Platform | File |
|---|---|
| Windows 10 or later (x86_64) | [Xenon2Remake-1.0.7-windows-x86_64.zip](https://github.com/vpapanik/xenon-2-remake/releases/download/v1.0.7/Xenon2Remake-1.0.7-windows-x86_64.zip) : unzip and run `Xenon2Remake.exe`. Godot 4 no longer runs on Windows 7 or 8, where the online version may still play in the browser |
| Linux (x86_64) | [Xenon2Remake-1.0.7-linux-x86_64.tar.gz](https://github.com/vpapanik/xenon-2-remake/releases/download/v1.0.7/Xenon2Remake-1.0.7-linux-x86_64.tar.gz) : extract and run `./Xenon2Remake.x86_64` |
| macOS (Apple Silicon and Intel) | [Xenon2Remake-1.0.7-macos-universal.zip](https://github.com/vpapanik/xenon-2-remake/releases/download/v1.0.7/Xenon2Remake-1.0.7-macos-universal.zip) : unzip, then the first time right-click `Xenon 2 remake.app` and choose Open, as the app is not signed by Apple (or run `xattr -cr "Xenon 2 remake.app"`) |
| Web | [Xenon2Remake-1.0.7-web.zip](https://github.com/vpapanik/xenon-2-remake/releases/download/v1.0.7/Xenon2Remake-1.0.7-web.zip) : unzip and serve the folder with any web server, then open it in the browser |

## The game

The complete game, as it was in 1989:

- all five levels with their mid-level and end-of-level guardians
- the shop with every weapon and upgrade, buying and selling, in the middle and at the end of each level
- pods, power-ups and tokens: speed, power, rate of fire, dives, energy, side shots, the Z bomb, shields, Super Nashwan Power
- dive, protection and bitmap shades
- lives, continues, the high score table, one or two players in turn
- the end of the game and the loop back to the first level.

The behaviour follows the original game to the frame: the same enemy waves, paths, speeds, collisions and timings.

## Amiga or PC

The title menu chooses them, and F2 and F3 switch them at any moment, even in the middle of a level:

- **graphics** (F2): the Amiga version, with its own level backgrounds, title screen and colours, or the PC (VGA) version
- **sound** (F3): the Amiga sound, with the Megablast music and the Amiga sound effects, or the PC speaker.

## ORIGINAL 1989 or ENHANCED 2026

The opening screen offers two editions, and **F1** switches between them at any moment, even in the middle of a level.

| | ORIGINAL 1989 | ENHANCED 2026 |
|---|---|---|
| Picture | original 320 × 200 | every picture drawn sharp at the resolution of your screen |
| Graphics | the original pixels | smooth high resolution graphics |
| Amiga music | the in-game arrangement | the full arrangement of the original release |

The game mechanics of the original Amiga and PC versions of Xenon 2 are identical: the same levels, enemies, weapons and timings. So with Amiga or PC graphics and sound, in either edition, the game plays exactly the same: only the look and the sound change.

![Scenes from the game](images/poster_scenes.png)

ENHANCED also smooths a few small rough edges of the original:

- the Amiga music goes on through a lost life instead of starting again
- the CONTINUE countdown counts real seconds, 10 in all instead of about 4
- the texts of the title screen are centred
- the logo zooms in smoothly on the title screen
- the tails of the level 1 capsules stay on their bodies, instead of floating a frame behind them
- after a weapon is sold in the shop, the side weapons left move next to the ship at once, instead of hanging in the air until the next life or level
- **F4** shows the picture as on a 4:3 PC (VGA) screen of the time, every pixel 20% taller, or with square pixels (the default, close to a PAL Amiga)
- smooth motion: the game still moves everything about 18 times a second, but the picture is drawn at every frame of your screen, with the scroll, the ship, the enemies, the shots and the stars between their last two positions. The game itself plays exactly the same. **F5** turns it off and on.

## Building

Open the folder in **[Godot 4.7.2](https://godotengine.org/download/)** (standard build) and run it, or export it from *Project > Export* for Windows, Linux or the Web. Ready builds are on the [Releases](https://github.com/vpapanik/xenon-2-remake/releases) page.

## Controls

| Key | Action |
|---|---|
| Arrows or keypad | move |
| Space or joystick buttons | fire |
| Enter | dive |
| P | pause |
| Esc | back to the title |
| F1 | ORIGINAL or ENHANCED |
| F2 | Amiga or PC graphics |
| F3 | Amiga or PC sound |
| F4 (ENHANCED) | square pixels or the 4:3 shape of a PC screen of the time |
| F5 (ENHANCED) | smooth motion off or on |
| F10 | quit |
| K (on the title menu) | choose your own keys |

On phones and tablets the browser version shows touch controls, without text. In a level: a joystick at the lower left (or wherever the thumb lands on the left half), the red button fires (hold it for autofire), the green one dives while a dive is left, and the two bars pause. On the menus and in the shop: four arrows and the red button to choose. Turn the phone sideways for a larger picture.

## Credits

- [Xenon 2: Megablast](https://en.wikipedia.org/wiki/Xenon_2:_Megablast) by [The Bitmap Brothers](https://en.wikipedia.org/wiki/The_Bitmap_Brothers), published by [Image Works](https://en.wikipedia.org/wiki/Image_Works) (1989).
- Music: [Bomb the Bass](https://en.wikipedia.org/wiki/Bomb_the_Bass), adapted by [David Whittaker](https://en.wikipedia.org/wiki/David_Whittaker_(video_game_composer)).
- Remake by vpapanik.

## Disclaimer

This is a free, non-commercial fan project, made out of love for the original game. It is not affiliated with, endorsed by or connected in any way to The Bitmap Brothers, Image Works, [Mirrorsoft](https://en.wikipedia.org/wiki/Mirrorsoft), Bomb the Bass, David Whittaker or any current owner of Xenon 2: Megablast. All names, trademarks, graphics, music and other material of the original game belong to their respective owners. Nothing here is for sale.
