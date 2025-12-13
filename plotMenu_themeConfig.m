function [theme, currentFont, themeLight, themeDark, fontUiLight, fontUiDark, fontFigure] = plotMenu_themeConfig()
%plotMenu_themeConfig Define theme and font profiles for plotMenu.
%   Returns the default theme, font selections, and the individual theme
%   structures used throughout the UI. Keeping these definitions in one place
%   simplifies switching defaults or extending themes later.

% Light theme (default MATLAB-like)
themeLight.bgMain        = [0.94 0.94 0.94];
themeLight.bgPanel       = [0.97 0.97 0.97];
themeLight.bgControl     = [1.00 1.00 1.00];
themeLight.bgControlAlt  = [0.93 0.93 0.93];
themeLight.fgText        = [0.00 0.00 0.00];
themeLight.fgMuted       = [0.20 0.20 0.20];
themeLight.accent        = [0.00 0.45 0.74];
themeLight.accentWarning = [0.85 0.33 0.10];

% Dark theme configuration
themeDark.bgMain        = [0.10 0.10 0.12];
themeDark.bgPanel       = [0.14 0.14 0.17];
themeDark.bgControl     = [0.20 0.20 0.20];
themeDark.bgControlAlt  = [0.25 0.25 0.29];
themeDark.fgText        = [0.90 0.90 0.92];
themeDark.fgMuted       = [0.70 0.70 0.75];
themeDark.accent        = [0.30 0.70 1.00];
themeDark.accentWarning = [0.95 0.55 0.35];

% Font profiles
fontUiLight.fontName      = 'Segoe UI';
fontUiLight.fontSizeSmall  = 13;
fontUiLight.fontSizeBase   = 14;
fontUiLight.fontSizeLarge  = 15;

fontUiDark.fontName       = 'Segoe UI';
fontUiDark.fontSizeSmall  = 13;
fontUiDark.fontSizeBase   = 14;
fontUiDark.fontSizeLarge  = 15;

fontFigure.fontName       = 'Segoe UI';
fontFigure.fontSize       = 18;

theme = themeDark;
currentFont = fontUiDark;
end
