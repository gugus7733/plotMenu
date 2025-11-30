function plotMenu
% plotMenuPrototype - Interactive plot menu prototype.
%
% Usage:
%   Run in MATLAB (with data already in base workspace):
%       plotMenuPrototype
%
% GUI-only workflow:
%   - Choose X and Y variables from the base workspace.
%   - Plot multiple Y on the same axes.
%   - Change line color (RGB spinners), width, style, and name.
%   - Change title, axis labels, legend presence/location.
%   - Export MATLAB code that reproduces the figure using the variable names.

% Close any other open plotMenu windows to keep a single instance active
existingMenus = findall(0, 'Type', 'figure', '-and', {'Name', 'Plot Menu'});
for k = 1:numel(existingMenus)
    if isvalid(existingMenus(k))
        delete(existingMenus(k));
    end
end

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

%% Create main UI
fig = uifigure( ...
    'Name',     'Plot Menu', ...
    'Position', [100 100 1400 800], ...
    'Color',    [1 1 1]);
fig.WindowKeyPressFcn = @onWindowKeyPressed;

mainLayout = uigridlayout(fig, [1 3]);
mainLayout.ColumnWidth = {'1x', '2x', '1x'};

%% Left panel: data selection
leftPanel  = uipanel(mainLayout, 'Title', 'Data selection', 'BackgroundColor', [1 1 1], ...
    'Scrollable', 'on');
leftPanel.Layout.Row    = 1;
leftPanel.Layout.Column = 1;

leftLayout = uigridlayout(leftPanel, [12 1]);
leftLayout.RowHeight = {'fit', 'fit', 'fit', 'fit', 'fit', '1x', 'fit', 'fit', 'fit', 'fit', 'fit', 'fit'};

subplotPanel = uipanel(leftLayout, 'Title', 'Subplots', 'BackgroundColor', [1 1 1]);
subplotPanel.Layout.Row    = 1;
subplotPanel.Layout.Column = 1;

subplotLayout = uigridlayout(subplotPanel, [2 1]);
subplotLayout.RowHeight   = {'fit', 'fit'};
subplotLayout.BackgroundColor = [1 1 1];

layoutOptions = [1 1; 1 2; 2 1; 2 2; 2 3; 3 2; 3 3; 4 4];
layoutItems   = arrayfun(@(idx) sprintf('%d x %d', layoutOptions(idx, 1), layoutOptions(idx, 2)), ...
    1:size(layoutOptions, 1), 'UniformOutput', false);
layoutItemsData = num2cell(layoutOptions, 2);

ddLayoutMenu = uidropdown(subplotLayout, ...
    'Items', layoutItems, ...
    'ItemsData', layoutItemsData, ...
    'Value', layoutItemsData{1}, ...
    'ValueChangedFcn', @onLayoutSelectionChanged);
ddLayoutMenu.Layout.Row    = 1;
ddLayoutMenu.Layout.Column = 1;
lblLayoutSummary = uilabel(subplotLayout, ...
    'Text', 'Layout: 1 x 1', ...
    'HorizontalAlignment', 'center');
lblLayoutSummary.Layout.Row    = 2;
lblLayoutSummary.Layout.Column = 1;

btnRefresh = uibutton(leftLayout, ...
    'Text',          'Refresh workspace variables', ...
    'ButtonPushedFcn', @onRefreshWorkspace);
btnRefresh.Layout.Row    = 2;
btnRefresh.Layout.Column = 1;

lblXVar = uilabel(leftLayout, 'Text', 'X variable:');
lblXVar.Layout.Row    = 3;
lblXVar.Layout.Column = 1;

ddXVar = uidropdown(leftLayout, ...
    'Items', {''}, ...
    'Value', '', ...
    'ValueChangedFcn', @onXSelectionChanged);
ddXVar.Layout.Row    = 4;
ddXVar.Layout.Column = 1;

lblYVar = uilabel(leftLayout, 'Text', 'Y variable(s):');
lblYVar.Layout.Row    = 5;
lblYVar.Layout.Column = 1;

lbYVar = uilistbox(leftLayout, ...
    'Items',      {}, ...
    'Multiselect','on', ...
    'ValueChangedFcn', @onYSelectionChanged);
lbYVar.Layout.Row    = 6;
lbYVar.Layout.Column = 1;

btnOtherData = uibutton(leftLayout, ...
    'Text', 'Other data types', ...
    'ButtonPushedFcn', @onOpenOtherData);
btnOtherData.Layout.Row    = 7;
btnOtherData.Layout.Column = 1;

derivedRow = uigridlayout(leftLayout, [1 3]);
derivedRow.ColumnWidth = {45, 110, '1x'};
derivedRow.RowHeight   = {'fit'};
derivedRow.Layout.Row    = 8;
derivedRow.Layout.Column = 1;

btnDerivedNew = uibutton(derivedRow, ...
    'Text', 'New', ...
    'ButtonPushedFcn', @onDerivedNew);
btnDerivedNew.Layout.Row    = 1;
btnDerivedNew.Layout.Column = 1;

edtDerivedName = uieditfield(derivedRow, 'text', ...
    'Placeholder', 'name', ...
    'ValueChangedFcn', @onDerivedFieldEdited);
edtDerivedName.Layout.Row    = 1;
edtDerivedName.Layout.Column = 2;

edtDerivedExpr = uieditfield(derivedRow, 'text', ...
    'Placeholder', 'expression', ...
    'ValueChangedFcn', @onDerivedFieldEdited);
edtDerivedExpr.Layout.Row    = 1;
edtDerivedExpr.Layout.Column = 3;

btnPlot = uibutton(leftLayout, ...
    'Text',          'Plot selected', ...
    'ButtonPushedFcn', @onPlot);
btnPlot.Layout.Row    = 12;
btnPlot.Layout.Column = 1;

%% Center panel: axes
centerPanel  = uipanel(mainLayout, 'Title', 'Plot', 'BackgroundColor', [1 1 1]);
centerPanel.Layout.Row    = 1;
centerPanel.Layout.Column = 2;

centerLayout = uigridlayout(centerPanel, [1 1]);
centerLayout.RowHeight   = {'1x'};
centerLayout.ColumnWidth = {'1x'};

%% Right panel: line style, axes properties, export
rightPanel  = uipanel(mainLayout, 'Title', 'Style / Export', 'BackgroundColor', [1 1 1], ...
    'Scrollable', 'on');
rightPanel.Layout.Row    = 1;
rightPanel.Layout.Column = 3;

rightLayout = uigridlayout(rightPanel, [3 1]);
rightLayout.RowHeight = {'fit', 'fit', 'fit'};

% Bottom panel: export button + status label
bottomPanel = uipanel(rightLayout, 'BorderType', 'none');
bottomPanel.Layout.Row    = 3;
bottomPanel.Layout.Column = 1;

bottomLayout = uigridlayout(bottomPanel, [1 1]);
bottomLayout.ColumnWidth = {'1x'};

% --- Line style panel ---
linePanel = uipanel(rightLayout, 'Title', 'Line properties', 'BackgroundColor', [1 1 1], ...
    'Scrollable', 'on');
linePanel.Layout.Row    = 1;
linePanel.Layout.Column = 1;

lineLayout = uigridlayout(linePanel, [14 3]);
lineLayout.RowHeight   = {20, 40, 20, 24, 30, 30, 30, 30, 24, 30, 30, 30, 30, '1x'};
lineLayout.ColumnWidth = {80, '1x', '1x'};

lblLines = uilabel(lineLayout, 'Text', 'Lines:');
lblLines.Layout.Row    = 1;
lblLines.Layout.Column = [1 2];

lbLines = uidropdown(lineLayout, ...
    'Items',          {}, ...
    'ValueChangedFcn', @onLineSelectionChanged);
lbLines.Layout.Row    = 2;
lbLines.Layout.Column = [1 2];

lblLineName = uilabel(lineLayout, 'Text', 'Line name:');
lblLineName.Layout.Row    = 3;
lblLineName.Layout.Column = 1;

edtLineName = uieditfield(lineLayout, 'text', ...
    'ValueChangedFcn', @onLineNameChanged);
edtLineName.Layout.Row    = 3;
edtLineName.Layout.Column = 2;

lblLineOrder = uilabel(lineLayout, 'Text', 'Plot order:');
lblLineOrder.Layout.Row    = 4;
lblLineOrder.Layout.Column = 1;

btnLineOrderDown = uibutton(lineLayout, ...
    'Text', '-', ...
    'ButtonPushedFcn', @onMoveLineBackward);
btnLineOrderDown.Layout.Row    = 4;
btnLineOrderDown.Layout.Column = 2;

btnLineOrderUp = uibutton(lineLayout, ...
    'Text', '+', ...
    'ButtonPushedFcn', @onMoveLineForward);
btnLineOrderUp.Layout.Row    = 4;
btnLineOrderUp.Layout.Column = 3;

% Color controls: single clickable color bar
lblColor = uilabel(lineLayout, 'Text', 'Color:');
lblColor.Layout.Row    = 5;
lblColor.Layout.Column = 1;

btnColor = uibutton(lineLayout, ...
    'Text', '', ...
    'BackgroundColor', [0 0.4470 0.7410], ...
    'ButtonPushedFcn', @onPickColor);
btnColor.Layout.Row    = 5;
btnColor.Layout.Column = 2;

lblWidth = uilabel(lineLayout, 'Text', 'Line width:');
lblWidth.Layout.Row    = 6;
lblWidth.Layout.Column = 1;

sldLineWidth = uislider(lineLayout, ...
    'Limits', [0.1 10], ...
    'MajorTicks', [], ...
    'MinorTicks', [], ...
    'Value', 1.5, ...
    'ValueChangedFcn', @onWidthSliderChanged, ...
    'ValueChangingFcn', @(~, evt) applyLineWidth(evt.Value));
sldLineWidth.Layout.Row    = 6;
sldLineWidth.Layout.Column = 2;

edtLineWidth = uieditfield(lineLayout, 'numeric', ...
    'Limits', [0.1 10], ...
    'Value', 1.5, ...
    'ValueChangedFcn', @onWidthEditChanged);
edtLineWidth.Layout.Row    = 6;
edtLineWidth.Layout.Column = 3;

lblStyle = uilabel(lineLayout, 'Text', 'Line style:');
lblStyle.Layout.Row    = 7;
lblStyle.Layout.Column = 1;

ddLineStyle = uidropdown(lineLayout, ...
    'Items', {'-', '--', ':', '-.'}, ...
    'Value', '-', ...
    'ValueChangedFcn', @onStyleChanged);
ddLineStyle.Layout.Row    = 7;
ddLineStyle.Layout.Column = 2;

chkLineLegend = uicheckbox(lineLayout, ...
    'Text', 'Show in legend', ...
    'Value', true, ...
    'ValueChangedFcn', @onLineLegendToggled);
chkLineLegend.Layout.Row    = 8;
chkLineLegend.Layout.Column = [1 3];

lblTransform = uilabel(lineLayout, ...
    'Text', 'Curve transform (active line)');
lblTransform.Layout.Row    = 9;
lblTransform.Layout.Column = [1 3];

lblGain = uilabel(lineLayout, 'Text', 'Gain:');
lblGain.Layout.Row    = 10;
lblGain.Layout.Column = 1;

edtLineGain = uieditfield(lineLayout, 'numeric', ...
    'Value', 1, ...
    'Limits', [-Inf Inf], ...
    'ValueChangedFcn', @onLineTransformChanged);
edtLineGain.Layout.Row    = 10;
edtLineGain.Layout.Column = 2;

btnPresetDeg2Rad = uibutton(lineLayout, ...
    'Text', 'deg → rad', ...
    'ButtonPushedFcn', @(~, ~) applyTransformPreset('deg2rad'));
btnPresetDeg2Rad.Layout.Row    = 10;
btnPresetDeg2Rad.Layout.Column = 3;

lblOffset = uilabel(lineLayout, 'Text', 'Offset:');
lblOffset.Layout.Row    = 11;
lblOffset.Layout.Column = 1;

edtLineOffset = uieditfield(lineLayout, 'numeric', ...
    'Value', 0, ...
    'Limits', [-Inf Inf], ...
    'ValueChangedFcn', @onLineTransformChanged);
edtLineOffset.Layout.Row    = 11;
edtLineOffset.Layout.Column = 2;

btnPresetRad2Deg = uibutton(lineLayout, ...
    'Text', 'rad → deg', ...
    'ButtonPushedFcn', @(~, ~) applyTransformPreset('rad2deg'));
btnPresetRad2Deg.Layout.Row    = 11;
btnPresetRad2Deg.Layout.Column = 3;

tbtnDatatipMode = uibutton(lineLayout, 'state', ...
    'Text', 'Datatip mode (off)', ...
    'ValueChangedFcn', @onDatatipModeToggled);
tbtnDatatipMode.Layout.Row    = 12;
tbtnDatatipMode.Layout.Column = [1 3];

btnRemoveLine = uibutton(lineLayout, ...
    'Text', 'Remove selected line', ...
    'ButtonPushedFcn', @onRemoveLine);
btnRemoveLine.Layout.Row    = 13;
btnRemoveLine.Layout.Column = [1 3];

% --- Axes properties panel ---
axesPanel = uipanel(rightLayout, 'Title', 'Axes properties', 'BackgroundColor', [1 1 1], ...
    'Scrollable', 'on');
axesPanel.Layout.Row    = 2;
axesPanel.Layout.Column = 1;

axesLayout = uigridlayout(axesPanel, [15 2]);
axesLayout.RowHeight   = {20, 30, 20, 30, 20, 30, 30, 20, 30, 20, 110, 20, 30, 30, '1x'};
axesLayout.ColumnWidth = {100, '1x'};

lblTitle = uilabel(axesLayout, 'Text', 'Title:');
lblTitle.Layout.Row    = 1;
lblTitle.Layout.Column = 1;

edtTitle = uieditfield(axesLayout, 'text', ...
    'ValueChangedFcn', @onAxesTextChanged);
edtTitle.Layout.Row    = 1;
edtTitle.Layout.Column = 2;

lblXLabel = uilabel(axesLayout, 'Text', 'X label:');
lblXLabel.Layout.Row    = 2;
lblXLabel.Layout.Column = 1;

edtXLabel = uieditfield(axesLayout, 'text', ...
    'ValueChangedFcn', @onAxesTextChanged);
edtXLabel.Layout.Row    = 2;
edtXLabel.Layout.Column = 2;

lblYLabel = uilabel(axesLayout, 'Text', 'Y label:');
lblYLabel.Layout.Row    = 3;
lblYLabel.Layout.Column = 1;

edtYLabel = uieditfield(axesLayout, 'text', ...
    'ValueChangedFcn', @onAxesTextChanged);
edtYLabel.Layout.Row    = 3;
edtYLabel.Layout.Column = 2;

chkLegend = uicheckbox(axesLayout, ...
    'Text',          'Show legend', ...
    'Value',         true, ...
    'ValueChangedFcn', @onLegendChanged);
chkLegend.Layout.Row    = 4;
chkLegend.Layout.Column = [1 2];

lblLegendLoc = uilabel(axesLayout, 'Text', 'Legend loc.:');
lblLegendLoc.Layout.Row    = 5;
lblLegendLoc.Layout.Column = 1;

ddLegendLocation = uidropdown(axesLayout, ...
    'Items', {'best', 'northwest', 'northeast', ...
    'southwest', 'southeast', ...
    'northoutside', 'southoutside'}, ...
    'Value', 'best', ...
    'ValueChangedFcn', @onLegendChanged);
ddLegendLocation.Layout.Row    = 5;
ddLegendLocation.Layout.Column = 2;

lblAxesScaleHeader = uilabel(axesLayout, ...
    'Text', 'Axes & scale (active subplot)', ...
    'FontWeight', 'bold');
lblAxesScaleHeader.Layout.Row    = 10;
lblAxesScaleHeader.Layout.Column = [1 2];

axesScalePanel = uipanel(axesLayout, 'BackgroundColor', [1 1 1]);
axesScalePanel.Layout.Row    = 11;
axesScalePanel.Layout.Column = [1 2];

axesScaleLayout = uigridlayout(axesScalePanel, [4 4]);
axesScaleLayout.RowHeight   = {24, 24, 24, 24};
axesScaleLayout.ColumnWidth = {70, '1x', 70, '1x'};

chkAxisEqual = uicheckbox(axesScaleLayout, ...
    'Text', 'Axis equal (selected subplot)', ...
    'Value', false, ...
    'ValueChangedFcn', @onAxisEqualToggled);
chkAxisEqual.Layout.Row    = 1;
chkAxisEqual.Layout.Column = [1 4];

lblXTickSpacing = uilabel(axesScaleLayout, 'Text', 'Xtick');
lblXTickSpacing.Layout.Row    = 2;
lblXTickSpacing.Layout.Column = 1;

edtXTickSpacing = uieditfield(axesScaleLayout, 'text', ...
    'Value', '', ...
    'ValueChangedFcn', @(src, ~) onTickSpacingChanged(src, 'x'));
edtXTickSpacing.Layout.Row    = 2;
edtXTickSpacing.Layout.Column = 2;

btnAutoXTicks = uibutton(axesScaleLayout, ...
    'Text', 'Auto', ...
    'ButtonPushedFcn', @(~, ~) onResetTickSpacing('x'));
btnAutoXTicks.Layout.Row    = 2;
btnAutoXTicks.Layout.Column = 4;

lblYTickSpacing = uilabel(axesScaleLayout, 'Text', 'Ytick');
lblYTickSpacing.Layout.Row    = 3;
lblYTickSpacing.Layout.Column = 1;

edtYTickSpacing = uieditfield(axesScaleLayout, 'text', ...
    'Value', '', ...
    'ValueChangedFcn', @(src, ~) onTickSpacingChanged(src, 'y'));
edtYTickSpacing.Layout.Row    = 3;
edtYTickSpacing.Layout.Column = 2;

btnAutoYTicks = uibutton(axesScaleLayout, ...
    'Text', 'Auto', ...
    'ButtonPushedFcn', @(~, ~) onResetTickSpacing('y'));
btnAutoYTicks.Layout.Row    = 3;
btnAutoYTicks.Layout.Column = 4;

lblXScale = uilabel(axesScaleLayout, 'Text', 'X scale:');
lblXScale.Layout.Row    = 4;
lblXScale.Layout.Column = 1;

ddXScale = uidropdown(axesScaleLayout, ...
    'Items', {'linear', 'log'}, ...
    'Value', 'linear', ...
    'ValueChangedFcn', @(src, ~) onAxisScaleChanged(src, 'x'));
ddXScale.Layout.Row    = 4;
ddXScale.Layout.Column = 2;

lblYScale = uilabel(axesScaleLayout, 'Text', 'Y scale:');
lblYScale.Layout.Row    = 4;
lblYScale.Layout.Column = 3;

ddYScale = uidropdown(axesScaleLayout, ...
    'Items', {'linear', 'log'}, ...
    'Value', 'linear', ...
    'ValueChangedFcn', @(src, ~) onAxisScaleChanged(src, 'y'));
ddYScale.Layout.Row    = 4;
ddYScale.Layout.Column = 4;

lblActiveSubplot = uilabel(axesLayout, ...
    'Text', 'Active subplot: (1,1)');
lblActiveSubplot.Layout.Row    = 12;
lblActiveSubplot.Layout.Column = [1 2];

chkSubplotSuperpose = uicheckbox(axesLayout, ...
    'Text',  'Superpose in subplot', ...
    'Value', false, ...
    'ValueChangedFcn', @onSubplotSuperposeChanged);
chkSubplotSuperpose.Layout.Row    = 13;
chkSubplotSuperpose.Layout.Column = [1 2];

btnClear = uibutton(axesLayout, ...
    'Text',          'Clear selected subplot', ...
    'ButtonPushedFcn', @onClearPlot);
btnClear.Layout.Row    = 14;
btnClear.Layout.Column = [1 2];

% --- Export button ---
btnExport = uibutton(bottomLayout, ...
    'Text',          'Export to MATLAB code', ...
    'ButtonPushedFcn', @onExport);
btnExport.Layout.Row    = 1;
btnExport.Layout.Column = 1;

% Status "toast" label (center bottom of the figure)
lblStatus = uilabel(fig, ...
    'Text', '', ...
    'HorizontalAlignment', 'center', ...
    'BackgroundColor', [0 0 0], ...
    'FontColor', [1 1 1], ...
    'Visible', 'off');

%% Initialize workspace variables in dropdowns/listbox and create default subplot
applySubplotGrid(1, 1);
setActiveSubplot(1);
refreshWorkspaceControls();

%% --- Nested helper and callback functions ---

    function setStatus(msg, isError)
        if nargin < 2
            isError = false;
        end

        lblStatus.Text    = msg;
        lblStatus.Visible = 'on';
        if isError
            lblStatus.BackgroundColor = [0.8 0 0];
            lblStatus.FontColor = [1 1 1];
        else
            lblStatus.BackgroundColor = [0 0 0];
            lblStatus.FontColor = [1 1 1];
        end

        figPos      = fig.Position;
        toastWidth  = min(360, figPos(3) - 20);
        toastWidth  = max(toastWidth, 200);
        toastHeight = 24;
        lblStatus.Position = [ (figPos(3) - toastWidth) / 2, 10, toastWidth, toastHeight ];

        if ~isempty(statusTimer) && isvalid(statusTimer)
            stop(statusTimer);
            delete(statusTimer);
        end

        statusTimer = timer( ...
            'StartDelay',    3, ...
            'ExecutionMode', 'singleShot', ...
            'TimerFcn',      @(~, ~) set(lblStatus, 'Visible', 'off'));
        start(statusTimer);
    end

    function applySubplotGrid(rows, cols)
        % Create or resize the subplot grid based on a table-like selection
        rows = max(1, rows);
        cols = max(1, cols);

        centerLayout.RowHeight   = repmat({'1x'}, 1, rows);
        centerLayout.ColumnWidth = repmat({'1x'}, 1, cols);

        oldSubplots = state.subplots;
        newCount    = rows * cols;

        defaultSubplot = struct( ...
            'axes',           [], ...
            'lines',          struct('handle',{},'xName',{},'yName',{},'legend',{},'datatips',{},'xData',{},'yData',{},'gain',{},'offset',{},'color',{},'lineStyle',{},'lineWidth',{},'displayName',{}), ...
            'superpose',      false, ...
            'legendVisible',  true, ...
            'legendLocation', 'best', ...
            'axisEqual',      false, ...
            'xTickSpacing',   [], ...
            'yTickSpacing',   [], ...
            'xScale',         'linear', ...
            'yScale',         'linear', ...
            'limitListeners', event.listener.empty, ...
            'titleText',      '', ...
            'xLabelText',     '', ...
            'yLabelText',     '', ...
            'xLim',           [], ...
            'yLim',           []);

        targetLength = max(newCount, numel(oldSubplots));
        if isempty(oldSubplots)
            oldSubplots = repmat(defaultSubplot, 1, targetLength);
        elseif numel(oldSubplots) < targetLength
            oldSubplots(end+1:targetLength) = repmat(defaultSubplot, 1, targetLength - numel(oldSubplots));
        end

        for idx = 1:numel(oldSubplots)
            state.subplots(idx) = ensureSubplotStruct(oldSubplots(idx));
            captureSubplotState(idx);
        end

        for idx = 1:targetLength
            subplotInfo = ensureSubplotStruct(state.subplots(idx));
            rIdx = ceil(idx / cols);
            cIdx = mod(idx-1, cols) + 1;

            if idx <= newCount
                if ~isValidAxesHandle(subplotInfo.axes)
                    axLocal = uiaxes(centerLayout);
                    axLocal.Layout.Row    = rIdx;
                    axLocal.Layout.Column = cIdx;
                    grid(axLocal, 'on');
                    title(axLocal, subplotInfo.titleText);
                    xlabel(axLocal, subplotInfo.xLabelText);
                    ylabel(axLocal, subplotInfo.yLabelText);
                    axLocal.Color = [1 1 1];
                    subplotInfo.axes = axLocal;
                    redrawSubplotContent(idx, subplotInfo);
                else
                    subplotInfo.axes.Layout.Row    = rIdx;
                    subplotInfo.axes.Layout.Column = cIdx;
                    subplotInfo.axes.Visible       = 'on';
                end

                wireAxesInteractivity(subplotInfo.axes);
                ensureLineInteractivity(subplotInfo.lines);
                attachLimitListeners(subplotInfo.axes, idx);
                applyAxesConfig(idx);
                applyAxesTextFromState(idx);
                restoreLineDatatips(idx);
            else
                subplotInfo = captureSubplotState(idx);
                if isfield(subplotInfo, 'axes') && isValidAxesHandle(subplotInfo.axes)
                    delete(subplotInfo.axes);
                end
                if isfield(subplotInfo, 'limitListeners') && ~isempty(subplotInfo.limitListeners)
                    try
                        delete(subplotInfo.limitListeners(isvalid(subplotInfo.limitListeners)));
                    catch
                    end
                end
                subplotInfo.axes = [];
                subplotInfo.limitListeners = event.listener.empty;
            end

            state.subplots(idx) = subplotInfo;
        end

        state.subplotRows   = rows;
        state.subplotCols   = cols;
        state.activeSubplot = min(state.activeSubplot, newCount);
        syncLayoutDropdown(rows, cols);
        lblLayoutSummary.Text = sprintf('Layout: %d x %d', rows, cols);

        setActiveSubplot(state.activeSubplot);
    end

    function tf = isValidAxesHandle(ax)
        tf = ~isempty(ax) && isgraphics(ax) && isvalid(ax);
    end

    function syncLayoutDropdown(rows, cols)
        if isempty(ddLayoutMenu) || ~isvalid(ddLayoutMenu)
            return;
        end

        match = find(layoutOptions(:, 1) == rows & layoutOptions(:, 2) == cols, 1);
        if isempty(match) || match > numel(layoutItemsData)
            return;
        end

        desired = layoutItemsData{match};
        if ~isequal(ddLayoutMenu.Value, desired)
            ddLayoutMenu.Value = desired;
        end
    end

    function subplotInfo = captureSubplotState(idx)
        subplotInfo = ensureSubplotStruct(state.subplots(idx));
        axLocal = subplotInfo.axes;
        if isValidAxesHandle(axLocal)
            subplotInfo.titleText  = axLocal.Title.String;
            subplotInfo.xLabelText = axLocal.XLabel.String;
            subplotInfo.yLabelText = axLocal.YLabel.String;
            subplotInfo.xLim       = axLocal.XLim;
            subplotInfo.yLim       = axLocal.YLim;
            syncDatatipsFromAxes(idx);
            subplotInfo = ensureSubplotStruct(state.subplots(idx));
        end

        subplotInfo.lines = captureLineState(subplotInfo.lines);
        state.subplots(idx) = subplotInfo;
    end

    function lines = captureLineState(lines)
        if isempty(lines)
            lines = ensureLineDefaults(lines);
            return;
        end
        for ln = 1:numel(lines)
            if isfield(lines(ln), 'handle') && isvalid(lines(ln).handle)
                lines(ln).color       = safeGetLineColor(lines(ln).handle);
                lines(ln).lineStyle   = safeGetLineStyle(lines(ln).handle);
                lines(ln).lineWidth   = safeGetLineWidth(lines(ln).handle);
                lines(ln).displayName = safeGetDisplayName(lines(ln).handle, lines(ln).yName);
                legendInfo = lines(ln).handle.Annotation.LegendInformation;
                lines(ln).legend = strcmp(legendInfo.IconDisplayStyle, 'on');
                lines(ln).xData  = safeGetLineData(lines(ln).handle, 'XData');
                lines(ln).yData  = safeGetLineData(lines(ln).handle, 'YData');
            end
            lines(ln).datatips = ensureLineDefaults(lines(ln)).datatips;
        end
    end

    function redrawSubplotContent(idx, subplotInfo)
        if nargin < 2
            subplotInfo = ensureSubplotStruct(state.subplots(idx));
        end
        axLocal = subplotInfo.axes;
        if ~isValidAxesHandle(axLocal)
            return;
        end

        cla(axLocal);
        hold(axLocal, 'on');
        for ln = 1:numel(subplotInfo.lines)
            lnInfo = ensureLineDefaults(subplotInfo.lines(ln));
            if isempty(lnInfo.xData) || isempty(lnInfo.yData)
                continue;
            end

            hLine = plot(axLocal, lnInfo.xData, lnInfo.yData, ...
                'LineWidth', lnInfo.lineWidth, ...
                'LineStyle', lnInfo.lineStyle, ...
                'Color',     lnInfo.color, ...
                'DisplayName', lnInfo.displayName);
            subplotInfo.lines(ln).handle = hLine;
            wireLineInteractivity(hLine);

            try
                set(hLine.Annotation.LegendInformation, 'IconDisplayStyle', ternary(lnInfo.legend, 'on', 'off'));
            catch
            end
        end
        hold(axLocal, 'off');

        state.subplots(idx) = subplotInfo;
        applyLineTransformsForSubplot(idx);
        applyAxesTextFromState(idx);
        applyAxesConfig(idx);
        updateLegend(axLocal);
    end

    function applyAxesTextFromState(idx)
        if idx < 1 || idx > numel(state.subplots)
            return;
        end
        subplotInfo = ensureSubplotStruct(state.subplots(idx));
        axLocal = subplotInfo.axes;
        if ~isValidAxesHandle(axLocal)
            return;
        end

        title(axLocal, subplotInfo.titleText);
        xlabel(axLocal, subplotInfo.xLabelText);
        ylabel(axLocal, subplotInfo.yLabelText);

        if ~isempty(subplotInfo.xLim)
            try
                axLocal.XLim = subplotInfo.xLim;
            catch
            end
        end
        if ~isempty(subplotInfo.yLim)
            try
                axLocal.YLim = subplotInfo.yLim;
            catch
            end
        end
    end

    function restoreLineDatatips(idx)
        if idx < 1 || idx > numel(state.subplots)
            return;
        end
        subplotInfo = ensureSubplotStruct(state.subplots(idx));
        axLocal = subplotInfo.axes;
        if ~isValidAxesHandle(axLocal)
            return;
        end

        try
            delete(findDatatipObjects(axLocal));
        catch
        end

        for ln = 1:numel(subplotInfo.lines)
            lnInfo = ensureLineDefaults(subplotInfo.lines(ln));
            if isempty(lnInfo.datatips)
                continue;
            end
            hLine = lnInfo.handle;
            if isempty(hLine) || ~isvalid(hLine)
                continue;
            end
            for tipIdx = 1:numel(lnInfo.datatips)
                dt = lnInfo.datatips(tipIdx);
                if isempty(dt.dataIndex) || ~isfinite(dt.dataIndex)
                    continue;
                end
                try
                    dtHandle = datatip(hLine, 'DataIndex', round(dt.dataIndex));
                    if isfield(dt, 'orientation') && ~isempty(dt.orientation) && isvalid(dtHandle) && isprop(dtHandle, 'Orientation')
                        dtHandle.Orientation = dt.orientation;
                    end
                catch
                end
            end
        end
    end

    function setActiveSubplot(idx)
        if idx < 1 || idx > numel(state.subplots)
            return;
        end

        state.activeSubplot = idx;
        state.subplots(idx) = ensureSubplotStruct(state.subplots(idx));
        ax = state.subplots(idx).axes;

        if isValidAxesHandle(ax)
            wireAxesInteractivity(ax);
            ensureLineInteractivity(state.subplots(idx).lines);
            applyLineTransformsForSubplot(idx);
            applyAxesConfig(idx);
        end

        rowIdx = ceil(idx / state.subplotCols);
        colIdx = mod(idx-1, state.subplotCols) + 1;
        lblActiveSubplot.Text = sprintf('Active subplot: (%d,%d)', rowIdx, colIdx);

        chkSubplotSuperpose.Value = state.subplots(idx).superpose;

        syncLegendControlsFromSubplot(idx);
        refreshLineListFromSubplot();
        syncAxesControlsFromSubplot();

        % Sync axes text fields with the selected subplot
        if isValidAxesHandle(ax)
            edtTitle.Value  = ax.Title.String;
            edtXLabel.Value = ax.XLabel.String;
            edtYLabel.Value = ax.YLabel.String;
        else
            edtTitle.Value  = state.subplots(idx).titleText;
            edtXLabel.Value = state.subplots(idx).xLabelText;
            edtYLabel.Value = state.subplots(idx).yLabelText;
        end
    end

    function lines = getCurrentLines()
        if isempty(state.subplots)
            lines = struct('handle',{},'xName',{},'yName',{},'legend',{},'datatips',{},'xData',{},'yData',{},'gain',{},'offset',{},'color',{},'lineStyle',{},'lineWidth',{},'displayName',{});
            return;
        end
        state.subplots(state.activeSubplot) = ensureSubplotStruct(state.subplots(state.activeSubplot));
        lines = ensureLineDefaults(state.subplots(state.activeSubplot).lines);
    end

    function setCurrentLines(lines)
        state.subplots(state.activeSubplot).lines = ensureLineDefaults(lines);
    end

    function refreshLineListFromSubplot(selectedHandle)
        if nargin < 1
            selectedHandle = [];
        end

        lines = getCurrentLines();
        items = {};
        data  = {};
        for k = 1:numel(lines)
            if isvalid(lines(k).handle)
                items{end+1} = lines(k).handle.DisplayName; %#ok<AGROW>
                data{end+1}  = lines(k).handle; %#ok<AGROW>
            end
        end

        previousValue = lbLines.Value;
        lbLines.Items     = items;
        lbLines.ItemsData = data;

        if ~isempty(items)
            if ~isempty(selectedHandle) && any(cellfun(@(h) isequal(h, selectedHandle), data))
                lbLines.Value = selectedHandle;
            elseif ~isempty(previousValue) && any(cellfun(@(h) isequal(h, previousValue), data))
                lbLines.Value = previousValue;
            else
                lbLines.Value = data{1};
            end
        else
            lbLines.Value = {};
        end

        syncStyleWithSelectedLine();
    end

    function onLayoutSelectionChanged(src, ~)
        if isempty(src.Value)
            return;
        end

        selection = src.Value;
        if numel(selection) < 2
            return;
        end

        rows = selection(1);
        cols = selection(2);

        if rows == state.subplotRows && cols == state.subplotCols
            return;
        end

        applySubplotGrid(rows, cols);
    end

    function onSubplotSuperposeChanged(~, ~)
        state.subplots(state.activeSubplot).superpose = chkSubplotSuperpose.Value;
    end

    function clearSubplot(idx)
        if idx < 1 || idx > numel(state.subplots)
            return;
        end

        subplotInfo = state.subplots(idx);
        if isfield(subplotInfo, 'axes') && isValidAxesHandle(subplotInfo.axes)
            cla(subplotInfo.axes);
            title(subplotInfo.axes, '');
            xlabel(subplotInfo.axes, '');
            ylabel(subplotInfo.axes, '');
        end

        subplotInfo.lines = struct('handle',{},'xName',{},'yName',{},'legend',{},'datatips',{}, ...
            'xData',{},'yData',{},'gain',{},'offset',{},'color',{},'lineStyle',{},'lineWidth',{},'displayName',{});
        subplotInfo.titleText  = '';
        subplotInfo.xLabelText = '';
        subplotInfo.yLabelText = '';
        subplotInfo.xLim       = [];
        subplotInfo.yLim       = [];
        state.subplots(idx) = subplotInfo;

        if idx == state.activeSubplot
            lbLines.Items = {};
            lbLines.Value = {};
            lbLines.ItemsData = {};
            syncStyleWithSelectedLine();
            updateLegend(subplotInfo.axes);
        end
    end

    function onRefreshWorkspace(~, ~)
        refreshWorkspaceControls();
    end

    function onDerivedNew(~, ~)
        if state.derivedMode
            exitDerivedMode(true);
            return;
        end

        refreshDerivedChoices();
        enterDerivedMode();
    end

    function onDerivedFieldEdited(~, ~)
        if ~state.derivedMode
            return;
        end

        newName = strtrim(edtDerivedName.Value);
        expr    = strtrim(edtDerivedExpr.Value);

        % Only attempt creation once both fields are filled; ValueChanged only
        % fires after the user confirms or leaves the field, so we avoid
        % evaluating partial input while typing.
        if isempty(newName) || isempty(expr)
            return;
        end

        tryCreateDerivedVariable(false);
    end

    function onWindowKeyPressed(~, evt)
        if ~state.derivedMode || isempty(evt) || ~isfield(evt, 'Key')
            return;
        end

        switch evt.Key
            case {'escape'}
                exitDerivedMode(true);
            case {'return', 'enter'}
                tryCreateDerivedVariable(true);
        end
    end

    function onYSelectionChanged(src, evt)
        if state.derivedMode
            insertDerivedExpression(extractDerivedExpression(src, evt));
            lbYVar.Value = {};
        end
    end

    function insertDerivedExpression(expr)
        if isempty(expr)
            return;
        end
        refreshDerivedChoices();
        existing = strtrim(edtDerivedExpr.Value);
        if isempty(existing)
            edtDerivedExpr.Value = expr;
        else
            edtDerivedExpr.Value = sprintf('%s %s', existing, expr);
        end
    end

    function expr = extractDerivedExpression(src, evt)
        expr = '';
        selection = [];
        if nargin >= 2 && ~isempty(evt) && isfield(evt, 'Value')
            selection = evt.Value;
        elseif nargin >= 1 && ~isempty(src)
            selection = src.Value;
        end

        if iscell(selection) && ~isempty(selection)
            selection = selection{end};
        end

        if isstruct(selection) && isfield(selection, 'expression')
            expr = selection.expression;
        elseif isstring(selection) || ischar(selection)
            expr = char(selection);
        end
    end

    function refreshDerivedChoices()
        [labels, expressions] = getDerivedVariableChoices();
        state.derivedChoices = repmat(struct('label', '', 'expression', ''), 1, numel(labels));
        for idx = 1:numel(labels)
            state.derivedChoices(idx) = struct('label', labels{idx}, 'expression', expressions{idx});
        end
    end

    function enterDerivedMode()
        state.derivedMode = true;
        if isempty(state.originalYBackground)
            state.originalYBackground = lbYVar.BackgroundColor;
        end
        lbYVar.BackgroundColor = [0.94 0.99 1];
        lbYVar.Value = {};
        edtDerivedName.Value = '';
        edtDerivedExpr.Value = '';
    end

    function exitDerivedMode(clearFields)
        if nargin < 1
            clearFields = false;
        end
        state.derivedMode = false;
        state.derivedChoices = struct('label',{},'expression',{});
        if ~isempty(state.originalYBackground)
            lbYVar.BackgroundColor = state.originalYBackground;
        end
        if clearFields
            edtDerivedName.Value = '';
            edtDerivedExpr.Value = '';
        end
    end

    function tryCreateDerivedVariable(showWarnings)
        if nargin < 1
            showWarnings = false;
        end

        newName = strtrim(edtDerivedName.Value);
        expr    = strtrim(edtDerivedExpr.Value);

        % Require both fields before attempting to evaluate; otherwise stay quiet
        if isempty(newName) || isempty(expr)
            if showWarnings
                if isempty(newName) && isempty(expr)
                    setStatus('Enter a variable name and an expression before creating a derived variable.', true);
                elseif isempty(newName)
                    setStatus('Enter a variable name for the derived variable.', true);
                else
                    setStatus('Enter an expression for the derived variable.', true);
                end
            end
            return;
        end

        if ~isvarname(newName)
            setStatus('Please provide a valid MATLAB variable name.', true);
            return;
        end

        [val, errMsg] = evaluateDerivedExpression(expr);
        if ~isempty(errMsg)
            uialert(fig, errMsg, 'Evaluation error');
            return;
        end

        xLen = getSelectedXLength();
        % Derived outputs are stored with a consistent sample-first orientation
        val  = normalizeDerivedResult(val, xLen);

        try
            assignin('base', newName, val);
            refreshWorkspaceControls();
            setStatus(sprintf('Created derived variable "%s".', newName), false);
            exitDerivedMode(true);
        catch ME
            uialert(fig, sprintf('Could not create variable:\n%s', ME.message), 'Assignment error');
        end
    end

    function [val, errMsg] = evaluateDerivedExpression(expr)
        val = [];
        errMsg = '';

        xName = ddXVar.Value;
        if strcmp(xName, '<select X>') || strcmp(xName, '<no valid arrays>') || isempty(xName)
            errMsg = 'Please select a valid X variable first.';
            return;
        end

        try
            xVal = evalin('base', xName);
        catch ME
            errMsg = sprintf('Cannot evaluate X variable "%s":\n%s', xName, ME.message);
            return;
        end
        if ~(isnumeric(xVal) || islogical(xVal)) || numel(xVal) < 1
            errMsg = 'X must be a numeric array with more than one element.';
            return;
        end

        xLen = numel(xVal);
        overrides = buildDerivedOverrides(xLen);
        cleaner = onCleanup(@() restoreDerivedOverrides(overrides));
        applyDerivedOverrides(overrides);

        try
            val = evalin('base', expr);
        catch ME
            errMsg = sprintf('Error evaluating expression:\n%s', ME.message);
            val = [];
        end
        clear cleaner;
    end

    function overrides = buildDerivedOverrides(xLen)
        overrides = struct('name', {}, 'original', {}, 'oriented', {});
        [~, expressions] = getDerivedVariableChoices();
        expressions = unique(expressions(~cellfun(@isempty, expressions)), 'stable');
        for idx = 1:numel(expressions)
            candidate = expressions{idx};
            if ~isvarname(candidate)
                continue;
            end
            try
                origVal = evalin('base', candidate);
            catch
                continue;
            end
            orientedVal = normalizeDerivedCandidate(origVal, xLen);
            overrides(end+1) = struct('name', candidate, 'original', origVal, 'oriented', orientedVal); %#ok<AGROW>
        end
    end

    function applyDerivedOverrides(overrides)
        for idx = 1:numel(overrides)
            try
                assignin('base', overrides(idx).name, overrides(idx).oriented);
            catch
            end
        end
    end

    function restoreDerivedOverrides(overrides)
        for idx = 1:numel(overrides)
            try
                assignin('base', overrides(idx).name, overrides(idx).original);
            catch
            end
        end
    end

    function val = normalizeDerivedCandidate(val, xLen)
        if isempty(val) || isempty(xLen) || ~isSupportedArray(val)
            return;
        end

        if isvector(val)
            if numel(val) == xLen
                val = val(:);
            end
            return;
        end

        [sampleDim, isCompat] = findSampleDim(size(val), xLen);
        if ~isCompat
            return;
        end

        order = [sampleDim, setdiff(1:ndims(val), sampleDim)];
        val = permute(val, order);
        val = reshape(val, size(val, 1), []);
    end

    function val = normalizeDerivedResult(val, xLen)
        if isempty(val) || isempty(xLen) || ~isSupportedArray(val)
            return;
        end

        if isvector(val)
            if numel(val) == xLen
                val = val(:);
            end
            return;
        end

        [sampleDim, isCompat] = findSampleDim(size(val), xLen);
        if ~isCompat
            return;
        end

        order = [sampleDim, setdiff(1:ndims(val), sampleDim)];
        val = permute(val, order);
        val = reshape(val, size(val, 1), []);
    end

    function [labels, expressions] = getDerivedVariableChoices()
        labels      = {};
        expressions = {};

        xName = ddXVar.Value;
        if ~isempty(xName) && ~strcmp(xName, '<select X>') && ~strcmp(xName, '<no valid arrays>')
            labels{end+1}      = sprintf('X: %s', xName); %#ok<AGROW>
            expressions{end+1} = char(string(xName)); %#ok<AGROW>
        end

        yLabels = lbYVar.Items;
        yData   = lbYVar.ItemsData;
        if ischar(yLabels) || isstring(yLabels)
            yLabels = cellstr(yLabels);
        end

        for yIdx = 1:numel(yLabels)
            expr = '';
            if numel(yData) >= yIdx
                dataEntry = yData{yIdx};
                if isstruct(dataEntry) && isfield(dataEntry, 'expression')
                    expr = dataEntry.expression;
                else
                    expr = char(string(dataEntry));
                end
            end

            if isempty(expr) || any(strcmp(expressions, expr))
                continue;
            end

            labels{end+1}      = yLabels{yIdx}; %#ok<AGROW>
            expressions{end+1} = expr; %#ok<AGROW>
        end
    end

    function refreshWorkspaceControls()
        if state.derivedMode
            exitDerivedMode(true);
        end
        state.workspaceMeta = getWorkspaceSnapshot();

        validNames = {state.workspaceMeta([state.workspaceMeta.isValidXCandidate]).name};

        if isempty(validNames)
            ddXVar.Items   = {'<no valid arrays>'};
            ddXVar.Value   = '<no valid arrays>';
            ddXVar.Enable  = 'off';

            lbYVar.Items     = {};
            lbYVar.ItemsData = {};
            lbYVar.Value     = {};
            lbYVar.Enable    = 'off';

            btnPlot.Enable = 'off';
            return;
        end

        ddXVar.Items = ['<select X>', validNames];
        if ~ismember(ddXVar.Value, ddXVar.Items)
            ddXVar.Value = '<select X>';
        end
        ddXVar.Enable = 'on';

        updateYListForX();
    end

    function subplotInfo = ensureSubplotStruct(subplotInfo)
        if ~isfield(subplotInfo, 'lines') || isempty(subplotInfo.lines)
            subplotInfo.lines = struct('handle',{},'xName',{},'yName',{},'legend',{},'datatips',{}, ...
                'xData',{},'yData',{},'gain',{},'offset',{},'color',{},'lineStyle',{},'lineWidth',{},'displayName',{});
        end
        subplotInfo.lines = ensureLineDefaults(subplotInfo.lines);

        if ~isfield(subplotInfo, 'axisEqual') || isempty(subplotInfo.axisEqual)
            subplotInfo.axisEqual = false;
        end
        if ~isfield(subplotInfo, 'xTickSpacing')
            subplotInfo.xTickSpacing = [];
        end
        if ~isfield(subplotInfo, 'yTickSpacing')
            subplotInfo.yTickSpacing = [];
        end
        if ~isfield(subplotInfo, 'xScale') || isempty(subplotInfo.xScale)
            subplotInfo.xScale = 'linear';
        end
        if ~isfield(subplotInfo, 'yScale') || isempty(subplotInfo.yScale)
            subplotInfo.yScale = 'linear';
        end
        if ~isfield(subplotInfo, 'limitListeners') || isempty(subplotInfo.limitListeners)
            subplotInfo.limitListeners = event.listener.empty;
        end
        if ~isfield(subplotInfo, 'titleText')
            subplotInfo.titleText = '';
        end
        if ~isfield(subplotInfo, 'xLabelText')
            subplotInfo.xLabelText = '';
        end
        if ~isfield(subplotInfo, 'yLabelText')
            subplotInfo.yLabelText = '';
        end
        if ~isfield(subplotInfo, 'xLim') || isempty(subplotInfo.xLim)
            subplotInfo.xLim = [];
        end
        if ~isfield(subplotInfo, 'yLim') || isempty(subplotInfo.yLim)
            subplotInfo.yLim = [];
        end
    end

    function lines = ensureLineDefaults(lines)
        if nargin < 1 || isempty(lines)
            lines = struct('handle',{},'xName',{},'yName',{},'legend',{},'datatips',{}, ...
                'xData',{},'yData',{},'gain',{},'offset',{},'color',{},'lineStyle',{},'lineWidth',{},'displayName',{});
            return;
        end

        for ln = 1:numel(lines)
            if ~isfield(lines(ln), 'legend')
                lines(ln).legend = true;
            end
            if ~isfield(lines(ln), 'datatips') || isempty(lines(ln).datatips)
                lines(ln).datatips = struct('dataIndex', {}, 'orientation', {});
            elseif isnumeric(lines(ln).datatips)
                numericTips = lines(ln).datatips;
                tipStruct = struct('dataIndex', {}, 'orientation', {});
                for tipIdx = 1:numel(numericTips)
                    tipStruct(end+1) = struct('dataIndex', numericTips(tipIdx), 'orientation', ''); %#ok<AGROW>
                end
                lines(ln).datatips = tipStruct;
            else
                tipStruct = struct('dataIndex', {}, 'orientation', {});
                for tipIdx = 1:numel(lines(ln).datatips)
                    curTip = lines(ln).datatips(tipIdx);
                    curIdx = [];
                    if isfield(curTip, 'dataIndex')
                        curIdx = curTip.dataIndex;
                    end
                    curOrientation = '';
                    if isfield(curTip, 'orientation') && ~isempty(curTip.orientation)
                        curOrientation = curTip.orientation;
                    end
                    tipStruct(end+1) = struct('dataIndex', curIdx, 'orientation', curOrientation); %#ok<AGROW>
                end
                lines(ln).datatips = tipStruct;
            end
            if ~isfield(lines(ln), 'gain') || isempty(lines(ln).gain)
                lines(ln).gain = 1;
            end
            if ~isfield(lines(ln), 'offset') || isempty(lines(ln).offset)
                lines(ln).offset = 0;
            end
            if ~isfield(lines(ln), 'xData') || isempty(lines(ln).xData)
                lines(ln).xData = safeGetLineData(lines(ln).handle, 'XData');
            end
            if ~isfield(lines(ln), 'yData') || isempty(lines(ln).yData)
                lines(ln).yData = safeGetLineData(lines(ln).handle, 'YData');
            end
            if ~isfield(lines(ln), 'color') || isempty(lines(ln).color)
                lines(ln).color = safeGetLineColor(lines(ln).handle);
            end
            if ~isfield(lines(ln), 'lineStyle') || isempty(lines(ln).lineStyle)
                lines(ln).lineStyle = safeGetLineStyle(lines(ln).handle);
            end
            if ~isfield(lines(ln), 'lineWidth') || isempty(lines(ln).lineWidth)
                lines(ln).lineWidth = safeGetLineWidth(lines(ln).handle);
            end
            if ~isfield(lines(ln), 'displayName') || isempty(lines(ln).displayName)
                lines(ln).displayName = safeGetDisplayName(lines(ln).handle, lines(ln).yName);
            end
        end
    end

    function data = safeGetLineData(hLine, prop)
        data = [];
        if isempty(hLine) || ~isvalid(hLine)
            return;
        end

        try
            data = get(hLine, prop);
        catch
            data = [];
        end

        data = data(:).';
    end

    function col = safeGetLineColor(hLine)
        col = [0 0.4470 0.7410];
        if isempty(hLine) || ~isvalid(hLine)
            return;
        end
        try
            col = hLine.Color;
        catch
        end
    end

    function ls = safeGetLineStyle(hLine)
        ls = '-';
        if isempty(hLine) || ~isvalid(hLine)
            return;
        end
        try
            ls = hLine.LineStyle;
        catch
        end
    end

    function lw = safeGetLineWidth(hLine)
        lw = 1.5;
        if isempty(hLine) || ~isvalid(hLine)
            return;
        end
        try
            lw = hLine.LineWidth;
        catch
        end
    end

    function dn = safeGetDisplayName(hLine, fallback)
        dn = '';
        if nargin >= 2
            dn = fallback;
        end
        if isempty(hLine) || ~isvalid(hLine)
            return;
        end
        try
            dn = hLine.DisplayName;
        catch
        end
    end

    function tf = isSupportedArray(val)
        tf = isnumeric(val) || islogical(val) || ...
            isdatetime(val) || isduration(val);
    end

    function meta = getWorkspaceSnapshot()
        % Gather workspace metadata for arrays and containers
        vars = evalin('base', 'whos');
        meta = struct('name',{},'class',{},'size',{},'isSupportedArray',{},'numel',{},'isIntegerScalar',{},'kind',{},'scalarValue',{},'isNumeric',{},'isValidXCandidate',{});

        for k = 1:numel(vars)
            name = vars(k).name;

            info = struct('name', name, 'class', '', 'size', [], ...
                'isSupportedArray', false, 'numel', 0, ...
                'isIntegerScalar', false, 'kind', '', 'scalarValue', [], 'isNumeric', false, 'isValidXCandidate', false);

            try
                val = evalin('base', name);
            catch
                continue;
            end

            info.class            = class(val);
            info.size             = size(val);
            info.isSupportedArray = isSupportedArray(val);
            info.numel            = numel(val);
            info.kind             = classifyValueKind(val);
            info.isIntegerScalar  = isscalar(val) && isnumeric(val) && isfinite(val) && val == round(val);
            info.isNumeric        = isnumeric(val);
            info.isValidXCandidate = info.isNumeric && info.numel > 1;
            if info.isIntegerScalar
                info.scalarValue = double(val);
            end

            meta(end+1) = info; %#ok<AGROW>
        end
    end

    function kind = classifyValueKind(val)
        if istable(val)
            kind = 'table';
            return;
        end

        if isstruct(val)
            kind = 'struct';
            return;
        end

        if iscell(val)
            kind = 'cell';
            return;
        end

        if isSupportedArray(val)
            kind = 'array';
            return;
        end

        kind = 'other';
    end

    function onXSelectionChanged(~, ~)
        validateSelectedX(true);
        updateYListForX();
    end

    function updateYListForX()
        validateCustomItems();

        [isValidX, ~] = validateSelectedX(false);
        if ~isValidX
            lbYVar.Items     = {};
            lbYVar.ItemsData = {};
            lbYVar.Value     = {};
            lbYVar.Enable    = 'off';
            btnPlot.Enable   = 'off';
            return;
        end

        xLen   = getSelectedXLength();
        discovered = discoverBaseCandidates(xLen);

        yItems = {};
        yData  = {};

        for k = 1:numel(discovered)
            [yItems, yData] = appendYEntry(yItems, yData, discovered(k).label, discovered(k).expression); %#ok<AGROW>
        end

        for k = 1:numel(state.customYItems)
            item = state.customYItems(k);
            if ~isempty(xLen) && ~isLengthCompatible(item.dimSizes, xLen)
                continue;
            end
            [yItems, yData] = appendYEntry(yItems, yData, item.label, item.expression); %#ok<AGROW>
        end

        lbYVar.Items     = yItems;
        lbYVar.ItemsData = yData;
        lbYVar.Value     = {};
        lbYVar.Enable    = ternary(~isempty(yItems), 'on', 'off');

        syncPlotButtonState();
    end

    function [items, data] = appendYEntry(items, data, label, expr)
        items{end+1} = label; %#ok<AGROW>
        data{end+1}  = struct('label', label, 'expression', expr); %#ok<AGROW>
    end

    function validateCustomItems()
        validEntries = struct('label',{},'expression',{},'dimSizes',{});
        for k = 1:numel(state.customYItems)
            item = state.customYItems(k);
            try
                val = evalin('base', item.expression);
            catch
                continue;
            end

            if ~isSupportedArray(val)
                continue;
            end

            item.dimSizes = size(val);
            validEntries(end+1) = item; %#ok<AGROW>
        end

        state.customYItems = validEntries;
    end

    function tf = isLengthCompatible(dimSizes, xLen)
        if isempty(xLen)
            tf = true;
            return;
        end

        if isempty(dimSizes)
            tf = false;
            return;
        end

        tf = any(dimSizes == xLen);
    end

    function candidates = discoverBaseCandidates(xLen)
        vars        = state.workspaceMeta;
        integerVars = getIntegerVariables();
        maxDepth    = 3;
        maxPerRoot  = 80;
        maxChildren = 20;

        candidates = struct('label',{},'expression',{},'dimSizes',{});
        visited = containers.Map('KeyType', 'char', 'ValueType', 'logical');
        perRootCount = containers.Map('KeyType', 'char', 'ValueType', 'double');

        for k = 1:numel(vars)
            rootName = vars(k).name;
            try
                rootVal = evalin('base', rootName);
            catch
                continue;
            end

            exploreValue(rootVal, rootName, rootName, 0, rootName);
        end

        function addCandidate(label, expr, dimSizes, rootLabel)
            if isempty(expr)
                return;
            end
            if isKey(visited, expr)
                return;
            end

            if ~isLengthCompatible(dimSizes, xLen)
                return;
            end

            currentCount = 0;
            if isKey(perRootCount, rootLabel)
                currentCount = perRootCount(rootLabel);
            end
            if currentCount >= maxPerRoot
                return;
            end

            visited(expr) = true;
            perRootCount(rootLabel) = currentCount + 1;
            candidates(end+1) = struct('label', label, 'expression', expr, 'dimSizes', dimSizes); %#ok<AGROW>
        end

        function exploreValue(val, expr, label, depth, rootLabel)
            if depth > maxDepth
                return;
            end

            kindLocal = classifyValueKind(val);

            if isSupportedArray(val)
                addCandidate(label, expr, size(val), rootLabel);
                if depth >= maxDepth
                    return;
                end
            end

            switch kindLocal
                case 'struct'
                    if numel(val) > 1
                        validIdx = filterIntegerIndices(integerVars, numel(val));
                        for idx = 1:min(numel(validIdx), maxChildren)
                            idxExpr = validIdx(idx).name;
                            childExpr = sprintf('%s(%s)', expr, idxExpr);
                            childLabel = sprintf('%s(%s)', label, idxExpr);
                            childVal = safeEval(childExpr);
                            if isempty(childVal)
                                continue;
                            end
                            exploreStruct(childVal, childExpr, childLabel, depth, rootLabel);
                        end
                    else
                        exploreStruct(val, expr, label, depth, rootLabel);
                    end

                case 'cell'
                    validIdx = filterIntegerIndices(integerVars, numel(val));
                    for idx = 1:min(numel(validIdx), maxChildren)
                        idxExpr = sprintf('{%s}', validIdx(idx).name);
                        childExpr = sprintf('%s%s', expr, idxExpr);
                        childLabel = sprintf('%s%s', label, idxExpr);
                        childVal = safeEval(childExpr);
                        if isempty(childVal)
                            continue;
                        end
                        exploreValue(childVal, childExpr, childLabel, depth + 1, rootLabel);
                    end

                case 'table'
                    tableWidth = width(val);
                    tableHeight = height(val);
                    validCols = filterIntegerIndices(integerVars, tableWidth);
                    validRows = filterIntegerIndices(integerVars, tableHeight);

                    for idx = 1:min(numel(validCols), maxChildren)
                        idxName = validCols(idx).name;
                        colExpr = sprintf('%s{:, %s}', expr, idxName);
                        colLabel = sprintf('%s{:, %s}', label, idxName);
                        colVal = safeEval(colExpr);
                        if ~isempty(colVal)
                            exploreValue(colVal, colExpr, colLabel, depth + 1, rootLabel);
                        end
                    end

                    for idx = 1:min(numel(validRows), maxChildren)
                        idxName = validRows(idx).name;
                        rowExpr = sprintf('%s{%s, :}', expr, idxName);
                        rowLabel = sprintf('%s{%s, :}', label, idxName);
                        rowVal = safeEval(rowExpr);
                        if ~isempty(rowVal)
                            exploreValue(rowVal, rowExpr, rowLabel, depth + 1, rootLabel);
                        end
                    end

                    if depth < maxDepth
                        try
                            colNames = val.Properties.VariableNames;
                        catch
                            colNames = {};
                        end
                        for c = 1:min(numel(colNames), maxChildren)
                            colName = colNames{c};
                            colExpr = sprintf('%s.%s', expr, colName);
                            colLabel = sprintf('%s.%s', label, colName);
                            colVal = safeEval(colExpr);
                            if ~isempty(colVal)
                                exploreValue(colVal, colExpr, colLabel, depth + 1, rootLabel);
                            end
                        end
                    end

                case 'array'
                    sz = size(val);
                    nd = numel(sz);
                    dimsToUse = 1:min(nd, 3);
                    for idxVar = 1:min(numel(integerVars), maxChildren)
                        idxVal = integerVars(idxVar).scalarValue;
                        if ~isfinite(idxVal)
                            continue;
                        end
                        for d = dimsToUse
                            if idxVal < 1 || idxVal > sz(d)
                                continue;
                            end
                            subs = repmat({':'}, 1, nd);
                            subs{d} = integerVars(idxVar).name;
                            sliceExpr = sprintf('%s(%s)', expr, strjoin(subs, ','));
                            sliceLabel = sprintf('%s(dim%d=%s)', label, d, integerVars(idxVar).name);
                            sliceVal = safeEval(sliceExpr);
                            if ~isempty(sliceVal)
                                exploreValue(sliceVal, sliceExpr, sliceLabel, depth + 1, rootLabel);
                            end
                        end
                    end
            end
        end

        function exploreStruct(val, expr, label, depth, rootLabel)
            fields = {};
            try
                fields = fieldnames(val);
            catch
                return;
            end

            for fIdx = 1:min(numel(fields), maxChildren)
                fieldName = fields{fIdx};
                childExpr = sprintf('%s.%s', expr, fieldName);
                childLabel = sprintf('%s.%s', label, fieldName);
                childVal = safeEval(childExpr);
                if isempty(childVal)
                    continue;
                end
                exploreValue(childVal, childExpr, childLabel, depth + 1, rootLabel);
            end
        end

        function subset = filterIntegerIndices(intVars, upperBound)
            mask = arrayfun(@(v) v.scalarValue >= 1 && v.scalarValue <= upperBound, intVars);
            subset = intVars(mask);
        end

        function out = safeEval(expr)
            try
                out = evalin('base', expr);
            catch
                out = [];
            end
        end
    end

    function [sampleDim, isCompat] = findSampleDim(dimSizes, targetLen)
        sampleDim = [];
        isCompat  = false;
        if isempty(targetLen) || isempty(dimSizes)
            return;
        end

        matches = find(dimSizes == targetLen, 1);
        if isempty(matches)
            return;
        end

        sampleDim = matches(1);
        isCompat  = true;
    end

    function [seriesData, labels] = reshapeSeriesForPlot(yVal, sampleDim, baseLabel)
        order = [sampleDim, setdiff(1:ndims(yVal), sampleDim)];
        yReordered = permute(yVal, order);
        seriesData = reshape(yReordered, size(yReordered, 1), []);

        otherDims = size(yReordered);
        if isempty(otherDims)
            otherDims = 1;
        end
        otherDims(1) = [];
        if isempty(otherDims)
            labels = {baseLabel};
            return;
        end

        totalSeries = size(seriesData, 2);
        if totalSeries == 1
            labels = {baseLabel};
            return;
        end

        labels = cell(1, totalSeries);
        for sIdx = 1:totalSeries
            subs = linearToSubs(otherDims, sIdx);
            if numel(subs) > 1
                suffix = strjoin(arrayfun(@(s) num2str(s), subs, 'UniformOutput', false), ',');
            else
                suffix = num2str(subs);
            end
            labels{sIdx} = sprintf('%s (%s)', baseLabel, suffix);
        end
    end

    function subs = linearToSubs(dims, idx)
        if isempty(dims)
            subs = 1;
            return;
        end
        cells = cell(1, numel(dims));
        [cells{:}] = ind2sub(dims, idx);
        subs = cellfun(@(c) c, cells);
    end

    function len = getSelectedXLength()
        len = [];
        xName = ddXVar.Value;
        if strcmp(xName, '<select X>') || strcmp(xName, '<no valid arrays>') || isempty(xName)
            return;
        end

        idx = find(strcmp({state.workspaceMeta.name}, xName), 1);
        if ~isempty(idx)
            if state.workspaceMeta(idx).isValidXCandidate
                len = state.workspaceMeta(idx).numel;
            else
                len = [];
            end
            return;
        end

        try
            len = numel(evalin('base', xName));
        catch
        end
    end

    function [ok, msg] = validateSelectedX(showDialog)
        if nargin < 1
            showDialog = false;
        end

        ok = false;
        msg = '';
        xName = ddXVar.Value;
        if strcmp(xName, '<select X>') || strcmp(xName, '<no valid arrays>') || isempty(xName)
            msg = 'Please select a vector or array for X.';
            return;
        end

        idx = find(strcmp({state.workspaceMeta.name}, xName), 1);
        if ~isempty(idx)
            meta = state.workspaceMeta(idx);
            ok = meta.isValidXCandidate;
            msg = 'X must be a numeric array with more than one element.';
        else
            try
                xVal = evalin('base', xName);
                ok = isnumeric(xVal) && numel(xVal) > 1;
                msg = 'X must be a numeric array with more than one element.';
            catch ME
                msg = sprintf('Could not evaluate X: %s', ME.message);
                ok = false;
            end
        end

        if ~ok && showDialog
            uialert(fig, msg, 'Invalid X selection');
            ddXVar.Value = '<select X>';
        end
    end

    function syncPlotButtonState()
        hasX = validateSelectedX(false);
        hasY = ~isempty(lbYVar.Items);
        btnPlot.Enable = ternary(hasX && hasY, 'on', 'off');
    end

    function addCustomYItem(label, expr, dimSizes)
        if nargin < 3
            dimSizes = [];
        end

        % Drop existing entries that rely on the same expression
        keepMask = true(1, numel(state.customYItems));
        for k = 1:numel(state.customYItems)
            keepMask(k) = ~strcmp(state.customYItems(k).expression, expr);
        end
        state.customYItems = state.customYItems(keepMask);

        state.customYItems(end+1) = struct('label', label, 'expression', expr, 'dimSizes', dimSizes); %#ok<AGROW>
    end

    function integers = getIntegerVariables()
        integers = state.workspaceMeta([state.workspaceMeta.isIntegerScalar]);
    end

    function tf = isContainerCandidate(metaEntry)
        tf = ismember(metaEntry.kind, {'struct', 'cell', 'table'});
    end

    function txt = sizeToString(sz)
        if isempty(sz)
            txt = '';
            return;
        end
        txt = strjoin(string(sz), 'x');
    end

    function onOpenOtherData(~, ~)
        if strcmp(ddXVar.Value, '<select X>') || strcmp(ddXVar.Value, '<no valid arrays>')
            uialert(fig, 'Please select an X variable first so compatible choices can be highlighted.', ...
                'Select X variable');
            return;
        end

        state.workspaceMeta = getWorkspaceSnapshot();
        candidates = state.workspaceMeta(arrayfun(@(m) isContainerCandidate(m), state.workspaceMeta));

        if isempty(candidates)
            uialert(fig, 'No structures, cell arrays, tables, or multi-column arrays found in the workspace.', ...
                'Nothing to explore');
            return;
        end

        xLenLocal = getSelectedXLength();

        otherFig = uifigure('Name', 'Other workspace data', ...
            'Position', [200 200 820 520], 'Color', [1 1 1]);
        otherFig.WindowStyle = 'modal';

        popupGrid = uigridlayout(otherFig, [3 2]);
        popupGrid.RowHeight = {'fit', '1x', 'fit'};
        popupGrid.ColumnWidth = {260, '1x'};

        lblIntro = uilabel(popupGrid, ...
            'Text', 'Browse complex workspace variables. Only selections compatible with the current X length will be accepted.', ...
            'WordWrap', 'on');
        lblIntro.Layout.Row    = 1;
        lblIntro.Layout.Column = [1 2];

        containerLabels = arrayfun(@(m) sprintf('%s (%s [%s])', m.name, m.kind, sizeToString(m.size)), ...
            candidates, 'UniformOutput', false);
        lstContainers = uilistbox(popupGrid, ...
            'Items', containerLabels, ...
            'ItemsData', num2cell(1:numel(candidates)), ...
            'Multiselect', 'off');
        lstContainers.Layout.Row    = 2;
        lstContainers.Layout.Column = 1;

        detailPanel = uipanel(popupGrid, 'Title', 'Selection details', 'BackgroundColor', [1 1 1]);
        detailPanel.Layout.Row    = 2;
        detailPanel.Layout.Column = 2;

        detailGrid = uigridlayout(detailPanel, [7 2]);
        detailGrid.RowHeight   = {'fit', '1x', 'fit', 'fit', 'fit', 'fit', 'fit'};
        detailGrid.ColumnWidth = {150, '1x'};

        lblDetails = uilabel(detailGrid, 'Text', 'Select a variable to begin.', 'WordWrap', 'on');
        lblDetails.Layout.Row    = 1;
        lblDetails.Layout.Column = [1 2];

        selectionTree = uitree(detailGrid, ...
            'SelectionChangedFcn', @onTreeSelectionChanged, ...
            'Visible', 'on');
        selectionTree.Layout.Row    = 2;
        selectionTree.Layout.Column = [1 2];

        lblIndexMode = uilabel(detailGrid, 'Text', 'Index mode:', 'Visible', 'off');
        lblIndexMode.Layout.Row    = 3;
        lblIndexMode.Layout.Column = 1;
        ddIndexMode = uidropdown(detailGrid, 'Items', {}, 'Visible', 'off');
        ddIndexMode.Layout.Row    = 3;
        ddIndexMode.Layout.Column = 2;

        lblIndexValue = uilabel(detailGrid, 'Text', 'Index / path:', 'Visible', 'off');
        lblIndexValue.Layout.Row    = 4;
        lblIndexValue.Layout.Column = 1;
        edtIndexValue = uieditfield(detailGrid, 'text', ...
            'Visible', 'off', 'Value', '');
        edtIndexValue.Layout.Row    = 4;
        edtIndexValue.Layout.Column = 2;

        lblPopupStatus = uilabel(detailGrid, 'Text', ' ', 'WordWrap', 'on', 'Visible', 'off', ...
            'FontColor', [0.1 0.5 0.1]);
        lblPopupStatus.Layout.Row    = 6;
        lblPopupStatus.Layout.Column = [1 2];

        btnAddFromOther = uibutton(detailGrid, 'Text', 'Add selection to Y list', ...
            'Enable', 'off');
        btnAddFromOther.Layout.Row    = 7;
        btnAddFromOther.Layout.Column = [1 2];

        btnClose = uibutton(popupGrid, 'Text', 'Close explorer', ...
            'ButtonPushedFcn', @(~, ~) close(otherFig));
        btnClose.Layout.Row    = 3;
        btnClose.Layout.Column = [1 2];

        currentMeta = [];
        currentNode = [];

        lstContainers.ValueChangedFcn = @onContainerChanged;
        btnAddFromOther.ButtonPushedFcn = @onAddFromOther;

        if ~isempty(lstContainers.ItemsData)
            lstContainers.Value = lstContainers.ItemsData{1};
            onContainerChanged();
        end

        function onContainerChanged(~, ~)
            idx = lstContainers.Value;
            if isempty(idx)
                return;
            end

            currentMeta = candidates(idx);
            lblDetails.Text = sprintf('%s (%s) size [%s]', currentMeta.name, currentMeta.class, sizeToString(currentMeta.size));
            resetSelectors();
            buildTreeForMeta(currentMeta);
        end

        function buildTreeForMeta(metaEntry)
            delete(selectionTree.Children);
            try
                val = evalin('base', metaEntry.name);
            catch ME
                setPopupStatus(sprintf('Cannot evaluate "%s": %s', metaEntry.name, ME.message), true);
                return;
            end

            rootMeta = describeValue(metaEntry.name, val, metaEntry.name);
            rootNode = uitreenode(selectionTree, 'Text', formatMeta(rootMeta), 'NodeData', rootMeta);
            expandNode(rootNode, val);
            selectionTree.SelectedNodes = rootNode;
            onTreeSelectionChanged();
        end

        function meta = describeValue(expr, val, label)
            if nargin < 3
                label = expr;
            end
            meta = struct( ...
                'expression', expr, ...
                'label',      label, ...
                'class',      class(val), ...
                'size',       size(val), ...
                'kind',       classifyValueKind(val), ...
                'isSupportedArray', isSupportedArray(val));
        end

        function lbl = formatMeta(meta)
            lbl = sprintf('%s (%s [%s])', meta.label, meta.kind, sizeToString(meta.size));
        end

        function expandNode(node, valOverride)
            if isempty(node) || ~isvalid(node)
                return;
            end

            meta = node.NodeData;
            val  = [];
            if nargin > 1
                val = valOverride;
            else
                try
                    val = evalin('base', meta.expression);
                catch
                    return;
                end
            end

            delete(node.Children);
            childMetas = enumerateChildren(meta, val);
            for k = 1:numel(childMetas)
                uitreenode(node, 'Text', formatMeta(childMetas(k)), 'NodeData', childMetas(k)); %#ok<AGROW>
            end
        end

        function children = enumerateChildren(meta, val)
            children = struct('expression',{},'label',{},'class',{},'size',{},'kind',{},'isSupportedArray',{});
            maxItems = 30;

            switch meta.kind
                case 'table'
                    try
                        colNames = val.Properties.VariableNames;
                    catch
                        colNames = {};
                    end

                    for c = 1:numel(colNames)
                        colName = colNames{c};
                        try
                            childVal = val.(colName);
                        catch
                            childVal = [];
                        end
                        childExpr = sprintf('%s.%s', meta.expression, colName);
                        childLabel = sprintf('%s.%s', meta.label, colName);
                        children(end+1) = describeValue(childExpr, childVal, childLabel); %#ok<AGROW>
                    end

                case 'struct'
                    if numel(val) > 1
                        idxCount = min(numel(val), maxItems);
                        for idxLocal = 1:idxCount
                            idxStr = indexToString(idxLocal, size(val), false);
                            childExpr = sprintf('%s(%s)', meta.expression, idxStr);
                            childLabel = sprintf('%s(%s)', meta.label, idxStr);
                            try
                                childVal = val(idxLocal);
                            catch
                                childVal = [];
                            end
                            children(end+1) = describeValue(childExpr, childVal, childLabel); %#ok<AGROW>
                        end
                    else
                        fields = {};
                        try
                            fields = fieldnames(val);
                        catch
                        end
                        for fIdx = 1:numel(fields)
                            fieldName = fields{fIdx};
                            childExpr = sprintf('%s.%s', meta.expression, fieldName);
                            childLabel = sprintf('%s.%s', meta.label, fieldName);
                            try
                                childVal = val.(fieldName);
                            catch
                                childVal = [];
                            end
                            children(end+1) = describeValue(childExpr, childVal, childLabel); %#ok<AGROW>
                        end
                    end

                case 'cell'
                    idxCount = min(numel(val), maxItems);
                    for idxLocal = 1:idxCount
                        idxStr = indexToString(idxLocal, size(val), true);
                        childExpr = sprintf('%s%s', meta.expression, idxStr);
                        childLabel = sprintf('%s%s', meta.label, idxStr);
                        try
                            childVal = val{idxLocal};
                        catch
                            childVal = [];
                        end
                        children(end+1) = describeValue(childExpr, childVal, childLabel); %#ok<AGROW>
                    end
            end
        end

        function idxStr = indexToString(idxLocal, sz, useBraces)
            if nargin < 3
                useBraces = false;
            end
            subs = cell(1, numel(sz));
            [subs{:}] = ind2sub(sz, idxLocal);
            subStr = strjoin(arrayfun(@(s) sprintf('%d', s), [subs{:}], 'UniformOutput', false), ',');
            if useBraces
                idxStr = sprintf('{%s}', subStr);
            else
                idxStr = subStr;
            end
        end

        function onTreeSelectionChanged(~, evt)
            if nargin < 2 || isempty(evt)
                evt = struct('SelectedNodes', selectionTree.SelectedNodes);
            end

            if isempty(evt.SelectedNodes)
                btnAddFromOther.Enable = 'off';
                return;
            end

            currentNode = evt.SelectedNodes(1);
            currentMeta = currentNode.NodeData;

            lblDetails.Text = formatMeta(currentMeta);
            resetSelectors();
            configureIndexControls(currentMeta);

            if isContainerKind(currentMeta.kind)
                expandNode(currentNode);
            end

            btnAddFromOther.Enable = ternary(currentMeta.isSupportedArray || isContainerKind(currentMeta.kind), 'on', 'off');
        end

        function tf = isContainerKind(kind)
            tf = ismember(kind, {'cell', 'struct', 'table'});
        end

        function configureIndexControls(meta)
            showIndexControls(false, false);

            switch meta.kind
                case 'array'
                    hasMultipleColumns = numel(meta.size) >= 2 && meta.size(2) > 1;
                    showIndexControls(hasMultipleColumns, true);
                    if hasMultipleColumns
                        ddIndexMode.Items = {'Column', 'Row', 'Linear index'};
                        ddIndexMode.Value = 'Column';
                    end
                case {'cell', 'struct'}
                    showIndexControls(true, false);
            end
        end

        function showIndexControls(flag, includeMode)
            if nargin < 2
                includeMode = false;
            end
            lblIndexValue.Visible = flag;
            edtIndexValue.Visible = flag;

            lblIndexMode.Visible = flag && includeMode;
            ddIndexMode.Visible  = flag && includeMode;
        end

        function resetSelectors()
            btnAddFromOther.Enable = 'off';
            lblPopupStatus.Visible = 'off';
            showIndexControls(false, false);
            edtIndexValue.Value = '';
        end

        function idxStr = getIndexString(kind)
            if nargin < 1
                kind = '';
            end
            idxStr = '';
            raw = strtrim(edtIndexValue.Value);
            if isempty(raw)
                return;
            end

            switch kind
                case 'cell'
                    idxStr = normalizeCellIndex(raw);
                otherwise
                    idxStr = raw;
            end
        end

        function idxStr = normalizeCellIndex(raw)
            cleaned = regexprep(raw, '^\{', '');
            cleaned = regexprep(cleaned, '\}$', '');
            parts = regexp(cleaned, '\s*,\s*', 'split');
            parts = parts(~cellfun(@isempty, parts));
            if isempty(parts)
                idxStr = '';
                return;
            end

            idxStr = strjoin(arrayfun(@(p) sprintf('{%s}', p{1}), parts, 'UniformOutput', false), '');
        end

        function setPopupStatus(msg, isError)
            if nargin < 2
                isError = false;
            end
            lblPopupStatus.Text    = msg;
            lblPopupStatus.Visible = true;
            if isError
                lblPopupStatus.FontColor = [0.75 0 0];
            else
                lblPopupStatus.FontColor = [0.1 0.5 0.1];
            end
        end

        function [expr, label, val, valMeta] = buildExpression()
            expr  = '';
            label = '';
            val   = [];
            valMeta = [];
            if isempty(currentMeta)
                return;
            end

            baseExpr  = currentMeta.expression;
            baseLabel = currentMeta.label;

            switch currentMeta.kind
                case 'struct'
                    if numel(currentMeta.size) > 1 && prod(currentMeta.size) > 1 && ~contains(baseExpr, '(')
                        idxStr = getIndexString('struct');
                        if isempty(idxStr)
                            setPopupStatus('Provide a valid struct index or pick a child node.', true);
                            return;
                        end
                        baseExpr  = sprintf('%s(%s)', baseExpr, idxStr);
                        baseLabel = sprintf('%s(%s)', baseLabel, idxStr);
                    end
                    expr  = baseExpr;
                    label = baseLabel;

                case 'cell'
                    idxStr = getIndexString('cell');
                    if isempty(idxStr)
                        setPopupStatus('Provide a cell index or nested path (e.g., 1,2).', true);
                        return;
                    end
                    expr  = sprintf('%s%s', baseExpr, idxStr);
                    label = sprintf('%s%s', baseLabel, idxStr);

                case 'array'
                    expr  = baseExpr;
                    label = baseLabel;
                    idxStr = getIndexString('array');
                    if ddIndexMode.Visible && ~isempty(idxStr)
                        switch ddIndexMode.Value
                            case 'Row'
                                expr  = sprintf('%s(%s,:)', baseExpr, idxStr);
                                label = sprintf('%s row %s', baseLabel, idxStr);
                            case 'Column'
                                expr  = sprintf('%s(:,%s)', baseExpr, idxStr);
                                label = sprintf('%s(:,%s)', baseLabel, idxStr);
                            otherwise
                                expr  = sprintf('%s(%s)', baseExpr, idxStr);
                                label = sprintf('%s(%s)', baseLabel, idxStr);
                        end
                    elseif ~isempty(idxStr)
                        expr  = sprintf('%s(%s)', baseExpr, idxStr);
                        label = expr;
                    end

                otherwise
                    expr  = baseExpr;
                    label = baseLabel;
            end

            try
                val = evalin('base', expr);
            catch ME
                setPopupStatus(sprintf('Cannot evaluate "%s": %s', expr, ME.message), true);
                expr  = '';
                label = '';
                return;
            end

            valMeta = describeValue(expr, val, label);
        end

        function onAddFromOther(~, ~)
            [expr, label, candidateVal, valMeta] = buildExpression();
            if isempty(expr)
                return;
            end

            if isempty(valMeta)
                try
                    candidateVal = evalin('base', expr);
                    valMeta = describeValue(expr, candidateVal, label);
                catch ME
                    setPopupStatus(sprintf('Cannot evaluate "%s": %s', expr, ME.message), true);
                    return;
                end
            end

            if isempty(candidateVal)
                setPopupStatus('Selected entry could not be evaluated.', true);
                return;
            end

            if ~valMeta.isSupportedArray
                if isContainerKind(valMeta.kind)
                    if ~isempty(currentNode) && isvalid(currentNode) && ...
                            isfield(currentNode.NodeData, 'expression') && ...
                            strcmp(currentNode.NodeData.expression, valMeta.expression)
                        expandNode(currentNode, candidateVal);
                        selectionTree.SelectedNodes = currentNode;
                    else
                        targetParent = currentNode;
                        if isempty(targetParent) || ~isvalid(targetParent)
                            targetParent = selectionTree;
                        end

                        existingChild = findChildByExpression(targetParent, valMeta.expression);
                        if isempty(existingChild)
                            newNode = uitreenode(targetParent, 'Text', formatMeta(valMeta), 'NodeData', valMeta);
                            expandNode(newNode, candidateVal);
                            selectionTree.SelectedNodes = newNode;
                        else
                            expandNode(existingChild, candidateVal);
                            selectionTree.SelectedNodes = existingChild;
                        end
                    end
                    setPopupStatus('Selection is a container; drill down to reach a plottable array.', true);
                else
                    setPopupStatus('Selected data is not a plottable array.', true);
                end
                return;
            end

            if ~isempty(xLenLocal) && ~isLengthCompatible(size(candidateVal), xLenLocal)
                setPopupStatus(sprintf(['Length mismatch: X has %d elements but no dimension of the selection matches ' ...
                    '(%s).'], xLenLocal, sizeToString(size(candidateVal))), true);
                return;
            end

            addCustomYItem(label, expr, size(candidateVal));
            updateYListForX();
            if ~isempty(lbYVar.ItemsData)
                lbYVar.Value = {lbYVar.ItemsData{end}};
            end
            setPopupStatus(sprintf('Added "%s" to Y list.', label), false);
        end

        function node = findChildByExpression(parentNode, expr)
            node = [];
            if isempty(parentNode) || ~isvalid(parentNode)
                return;
            end

            for child = parentNode.Children.'
                data = child.NodeData;
                if isfield(data, 'expression') && strcmp(data.expression, expr)
                    node = child;
                    return;
                end
            end
        end
    end

    function onClearPlot(~, ~)
        clearSubplot(state.activeSubplot);
    end

    function onPlot(~, ~)
        % Plot Y variable(s) vs X using workspace variables

        if strcmp(ddXVar.Value, '<select X>') || ...
                strcmp(ddXVar.Value, '<no valid arrays>')
            uialert(fig, 'Please select a valid X variable.', ...
                'Missing X variable');
            return;
        end

        xName = ddXVar.Value;

        ySelection = lbYVar.Value;
        if isstruct(ySelection)
            ySelection = {ySelection};
        elseif ischar(ySelection)
            ySelection = {ySelection};
        end
        if isempty(ySelection)
            uialert(fig, 'Please select at least one Y variable.', ...
                'Missing Y variable');
            return;
        end

        [isValidX, msgX] = validateSelectedX(true);
        if ~isValidX
            return;
        end

        % Evaluate X once
        try
            xVal = evalin('base', xName);
        catch ME
            uialert(fig, sprintf('Cannot evaluate X variable "%s":\n%s', ...
                xName, ME.message), 'Error evaluating X');
            return;
        end
        if ~(isnumeric(xVal) && numel(xVal) > 1)
            uialert(fig, msgX, 'Invalid X variable');
            return;
        end

        xFlat = xVal(:);

        subplotIdx  = state.activeSubplot;
        subplotInfo = state.subplots(subplotIdx);
        targetAx    = subplotInfo.axes;

        superpose = subplotInfo.superpose;

        % Clear previous lines only if not superposing
        if ~superpose
            clearSubplot(subplotIdx);
            subplotInfo = state.subplots(subplotIdx);
        end

        hold(targetAx, 'on');

        anyPlotted     = false;
        newLineHandles = {};

        for k = 1:numel(ySelection)
            yLabel = '';
            yExpr  = '';
            if isstruct(ySelection{k}) && isfield(ySelection{k}, 'expression')
                yExpr  = ySelection{k}.expression;
                yLabel = ySelection{k}.label;
            else
                yExpr  = ySelection{k};
                yLabel = char(string(ySelection{k}));
            end

            try
                yVal = evalin('base', yExpr);
            catch ME
                uialert(fig, sprintf('Cannot evaluate Y variable "%s":\n%s', ...
                    yLabel, ME.message), 'Error evaluating Y');
                continue;
            end
            if ~isSupportedArray(yVal)
                uialert(fig, sprintf('Y variable "%s" is not a supported array type.', yLabel), ...
                    'Invalid Y variable');
                continue;
            end

            [sampleDim, isCompat] = findSampleDim(size(yVal), numel(xFlat));
            if ~isCompat
                uialert(fig, sprintf( ...
                    'X (%s) length is %d but no dimension of Y (%s) matches [%s].', ...
                    xName, numel(xFlat), yLabel, sizeToString(size(yVal))), ...
                    'Size mismatch');
                continue;
            end

            [ySeries, seriesLabels] = reshapeSeriesForPlot(yVal, sampleDim, yLabel);

            for sIdx = 1:size(ySeries, 2)
                hLine = plot(targetAx, xFlat, ySeries(:, sIdx), ...
                    'LineWidth',   1.5, ...
                    'LineStyle',   '-', ...
                    'DisplayName', seriesLabels{sIdx});

                wireLineInteractivity(hLine);

                lineInfo         = struct();
                lineInfo.handle  = hLine;
                lineInfo.xName   = xName;
                lineInfo.yName   = yExpr;
                lineInfo.legend  = true;
                lineInfo.datatips = struct('dataIndex', {}, 'orientation', {});
                lineInfo.xData   = xFlat(:).';
                lineInfo.yData   = ySeries(:, sIdx).';
                lineInfo.gain    = 1;
                lineInfo.offset  = 0;
                lineInfo.color   = hLine.Color;
                lineInfo.lineStyle = hLine.LineStyle;
                lineInfo.lineWidth = hLine.LineWidth;
                lineInfo.displayName = hLine.DisplayName;

                set(hLine.Annotation.LegendInformation, 'IconDisplayStyle', 'on');

                subplotInfo.lines(end+1) = lineInfo; %#ok<AGROW>

                anyPlotted        = true;
                newLineHandles{end+1} = hLine; %#ok<AGROW>
            end
        end

        hold(targetAx, 'off');

        state.subplots(subplotIdx) = subplotInfo;

        applyLineTransformsForSubplot(subplotIdx);
        applyAxesConfig(subplotIdx);

        if ~anyPlotted
            % If nothing new was plotted, keep existing lines when
            % superposing, otherwise clear line list.
            if ~superpose || isempty(subplotInfo.lines)
                lbLines.Items = {};
                lbLines.Value = {};
                lbLines.ItemsData = {};
                updateLegend(targetAx);
            end
            return;
        end

        selectedHandle = [];
        if ~isempty(newLineHandles)
            selectedHandle = newLineHandles{1};
        end

        refreshLineListFromSubplot(selectedHandle);
        updateLegend(targetAx);
    end

    function idx = getSelectedLineIndex()
        % Return index of selected line in the active subplot, or 0 if none
        idx = 0;
        lines = getCurrentLines();
        if isempty(lines) || isempty(lbLines.ItemsData) || isempty(lbLines.Value)
            return;
        end

        selHandle = lbLines.Value;
        idx = find(arrayfun(@(ln) isequal(ln.handle, selHandle), lines), 1, 'first');
        if isempty(idx) || idx > numel(lines)
            idx = 0;
        end
    end

    function selectLineHandle(hLine)
        if isempty(hLine) || ~isvalid(hLine)
            return;
        end

        data = lbLines.ItemsData;
        if isempty(data)
            refreshLineListFromSubplot(hLine);
            data = lbLines.ItemsData;
        end

        if any(cellfun(@(h) isequal(h, hLine), data))
            lbLines.Value = hLine;
            syncStyleWithSelectedLine();
        end
    end

    function onLineSelectionChanged(~, ~)
        syncStyleWithSelectedLine();
    end

    function syncStyleWithSelectedLine()
        idx = getSelectedLineIndex();
        if idx == 0
            edtLineName.Value        = '';
            btnColor.BackgroundColor = [0 0.4470 0.7410];
            sldLineWidth.Value       = 1.5;
            edtLineWidth.Value       = 1.5;
            ddLineStyle.Value        = '-';
            chkLineLegend.Value      = true;
            edtLineGain.Value        = 1;
            edtLineOffset.Value      = 0;
            return;
        end

        lines = getCurrentLines();
        hLine = lines(idx).handle;
        if ~isvalid(hLine)
            return;
        end

        % Name from DisplayName
        edtLineName.Value = hLine.DisplayName;

        % Color to button background
        col = hLine.Color;
        if numel(col) >= 3
            btnColor.BackgroundColor = col(1:3);
        end

        % Width
        sldLineWidth.Value = hLine.LineWidth;
        edtLineWidth.Value = hLine.LineWidth;

        % Style
        ddLineStyle.Value = hLine.LineStyle;

        legendInfo = hLine.Annotation.LegendInformation;
        chkLineLegend.Value = strcmp(legendInfo.IconDisplayStyle, 'on');

        edtLineGain.Value   = lines(idx).gain;
        edtLineOffset.Value = lines(idx).offset;
    end

    function onLineNameChanged(~, ~)
        idx = getSelectedLineIndex();
        if idx == 0
            return;
        end
        lines = getCurrentLines();
        hLine = lines(idx).handle;
        if ~isvalid(hLine)
            return;
        end

        newName = edtLineName.Value;
        if isempty(newName)
            newName = lines(idx).yName;
        end
        hLine.DisplayName = newName;
        lines(idx).displayName = newName;

        items = lbLines.Items;
        if ischar(items)
            items = {items};
        end
        if idx <= numel(items)
            items{idx} = newName;
        end
        lbLines.Items = items;
        if numel(lbLines.ItemsData) >= idx
            lbLines.Value = lbLines.ItemsData{idx};
        end

        setCurrentLines(lines);
        updateLegend();
    end

    function onLineLegendToggled(~, ~)
        idx = getSelectedLineIndex();
        if idx == 0
            return;
        end

        lines = getCurrentLines();
        hLine = lines(idx).handle;
        if ~isvalid(hLine)
            return;
        end

        showLegend = chkLineLegend.Value;
        lines(idx).legend = showLegend;
        set(hLine.Annotation.LegendInformation, 'IconDisplayStyle', ternary(showLegend, 'on', 'off'));
        setCurrentLines(lines);

        updateLegend();
    end

    function onLineTransformChanged(~, ~)
        idx = getSelectedLineIndex();
        if idx == 0
            return;
        end

        lines = getCurrentLines();
        lines(idx).gain   = edtLineGain.Value;
        lines(idx).offset = edtLineOffset.Value;
        state.subplots(state.activeSubplot).lines = ensureLineDefaults(lines);

        applyLineTransformsForSubplot(state.activeSubplot);
        enforceLogSafetyAfterTransform();
    end

    function applyLineTransformsForSubplot(subplotIdx)
        if subplotIdx < 1 || subplotIdx > numel(state.subplots)
            return;
        end

        subplotInfo = ensureSubplotStruct(state.subplots(subplotIdx));
        for ln = 1:numel(subplotInfo.lines)
            subplotInfo.lines(ln) = ensureLineDefaults(subplotInfo.lines(ln));
            hLine = subplotInfo.lines(ln).handle;
            if isempty(hLine) || ~isvalid(hLine)
                continue;
            end
            if ~isempty(subplotInfo.lines(ln).xData)
                try
                    set(hLine, 'XData', subplotInfo.lines(ln).xData);
                catch
                end
            end

            yDisplay = getDisplayY(subplotInfo.lines(ln));
            try
                set(hLine, 'YData', yDisplay);
            catch
            end
        end

        state.subplots(subplotIdx) = subplotInfo;
    end

    function enforceLogSafetyAfterTransform()
        subplotIdx = state.activeSubplot;
        if subplotIdx < 1 || subplotIdx > numel(state.subplots)
            return;
        end

        subplotInfo = ensureSubplotStruct(state.subplots(subplotIdx));
        if strcmp(subplotInfo.yScale, 'log')
            data = gatherAxisData(subplotInfo, 'y');
            if any(~isfinite(data) | data <= 0)
                uialert(fig, ['Transformed Y data includes non-positive values; reverting Y axis to linear ', ...
                    'to keep the plot readable.'], 'Log scale reverted');
                subplotInfo.yScale = 'linear';
                state.subplots(subplotIdx) = subplotInfo;
                ddYScale.Value = 'linear';
                applyAxesConfig(subplotIdx);
                syncAxesControlsFromSubplot();
            end
        end
    end

    function applyTransformPreset(kind)
        switch kind
            case 'deg2rad'
                edtLineGain.Value   = pi / 180;
                edtLineOffset.Value = 0;
            case 'rad2deg'
                edtLineGain.Value   = 180 / pi;
                edtLineOffset.Value = 0;
            otherwise
                return;
        end
        onLineTransformChanged();
    end

    function onMoveLineBackward(~, ~)
        adjustLineOrder(-1);
    end

    function onMoveLineForward(~, ~)
        adjustLineOrder(1);
    end

    function adjustLineOrder(step)
        idx = getSelectedLineIndex();
        lines = getCurrentLines();
        if idx == 0 || isempty(lines)
            return;
        end

        newIdx = min(max(idx + step, 1), numel(lines));
        if newIdx == idx
            return;
        end

        hLine = lines(idx).handle;
        lines([idx, newIdx]) = lines([newIdx, idx]);
        setCurrentLines(lines);

        if isvalid(hLine)
            direction = ternary(step > 0, 'up', 'down');
            try
                uistack(hLine, direction, abs(newIdx - idx));
            catch
            end
        end

        refreshLineListFromSubplot(hLine);
        updateLegend();
    end

    function onRemoveLine(~, ~)
        subplotIdx = state.activeSubplot;
        if isempty(state.subplots) || subplotIdx < 1 || subplotIdx > numel(state.subplots)
            return;
        end

        lines = getCurrentLines();
        idx = getSelectedLineIndex();
        if idx == 0 || isempty(lines)
            return;
        end

        hLine = lines(idx).handle;
        if isvalid(hLine)
            delete(hLine);
        end

        lines(idx) = [];
        state.subplots(subplotIdx).lines = lines;

        nextHandle = [];
        if idx > 1 && idx-1 <= numel(lines)
            nextHandle = lines(idx-1).handle;
        elseif idx <= numel(lines)
            nextHandle = lines(idx).handle;
        end

        refreshLineListFromSubplot(nextHandle);
        updateLegend(state.subplots(subplotIdx).axes);
    end

    function out = ternary(cond, a, b)
        if cond
            out = a;
        else
            out = b;
        end
    end

    function onPickColor(~, ~)
        % Interactive color picker using uisetcolor
        idx = getSelectedLineIndex();
        lines = getCurrentLines();
        if idx ~= 0 && idx <= numel(lines) && isvalid(lines(idx).handle)
            initColor = lines(idx).handle.Color;
        else
            initColor = btnColor.BackgroundColor;
        end

        try
            newColor = uisetcolor(initColor, 'Select line color');
        catch
            newColor = initColor;
        end

        % Bring the plot menu figure back to the foreground
        try
            figure(fig);
        catch
        end

        if numel(newColor) ~= 3 || any(isnan(newColor))
            return;
        end

        btnColor.BackgroundColor = newColor;

        % Apply to selected line if any
        idx = getSelectedLineIndex();
        lines = getCurrentLines();
        if idx ~= 0
            hLine = lines(idx).handle;
            if isvalid(hLine)
                hLine.Color = newColor;
                lines(idx).color = newColor;
                setCurrentLines(lines);
            end
        end
    end

% onRGBChanged no longer used (kept for compatibility if needed)
% function onRGBChanged(~, ~)
% end

    function onWidthSliderChanged(~, ~)
        applyLineWidth(sldLineWidth.Value);
    end

    function onWidthEditChanged(~, ~)
        applyLineWidth(edtLineWidth.Value);
    end

    function applyLineWidth(widthValue)
        widthValue = max(min(widthValue, sldLineWidth.Limits(2)), sldLineWidth.Limits(1));
        sldLineWidth.Value = widthValue;
        edtLineWidth.Value = widthValue;

        idx = getSelectedLineIndex();
        if idx == 0
            return;
        end

        lines = getCurrentLines();
        hLine = lines(idx).handle;
        if ~isvalid(hLine)
            return;
        end
        hLine.LineWidth = widthValue;
        lines(idx).lineWidth = widthValue;
        setCurrentLines(lines);
    end

    function onStyleChanged(~, ~)
        idx = getSelectedLineIndex();
        if idx == 0
            return;
        end

        lines = getCurrentLines();
        hLine = lines(idx).handle;
        if ~isvalid(hLine)
            return;
        end

        hLine.LineStyle = ddLineStyle.Value;
        lines(idx).lineStyle = ddLineStyle.Value;
        setCurrentLines(lines);
    end

    function onAxesTextChanged(~, ~)
        if isempty(state.subplots) || state.activeSubplot < 1 || ...
                state.activeSubplot > numel(state.subplots)
            return;
        end

        targetAx = state.subplots(state.activeSubplot).axes;
        state.subplots(state.activeSubplot).titleText  = edtTitle.Value;
        state.subplots(state.activeSubplot).xLabelText = edtXLabel.Value;
        state.subplots(state.activeSubplot).yLabelText = edtYLabel.Value;

        if isempty(targetAx) || ~isvalid(targetAx)
            return;
        end

        title(targetAx,  edtTitle.Value);
        xlabel(targetAx, edtXLabel.Value);
        ylabel(targetAx, edtYLabel.Value);
    end

    function onAxisEqualToggled(~, ~)
        if isempty(state.subplots)
            return;
        end
        state.subplots(state.activeSubplot).axisEqual = chkAxisEqual.Value;
        applyAxesConfig(state.activeSubplot);
    end

    function onAxisScaleChanged(src, axisName)
        if isempty(state.subplots)
            return;
        end

        subplotIdx = state.activeSubplot;
        desired = src.Value;
        [ok, msg] = canUseLogScale(subplotIdx, axisName, desired);
        if ~ok
            uialert(fig, msg, 'Cannot apply log scale');
            src.Value = 'linear';
            desired = 'linear';
        end

        fieldName = ternary(axisName == 'x', 'xScale', 'yScale');
        state.subplots(subplotIdx).(fieldName) = desired;
        applyAxesConfig(subplotIdx);
        syncAxesControlsFromSubplot();
    end

    function onTickSpacingChanged(src, axisName)
        spacing = str2double(strtrim(src.Value));
        if isempty(src.Value) || isnan(spacing) || spacing <= 0
            spacing = [];
        end

        if axisName == 'x'
            state.subplots(state.activeSubplot).xTickSpacing = spacing;
        else
            state.subplots(state.activeSubplot).yTickSpacing = spacing;
        end

        src.Value = spacingToString(spacing);
        applyAxesConfig(state.activeSubplot);
    end

    function onResetTickSpacing(axisName)
        if axisName == 'x'
            state.subplots(state.activeSubplot).xTickSpacing = [];
            edtXTickSpacing.Value = '';
        else
            state.subplots(state.activeSubplot).yTickSpacing = [];
            edtYTickSpacing.Value = '';
        end
        applyAxesConfig(state.activeSubplot);
    end

    function syncAxesControlsFromSubplot()
        if isempty(state.subplots)
            return;
        end

        subplotInfo = ensureSubplotStruct(state.subplots(state.activeSubplot));
        chkAxisEqual.Value   = subplotInfo.axisEqual;
        ddXScale.Value       = subplotInfo.xScale;
        ddYScale.Value       = subplotInfo.yScale;
        edtXTickSpacing.Value = spacingToString(subplotInfo.xTickSpacing);
        edtYTickSpacing.Value = spacingToString(subplotInfo.yTickSpacing);
    end

    function out = spacingToString(val)
        if isempty(val) || ~isfinite(val) || val <= 0
            out = '';
            return;
        end
        out = char(string(val));
    end

    function onLegendChanged(~, ~)
        idx = state.activeSubplot;
        state.subplots(idx).legendVisible  = chkLegend.Value;
        state.subplots(idx).legendLocation = ddLegendLocation.Value;
        updateLegend(state.subplots(idx).axes);
    end

    function updateLegend(axHandle)
        if nargin < 1 || isempty(axHandle)
            if isempty(state.subplots) || state.activeSubplot < 1 || ...
                    state.activeSubplot > numel(state.subplots)
                return;
            end

            axHandle = state.subplots(state.activeSubplot).axes;
        end

        if ~isValidAxesHandle(axHandle)
            return;
        end

        subplotIdx = findSubplotIndex(axHandle);
        if subplotIdx == 0
            legend(axHandle, 'off');
            return;
        end

        subplotInfo = state.subplots(subplotIdx);
        lines = subplotInfo.lines;

        hasLegendLines = false;
        for k = 1:numel(lines)
            if isvalid(lines(k).handle) && strcmp(get(lines(k).handle.Annotation.LegendInformation, ...
                    'IconDisplayStyle'), 'on')
                hasLegendLines = true;
                break;
            end
        end

        if isempty(lines) || ~subplotInfo.legendVisible || ~hasLegendLines
            legend(axHandle, 'off');
            return;
        end

        lgd = legend(axHandle, 'show');
        if ~isempty(lgd) && isvalid(lgd)
            lgd.Location = subplotInfo.legendLocation;
            lgd.Visible  = 'on';
        end
    end

    function applyAxesConfig(subplotIdx)
        if subplotIdx < 1 || subplotIdx > numel(state.subplots)
            return;
        end

        subplotInfo = ensureSubplotStruct(state.subplots(subplotIdx));
        ax = subplotInfo.axes;
        if ~isValidAxesHandle(ax)
            return;
        end

        % Axis equality
        try
            if subplotInfo.axisEqual
                axis(ax, 'equal');
            else
                axis(ax, 'normal');
            end
        catch
        end

        % Positive limits before enabling log
        if strcmp(subplotInfo.xScale, 'log')
            posLim = computePositiveLimits(subplotIdx, 'x');
            if isempty(posLim)
                posLim = [1 10];
            end
            try
                xlim(ax, posLim);
            catch
            end
        end
        if strcmp(subplotInfo.yScale, 'log')
            posLim = computePositiveLimits(subplotIdx, 'y');
            if isempty(posLim)
                posLim = [1 10];
            end
            try
                ylim(ax, posLim);
            catch
            end
        end

        % Axis scales
        try
            set(ax, 'XScale', subplotInfo.xScale);
        catch
            subplotInfo.xScale = 'linear';
            set(ax, 'XScale', 'linear');
        end
        try
            set(ax, 'YScale', subplotInfo.yScale);
        catch
            subplotInfo.yScale = 'linear';
            set(ax, 'YScale', 'linear');
        end

        enforceTickSpacing(subplotIdx);
        state.subplots(subplotIdx) = subplotInfo;
    end

    function enforceTickSpacing(subplotIdx)
        if subplotIdx < 1 || subplotIdx > numel(state.subplots)
            return;
        end

        subplotInfo = ensureSubplotStruct(state.subplots(subplotIdx));
        ax = subplotInfo.axes;
        if ~isValidAxesHandle(ax)
            return;
        end

        applySpacing(subplotInfo.xTickSpacing, 'X');
        applySpacing(subplotInfo.yTickSpacing, 'Y');

        function applySpacing(spacing, axisPrefix)
            tickProp = [axisPrefix 'Tick'];
            modeProp = [tickProp 'Mode'];
            limProp  = [axisPrefix 'Lim'];

            if isempty(spacing) || ~isfinite(spacing) || spacing <= 0
                try
                    set(ax, modeProp, 'auto');
                catch
                end
                return;
            end

            try
                lims = get(ax, limProp);
            catch
                return;
            end
            if numel(lims) ~= 2 || any(~isfinite(lims))
                return;
            end

            ticks = lims(1):spacing:lims(2);
            scale = ternary(axisPrefix == 'X', subplotInfo.xScale, subplotInfo.yScale);
            if strcmp(scale, 'log')
                ticks = ticks(ticks > 0);
            end
            if numel(ticks) < 2
                try
                    set(ax, modeProp, 'auto');
                catch
                end
                return;
            end

            try
                set(ax, tickProp, ticks);
            catch
                try
                    set(ax, modeProp, 'auto');
                catch
                end
            end
        end
    end

    function lims = computePositiveLimits(subplotIdx, axisName)
        lims = [];
        if subplotIdx < 1 || subplotIdx > numel(state.subplots)
            return;
        end

        subplotInfo = ensureSubplotStruct(state.subplots(subplotIdx));
        data = gatherAxisData(subplotInfo, axisName);
        posData = data(isfinite(data) & data > 0);
        if isempty(posData)
            return;
        end

        lims = [min(posData), max(posData)];
        if lims(1) == lims(2)
            lims = lims .* [0.9 1.1];
        end
    end

    function data = gatherAxisData(subplotInfo, axisName)
        data = [];
        for ln = 1:numel(subplotInfo.lines)
            if strcmp(axisName, 'x')
                candidate = subplotInfo.lines(ln).xData;
            else
                candidate = getDisplayY(subplotInfo.lines(ln));
            end
            if isempty(candidate) || ~isnumeric(candidate)
                continue;
            end
            data = [data, candidate]; %#ok<AGROW>
        end
    end

    function yVals = getDisplayY(lineInfo)
        lineInfo = ensureLineDefaults(lineInfo);
        if numel(lineInfo) > 1
            yVals = cell2mat(arrayfun(@(ln) getDisplayY(ln), lineInfo, 'UniformOutput', false));
            return;
        end

        baseY = lineInfo.yData;
        if isempty(baseY) && isfield(lineInfo, 'handle') && isvalid(lineInfo.handle)
            baseY = safeGetLineData(lineInfo.handle, 'YData');
            lineInfo.yData = baseY;
        end
        if isempty(baseY)
            yVals = [];
            return;
        end
        yVals = lineInfo.gain .* baseY + lineInfo.offset;
    end

    function [ok, msg] = canUseLogScale(subplotIdx, axisName, desired)
        ok = true;
        msg = '';
        if nargin < 3
            desired = 'linear';
        end
        if strcmp(desired, 'linear')
            return;
        end

        if subplotIdx < 1 || subplotIdx > numel(state.subplots)
            return;
        end

        subplotInfo = ensureSubplotStruct(state.subplots(subplotIdx));
        for ln = 1:numel(subplotInfo.lines)
            if strcmp(axisName, 'x')
                data = subplotInfo.lines(ln).xData;
            else
                data = getDisplayY(subplotInfo.lines(ln));
            end
            if isempty(data)
                continue;
            end
            if ~isnumeric(data)
                ok = false;
                msg = 'Log scale requires numeric data.';
                return;
            end
            if any(~isfinite(data) | data <= 0)
                ok = false;
                msg = 'Log scale cannot be applied because data has non-positive values.';
                return;
            end
        end
    end

    function onAxesLimitsChanged(subplotIdx)
        if subplotIdx < 1 || subplotIdx > numel(state.subplots)
            return;
        end
        subplotInfo = ensureSubplotStruct(state.subplots(subplotIdx));
        if isValidAxesHandle(subplotInfo.axes)
            try
                subplotInfo.xLim = subplotInfo.axes.XLim;
                subplotInfo.yLim = subplotInfo.axes.YLim;
            catch
            end
            state.subplots(subplotIdx) = subplotInfo;
        end
        enforceTickSpacing(subplotIdx);
    end

    function attachLimitListeners(axHandle, subplotIdx)
        if subplotIdx < 1 || subplotIdx > numel(state.subplots)
            return;
        end

        subplotInfo = ensureSubplotStruct(state.subplots(subplotIdx));
        if ~isempty(subplotInfo.limitListeners)
            try
                delete(subplotInfo.limitListeners(isvalid(subplotInfo.limitListeners)));
            catch
            end
        end
        subplotInfo.limitListeners = event.listener.empty;

        if ~isValidAxesHandle(axHandle)
            state.subplots(subplotIdx) = subplotInfo;
            return;
        end

        try
            subplotInfo.limitListeners(end+1) = addlistener(axHandle, 'XLim', 'PostSet', @(~, ~) onAxesLimitsChanged(subplotIdx)); %#ok<AGROW>
        catch
        end
        try
            subplotInfo.limitListeners(end+1) = addlistener(axHandle, 'YLim', 'PostSet', @(~, ~) onAxesLimitsChanged(subplotIdx)); %#ok<AGROW>
        catch
        end

        state.subplots(subplotIdx) = subplotInfo;
    end

    function onAxesClicked(axHandle, ~)
        if ~isValidAxesHandle(axHandle)
            return;
        end

        idx = findSubplotIndex(axHandle);
        if idx ~= 0
            setActiveSubplot(idx);
        end
    end

    function onPlotElementClicked(graphObj, evt)
        if isempty(graphObj) || ~isvalid(graphObj)
            return;
        end

        axHandle = ancestor(graphObj, 'axes');
        if ~isValidAxesHandle(axHandle)
            return;
        end

        idx = findSubplotIndex(axHandle);
        if idx ~= 0
            setActiveSubplot(idx);
        end

        if isa(graphObj, 'matlab.graphics.chart.primitive.Line')
            selectLineHandle(graphObj);
            if state.datatipMode
                applyDatatip(graphObj, evt);
            end
        end
    end

    function applyDatatip(hLine, evt)
        if isempty(hLine) || ~isvalid(hLine)
            return;
        end

        dataIndex = resolveDatatipIndex(hLine, evt);

        dtHandle = [];
        tipOrientation = '';
        try
            if ~isempty(dataIndex)
                dtHandle = datatip(hLine, 'DataIndex', round(dataIndex));
            else
                dtHandle = datatip(hLine);
            end
        catch
        end

        if isempty(dataIndex) && ~isempty(dtHandle) && isvalid(dtHandle)
            try
                dataIndex = dtHandle.DataIndex;
            catch
            end
        end

        if ~isempty(dtHandle) && isvalid(dtHandle)
            try
                tipOrientation = dtHandle.Orientation;
            catch
            end
        end

        recordDatatipIndex(hLine, dataIndex, tipOrientation);
    end

    function idx = resolveDatatipIndex(hLine, evt)
        idx = [];

        xData = safeGetLineData(hLine, 'XData');
        yData = safeGetLineData(hLine, 'YData');
        if isempty(xData) || isempty(yData)
            return;
        end

        if ~isempty(evt)
            try
                idx = evt.DataIndex;
            catch
            end
            if isempty(idx)
                try
                    pos = evt.IntersectionPoint;
                catch
                    pos = [];
                end
                if numel(pos) >= 2
                    idx = findClosestIndex(xData, yData, pos(1), pos(2));
                end
            end
        end

        if isempty(idx)
            idx = 1;
        end
    end

    function recordDatatipIndex(hLine, dataIndex, orientation)
        if nargin < 3
            orientation = '';
        end
        if isempty(hLine) || ~isvalid(hLine) || isempty(dataIndex) || ~isfinite(dataIndex)
            return;
        end

        subplotIdx = findSubplotIndex(ancestor(hLine, 'axes'));
        if subplotIdx == 0 || subplotIdx > numel(state.subplots)
            return;
        end

        lines = state.subplots(subplotIdx).lines;
        lineIdx = find(arrayfun(@(ln) isequal(ln.handle, hLine), lines), 1);
        if isempty(lineIdx)
            return;
        end

        if ~isfield(lines(lineIdx), 'datatips') || isempty(lines(lineIdx).datatips)
            lines(lineIdx).datatips = struct('dataIndex', {}, 'orientation', {});
        end

        tips = lines(lineIdx).datatips;
        tips(end+1) = struct('dataIndex', round(dataIndex), 'orientation', orientation); %#ok<AGROW>
        lines(lineIdx).datatips = tips;
        state.subplots(subplotIdx).lines = lines;
    end

    function idx = findClosestIndex(xData, yData, xTarget, yTarget)
        idx = [];
        if isempty(xData) || isempty(yData)
            return;
        end
        try
            d = hypot(double(xData) - xTarget, double(yData) - yTarget);
            [~, idx] = min(d);
        catch
            idx = 1;
        end
    end

    function onDatatipModeToggled(src, ~)
        state.datatipMode = logical(src.Value);
        if state.datatipMode
            src.Text = 'Datatip mode (on)';
        else
            src.Text = 'Datatip mode (off)';
            syncDatatipsFromAxes(state.activeSubplot);
        end
    end

    function dtObjects = findDatatipObjects(axHandle)
        if nargin < 1 || ~isValidAxesHandle(axHandle)
            dtObjects = gobjects(0, 1);
            return;
        end

        figHandle = ancestor(axHandle, 'figure');
        searchRoot = axHandle;
        if ~isempty(figHandle) && isvalid(figHandle)
            searchRoot = figHandle;
        end

        dtByType  = findall(searchRoot, 'Type', 'datatip');
        dtByClass = findall(searchRoot, '-class', 'matlab.graphics.datatip.DataTip');
        dtByIndex = findall(searchRoot, '-property', 'DataIndex');
        dtObjects = unique([dtByType(:); dtByClass(:); dtByIndex(:)], 'stable');
        dtObjects = dtObjects(isgraphics(dtObjects));

        if isempty(dtObjects)
            dtObjects = gobjects(0, 1);
            return;
        end

        dtObjects = dtObjects(arrayfun(@(dt) isDatatipOnAxes(dt, axHandle), dtObjects));
    end

    function tgt = getTarget(dtObj)
        tgt = [];
        if isempty(dtObj) || ~isvalid(dtObj)
            return;
        end

        propNames = {'Target', 'DataSource', 'Host'};
        for pIdx = 1:numel(propNames)
            name = propNames{pIdx};
            if isprop(dtObj, name)
                try
                    candidate = dtObj.(name);
                    if ~isempty(candidate) && isgraphics(candidate)
                        tgt = candidate;
                        return;
                    end
                catch
                end
            end
        end

        try
            if isprop(dtObj, 'Parent') && isvalid(dtObj.Parent)
                parentObj = dtObj.Parent;
                if isprop(parentObj, 'Host') && ~isempty(parentObj.Host) && isgraphics(parentObj.Host)
                    tgt = parentObj.Host;
                    return;
                end
            end
        catch
        end

        tgt = ancestor(dtObj, 'matlab.graphics.chart.primitive.Line');
        if isempty(tgt) || ~isvalid(tgt)
            tgt = [];
        end
    end

    function tf = isDatatipOnAxes(dtObj, axHandle)
        tf = false;
        if isempty(dtObj) || ~isvalid(dtObj) || isempty(axHandle) || ~isvalid(axHandle)
            return;
        end

        tgt = getTarget(dtObj);
        if isempty(tgt) || ~isvalid(tgt)
            targetAxes = ancestor(dtObj, 'axes');
        else
            targetAxes = ancestor(tgt, 'axes');
        end

        tf = ~isempty(targetAxes) && isvalid(targetAxes) && isequal(targetAxes, axHandle);
    end

    function syncDatatipsFromAxes(subplotIdx)
        if subplotIdx < 1 || subplotIdx > numel(state.subplots)
            return;
        end

        subplotInfo = state.subplots(subplotIdx);
        axLocal = subplotInfo.axes;
        if ~isValidAxesHandle(axLocal)
            return;
        end

        for lnIdx = 1:numel(subplotInfo.lines)
            subplotInfo.lines(lnIdx).datatips = struct('dataIndex', {}, 'orientation', {});
        end

        dtObjects = findDatatipObjects(axLocal);
        for dt = dtObjects.'
            tgt = getTarget(dt);
            if isempty(tgt)
                continue;
            end

            lineIdx = find(arrayfun(@(ln) isequal(ln.handle, tgt), subplotInfo.lines), 1);
            if isempty(lineIdx)
                continue;
            end

            dataIndex = [];
            tipOrientation = '';
            try
                dataIndex = dt.DataIndex;
            catch
            end
            if isempty(dataIndex) || ~isfinite(dataIndex)
                continue;
            end
            if isprop(dt, 'Orientation')
                try
                    tipOrientation = dt.Orientation;
                catch
                end
            end

            subplotInfo.lines(lineIdx).datatips(end+1) = struct('dataIndex', dataIndex, 'orientation', tipOrientation); %#ok<AGROW>
        end

        state.subplots(subplotIdx) = subplotInfo;
    end

    function tips = normalizeDatatipsForExport(lineInfo)
        lineInfo = ensureLineDefaults(lineInfo);
        tips = lineInfo.datatips;
        if isempty(tips)
            tips = struct('dataIndex', {}, 'orientation', {});
            return;
        end

        validMask = arrayfun(@(t) isfield(t, 'dataIndex') && ~isempty(t.dataIndex) && isfinite(t.dataIndex), tips);
        tips = tips(validMask);

        for t = 1:numel(tips)
            if ~isfield(tips(t), 'orientation') || isempty(tips(t).orientation)
                tips(t).orientation = '';
            end
        end
    end

    function wireAxesInteractivity(axHandle)
        if ~isValidAxesHandle(axHandle)
            return;
        end

        axHandle.ButtonDownFcn = @(src, evt) onAxesClicked(src, evt);
        if isprop(axHandle, 'PickableParts')
            axHandle.PickableParts = 'all';
        end
    end

    function wireLineInteractivity(hLine)
        if isempty(hLine) || ~isvalid(hLine)
            return;
        end

        hLine.ButtonDownFcn = @(src, evt) onPlotElementClicked(src, evt);
        if isprop(hLine, 'PickableParts')
            hLine.PickableParts = 'all';
        end
    end

    function ensureLineInteractivity(lines)
        for ln = 1:numel(lines)
            wireLineInteractivity(lines(ln).handle);
        end
    end

    function idx = findSubplotIndex(axHandle)
        idx = 0;
        for n = 1:numel(state.subplots)
            if isequal(state.subplots(n).axes, axHandle)
                idx = n;
                return;
            end
        end
    end

    function lit = valueToLiteral(val)
        if isa(val, 'datetime')
            lit = sprintf('datetime(''%s'',''InputFormat'',''yyyy-MM-dd HH:mm:ss'')', ...
                datestr(val, 'yyyy-mm-dd HH:MM:SS'));
            return;
        end

        if isa(val, 'duration')
            lit = sprintf('seconds(%g)', seconds(val));
            return;
        end

        lit = mat2str(val);
    end

    function lit = arrayToLiteral(vals)
        if isscalar(vals)
            lit = valueToLiteral(vals);
            return;
        end

        if isa(vals, 'datetime')
            parts = arrayfun(@(d) sprintf('datetime(''%s'',''InputFormat'',''yyyy-MM-dd HH:mm:ss'')', ...
                datestr(d, 'yyyy-mm-dd HH:MM:SS')), vals, 'UniformOutput', false);
            lit = ['[', strjoin(parts, ' '), ']'];
            return;
        end

        if isa(vals, 'duration')
            parts = arrayfun(@(d) sprintf('seconds(%g)', seconds(d)), vals, 'UniformOutput', false);
            lit = ['[', strjoin(parts, ' '), ']'];
            return;
        end

        lit = mat2str(vals);
    end

    function syncLegendControlsFromSubplot(idx)
        subplotInfo = state.subplots(idx);
        chkLegend.Value = subplotInfo.legendVisible;

        if ismember(subplotInfo.legendLocation, ddLegendLocation.Items)
            ddLegendLocation.Value = subplotInfo.legendLocation;
        else
            ddLegendLocation.Value = 'best';
            subplotInfo.legendLocation = 'best';
            state.subplots(idx) = subplotInfo;
        end

        updateLegend(subplotInfo.axes);
    end

    function onExport(~, ~)
        if isempty(state.subplots)
            % Nothing to export, keep silent
            return;
        end

        hasAnyLines = false;
        for s = 1:numel(state.subplots)
            if ~isempty(state.subplots(s).lines)
                hasAnyLines = true;
                break;
            end
        end
        if ~hasAnyLines
            return;
        end

        codeLines = {};
        codeLines{end+1} = '% Auto-generated by plotMenuPrototype';
        codeLines{end+1} = sprintf('hFig = figure(''Name'',''Generated plot'', ''Color'', [1 1 1]);');
        codeLines{end+1} = sprintf('tiled = tiledlayout(hFig, %d, %d);', ...
            state.subplotRows, state.subplotCols);
        codeLines{end+1} = '';

        visibleCount = min(numel(state.subplots), state.subplotRows * state.subplotCols);
        for s = 1:visibleCount
            subplotInfo = state.subplots(s);
            if isempty(subplotInfo.lines)
                continue;
            end

            syncDatatipsFromAxes(s);
            subplotInfo = state.subplots(s);

            codeLines{end+1} = sprintf('ax = nexttile(tiled, %d); hold(ax,''on'');', s); %#ok<AGROW>

            lineVarNames = cell(1, numel(subplotInfo.lines));

            for k = 1:numel(subplotInfo.lines)
                info  = subplotInfo.lines(k);
                hLine = info.handle;

                lineVar = sprintf('hLine_%d_%d', s, k);
                lineVarNames{k} = lineVar;

                if isvalid(hLine)
                    lw  = hLine.LineWidth;
                    ls  = hLine.LineStyle;
                    col = hLine.Color;
                    dn  = hLine.DisplayName;
                else
                    lw  = info.lineWidth;
                    ls  = info.lineStyle;
                    col = info.color;
                    dn  = info.displayName;
                end
                dnEsc = strrep(dn, '''', '''''');

                yExpr = info.yName;
                if isfield(info, 'gain') && isfield(info, 'offset')
                    if info.gain ~= 1
                        yExpr = sprintf('(%g*(%s))', info.gain, yExpr);
                    end
                    if info.offset ~= 0
                        yExpr = sprintf('(%s + %g)', yExpr, info.offset);
                    end
                end

                lineCode = sprintf( ...
                    '%s = plot(ax, %s, %s, ''LineWidth'', %.3g, ''LineStyle'', ''%s'', ''Color'', [%.3g %.3g %.3g], ''DisplayName'', ''%s'');', ...
                    lineVar, ...
                    info.xName, yExpr, ...
                    lw, ls, ...
                    col(1), col(2), col(3), dnEsc);

                codeLines{end+1} = lineCode; %#ok<AGROW>
            end

            codeLines{end+1} = 'hold(ax,''off'');';

            % Axes title / labels
            axLocal = subplotInfo.axes;
            if ~isempty(axLocal.Title.String)
                tStr = axLocal.Title.String;
                tStr = strrep(tStr, '''', '''''');
                codeLines{end+1} = sprintf('title(ax, ''%s'');', tStr);
            end
            if ~isempty(axLocal.XLabel.String)
                xStr = axLocal.XLabel.String;
                xStr = strrep(xStr, '''', '''''');
                codeLines{end+1} = sprintf('xlabel(ax, ''%s'');', xStr);
            end
            if ~isempty(axLocal.YLabel.String)
                yStr = axLocal.YLabel.String;
                yStr = strrep(yStr, '''', '''''');
                codeLines{end+1} = sprintf('ylabel(ax, ''%s'');', yStr);
            end

            codeLines{end+1} = sprintf('xlim(ax, %s);', arrayToLiteral(axLocal.XLim));
            codeLines{end+1} = sprintf('ylim(ax, %s);', arrayToLiteral(axLocal.YLim));

            codeLines{end+1} = sprintf('set(ax, ''XScale'', ''%s'');', subplotInfo.xScale);
            codeLines{end+1} = sprintf('set(ax, ''YScale'', ''%s'');', subplotInfo.yScale);
            if subplotInfo.axisEqual
                codeLines{end+1} = 'axis(ax,''equal'');';
            else
                codeLines{end+1} = 'axis(ax,''normal'');';
            end
            if ~isempty(subplotInfo.xTickSpacing) && isfinite(subplotInfo.xTickSpacing) && subplotInfo.xTickSpacing > 0
                codeLines{end+1} = sprintf('set(ax, ''XTick'', %g:%g:%g);', ...
                    axLocal.XLim(1), subplotInfo.xTickSpacing, axLocal.XLim(2));
            end
            if ~isempty(subplotInfo.yTickSpacing) && isfinite(subplotInfo.yTickSpacing) && subplotInfo.yTickSpacing > 0
                codeLines{end+1} = sprintf('set(ax, ''YTick'', %g:%g:%g);', ...
                    axLocal.YLim(1), subplotInfo.yTickSpacing, axLocal.YLim(2));
            end

            legendable = arrayfun(@(ln) isvalid(ln.handle) && ...
                strcmp(get(ln.handle.Annotation.LegendInformation, 'IconDisplayStyle'), 'on'), ...
                subplotInfo.lines);
            if subplotInfo.legendVisible && any(legendable)
                codeLines{end+1} = sprintf( ...
                    'legend(ax, ''show'', ''Location'', ''%s'');', ...
                    subplotInfo.legendLocation);
            else
                codeLines{end+1} = 'legend(ax, ''off'');';
            end

            codeLines{end+1} = 'grid(ax,''on'');';

            for dtIdx = 1:numel(subplotInfo.lines)
                if dtIdx > numel(lineVarNames) || isempty(lineVarNames{dtIdx})
                    continue;
                end

                tipEntries = normalizeDatatipsForExport(subplotInfo.lines(dtIdx));
                if isempty(tipEntries)
                    continue;
                end

                for tipRow = 1:numel(tipEntries)
                    entry = tipEntries(tipRow);
                    orientationStr = '';
                    if isfield(entry, 'orientation') && ~isempty(entry.orientation)
                        orientationStr = strrep(char(string(entry.orientation)), '''', '''''');
                    end
                    if ~isfield(entry, 'dataIndex') || isempty(entry.dataIndex) || ~isfinite(entry.dataIndex)
                        continue;
                    end

                    dtCmd = sprintf('try, dTip = datatip(%s, ''DataIndex'', %d);', lineVarNames{dtIdx}, round(entry.dataIndex));
                    if ~isempty(orientationStr)
                        dtCmd = sprintf('%s if isprop(dTip,''Orientation''), dTip.Orientation = ''%s''; end;', dtCmd, orientationStr);
                    end
                    dtCmd = sprintf('%s catch, end', dtCmd);
                    codeLines{end+1} = dtCmd; %#ok<AGROW>
                end
            end

            codeLines{end+1} = '';
        end
        codeStr = strjoin(codeLines, newline);

        try
            clipboard('copy', codeStr);

            setStatus('graph generation code copied to clipboard', false);
        catch
            % In case of failure, remain silent to avoid intrusive dialogs
        end
    end
end

