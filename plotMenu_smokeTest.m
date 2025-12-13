function plotMenu_smokeTest()
%plotMenu_smokeTest Launch PlotMenu with validation data and close it.
%   This is a lightweight sanity check that the UI instantiates without
%   throwing errors. It relies on the validation script to prepare sample
%   workspace variables.

evalin('base', 'plotMenu_validation;');
drawnow;
pause(0.5); % allow UI to render
fig = findall(groot, 'Tag', 'PlotMenuMainFigure');
if ~isempty(fig) && all(isvalid(fig))
    delete(fig);
end
end
