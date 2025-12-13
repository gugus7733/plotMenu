function [state, statusTimer, maximizeTimer] = plotMenu_initState()
%plotMenu_initState Construct the initial shared state used by plotMenu.
%   This helper centralizes default values for the application model so they
%   can be referenced consistently across the UI creation and callbacks.

% Shared state across nested callbacks
state          = struct();
statusTimer    = [];
state.subplots = struct('axes',{},'lines',{},'superpose',{},'legendVisible',{},'legendLocation',{}, ...
    'axisEqual',{},'xTickSpacing',{},'yTickSpacing',{},'xScale',{},'yScale',{},'limitListeners',{}, ...
    'titleText',{},'xLabelText',{},'yLabelText',{},'xLim',{},'yLim',{});
state.subplotRows = 1;
state.subplotCols = 1;
state.activeSubplot = 1;
state.workspaceMeta = struct('name',{},'class',{},'size',{},'isSupportedArray',{},'numel',{},'isIntegerScalar',{},'kind',{},'scalarValue',{},'isNumeric',{},'isValidXCandidate',{});
state.customYItems  = struct('label',{},'expression',{},'dimSizes',{});
state.datatipMode   = false;
state.derivedMode   = false;
state.derivedChoices = struct('label',{},'expression',{});
state.originalYBackground = [];
state.hoverButtons = gobjects(0);
state.selectedIndexVars = {};
state.customIndexExpressions = {};
maximizeTimer = [];
end
