# PlotMenu

PlotMenu is a MATLAB GUI that lets you quickly pick variables from the base workspace and visualize them with customizable plotting options. The interface supports selecting X/Y variables, arranging multiple subplots, adjusting line appearance, and exporting figure-generating code.

## Project scope
- Keep the GUI self-contained in `plotMenu.m` for easy maintenance.
- Use the validation script in `plotMenu_validation.m` to populate the workspace with diverse sample data and launch the GUI.
- Manual testing is expected: run the validation script or prepare your own variables in the workspace, then execute `plotMenu`.
