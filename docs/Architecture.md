# Architecture overview

## Entry point
- **`plotMenu.m`** remains the main function. It performs one-time window cleanup, initializes state via `plotMenu_initState`, loads theme/font data via `plotMenu_themeConfig`, and then builds the UI and callbacks defined in the file.

## State model
- `plotMenu_initState` creates a struct that holds subplot metadata, workspace metadata, custom Y expressions, and runtime flags (datatip/derived modes, hover buttons, index selections). Timers used for status and maximization are returned alongside the struct so they are created in a single place.
- The shared `state` struct is mutated by nested callbacks inside `plotMenu.m`, keeping UI handles and plot data together.

## Theming
- `plotMenu_themeConfig` centralizes light/dark theme colors and UI/figure font profiles. `plotMenu.m` uses these values when constructing panels, grids, and labels and when toggling between themes.

## Validation and smoke testing
- `plotMenu_validation.m` populates the workspace with a curated set of variables and launches the GUI for manual verification.
- `plotMenu_smokeTest.m` runs the validation script, waits briefly for UI creation, and then closes the PlotMenu figure. Use it as a quick sanity check that the GUI instantiates without errors.

## Extension points
- Add new state defaults in `plotMenu_initState` to keep initialization consistent across callbacks.
- Update theme palettes or fonts in `plotMenu_themeConfig` when introducing new UI styling.
- Keep new UI sections or callbacks co-located in `plotMenu.m` but rely on the centralized state and theme helpers for consistency.
