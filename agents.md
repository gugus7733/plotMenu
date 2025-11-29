When given a list of points to modify, follow these instructions :
- Adress them point by point like they were several separate requests
- After addressing them, make a final checkup of the code to make sure it is coherent on indentation and statements so it can be run directly.
- Only add new files if absolutely necessary, otherwise keep it all in a single file.

Additional project notes for Codex:
- The main GUI entry point is `plotMenu.m`; keep GUI logic self-contained there.
- Use `plotMenu_validation.m` to seed the base workspace with diverse sample variables and launch the GUI for manual testing.
- Prefer MATLAB scripts over functions for quick validation data so variables land in the base workspace.
- Only use MATLAB functions or properties that existed in or before R2022a; avoid newer functionality.
