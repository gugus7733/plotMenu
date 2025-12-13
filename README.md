# PlotMenu

PlotMenu is a MATLAB GUI that lets you quickly pick variables from the base workspace and visualize them with customizable plotting options. The interface supports selecting X/Y variables, arranging multiple subplots, adjusting line appearance, and exporting figure-generating code.

## Requirements
- MATLAB R2022a or later
- No additional toolboxes are required.

## How to run
- Typical workflow: prepare your workspace variables and run `plotMenu` from the MATLAB command window.
- For a curated set of sample variables, run `plotMenu_validation.m`. It seeds the workspace with test data and then launches the GUI.
- A lightweight smoke test is available via `plotMenu_smokeTest` to launch and close the UI programmatically.

## Repository layout
- `plotMenu.m` — main GUI entry point that wires together state, theming, and UI construction.
- `plotMenu_initState.m` — helper that builds the default application state struct.
- `plotMenu_themeConfig.m` — helper defining light/dark themes and font profiles.
- `plotMenu_validation.m` — script that prepares diverse sample variables and opens the GUI for manual testing.
- `plotMenu_smokeTest.m` — programmatic smoke test that opens and closes the GUI using the validation data.

## Notes
- The GUI logic remains MATLAB-only for simplicity and quick iteration.
- If you change or extend themes or font settings, update `plotMenu_themeConfig.m` to keep defaults consistent.
- Keep `plotMenu.m` on the MATLAB path (current folder is enough) so helper functions in the same directory are discoverable.

## PlotMenu figure persistence
- Quick Save stores a PlotMenu-native figure specification (`*.plotmenu.mat`) plus a PNG preview in a dedicated folder under `prefdir/plotmenu/figures` (with fallbacks to `userpath` or `tempdir`).
- "Save As..." lets you pick a custom destination for the paired spec + PNG files.
- The Import Figure manager lists saved figures with thumbnails, allows opening them into PlotMenu, and supports deleting entries.
- Autosave runs every 5 minutes by default (configurable in Preferences) and rotates a small set of `autosave_*` entries. Autosave uses the same parametric spec and preview so figures can be reopened even when variables are missing.
