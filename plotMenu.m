function plotMenuPrototype
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

% Shared state across nested callbacks
state         = struct();
statusTimer   = [];
state.lines   = struct('handle',{},'xName',{},'yName',{});  % line info: handle, xName, yName

%% Create main UI
fig = uifigure( ...
    'Name',     'Plot Menu Prototype', ...
    'Position', [100 100 1400 800]);

mainLayout = uigridlayout(fig, [1 3]);
mainLayout.ColumnWidth = {280, '1x', 320};

%% Left panel: data selection
leftPanel  = uipanel(mainLayout, 'Title', 'Data selection');
leftPanel.Layout.Row    = 1;
leftPanel.Layout.Column = 1;

leftLayout = uigridlayout(leftPanel, [8 1]);
leftLayout.RowHeight = {30, 20, 30, 20, '1x', 30, 20, 30};

btnRefresh = uibutton(leftLayout, ...
    'Text',          'Refresh workspace variables', ...
    'ButtonPushedFcn', @onRefreshWorkspace);
btnRefresh.Layout.Row    = 1;
btnRefresh.Layout.Column = 1;

lblXVar = uilabel(leftLayout, 'Text', 'X variable:');
lblXVar.Layout.Row    = 2;
lblXVar.Layout.Column = 1;

ddXVar = uidropdown(leftLayout, ...
    'Items', {''}, ...
    'Value', '');
ddXVar.Layout.Row    = 3;
ddXVar.Layout.Column = 1;

lblYVar = uilabel(leftLayout, 'Text', 'Y variable(s):');
lblYVar.Layout.Row    = 4;
lblYVar.Layout.Column = 1;

lbYVar = uilistbox(leftLayout, ...
    'Items',      {}, ...
    'Multiselect','on');
lbYVar.Layout.Row    = 5;
lbYVar.Layout.Column = 1;

btnClear = uibutton(leftLayout, ...
    'Text',          'Clear plot', ...
    'ButtonPushedFcn', @onClearPlot);
btnClear.Layout.Row    = 6;
btnClear.Layout.Column = 1;

chkSuperpose = uicheckbox(leftLayout, ...
    'Text',  'Superpose', ...
    'Value', false);
chkSuperpose.Layout.Row    = 7;
chkSuperpose.Layout.Column = 1;

btnPlot = uibutton(leftLayout, ...
    'Text',          'Plot selected', ...
    'ButtonPushedFcn', @onPlot);
btnPlot.Layout.Row    = 8;
btnPlot.Layout.Column = 1;

%% Center panel: axes
centerPanel  = uipanel(mainLayout, 'Title', 'Plot');
centerPanel.Layout.Row    = 1;
centerPanel.Layout.Column = 2;

centerLayout = uigridlayout(centerPanel, [1 1]);
centerLayout.RowHeight   = {'1x'};
centerLayout.ColumnWidth = {'1x'};

ax = uiaxes(centerLayout);
ax.Layout.Row    = 1;
ax.Layout.Column = 1;
grid(ax, 'on');
title(ax, '');
xlabel(ax, '');
ylabel(ax, '');

%% Right panel: line style, axes properties, export
rightPanel  = uipanel(mainLayout, 'Title', 'Style / Export');
rightPanel.Layout.Row    = 1;
rightPanel.Layout.Column = 3;

rightLayout = uigridlayout(rightPanel, [3 1]);
rightLayout.RowHeight = {240, 240, 40};

% Bottom panel: export button + status label
bottomPanel = uipanel(rightLayout, 'BorderType', 'none');
bottomPanel.Layout.Row    = 3;
bottomPanel.Layout.Column = 1;

bottomLayout = uigridlayout(bottomPanel, [1 1]);
bottomLayout.ColumnWidth = {'1x'};

% --- Line style panel ---
linePanel = uipanel(rightLayout, 'Title', 'Line properties');
linePanel.Layout.Row    = 1;
linePanel.Layout.Column = 1;

lineLayout = uigridlayout(linePanel, [8 2]);
lineLayout.RowHeight   = {20, 40, 20, 30, 20, 30, 20, '1x'};
lineLayout.ColumnWidth = {80, '1x'};

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

% Color controls: single clickable color bar
lblColor = uilabel(lineLayout, 'Text', 'Color:');
lblColor.Layout.Row    = 4;
lblColor.Layout.Column = 1;

btnColor = uibutton(lineLayout, ...
    'Text', '', ...
    'BackgroundColor', [0 0.4470 0.7410], ...
    'ButtonPushedFcn', @onPickColor);
btnColor.Layout.Row    = 4;
btnColor.Layout.Column = 2;

lblWidth = uilabel(lineLayout, 'Text', 'Line width:');
lblWidth.Layout.Row    = 5;
lblWidth.Layout.Column = 1;

spLineWidth = uispinner(lineLayout, ...
    'Limits', [0.1 10], ...
    'Step',  0.1, ...
    'Value', 1.5, ...
    'ValueChangedFcn', @onWidthChanged);
spLineWidth.Layout.Row    = 5;
spLineWidth.Layout.Column = 2;

lblStyle = uilabel(lineLayout, 'Text', 'Line style:');
lblStyle.Layout.Row    = 6;
lblStyle.Layout.Column = 1;

ddLineStyle = uidropdown(lineLayout, ...
    'Items', {'-', '--', ':', '-.'}, ...
    'Value', '-', ...
    'ValueChangedFcn', @onStyleChanged);
ddLineStyle.Layout.Row    = 6;
ddLineStyle.Layout.Column = 2;

lblDummy = uilabel(lineLayout, 'Text', '');
lblDummy.Layout.Row    = 7;
lblDummy.Layout.Column = [1 2];

% --- Axes properties panel ---
axesPanel = uipanel(rightLayout, 'Title', 'Axes properties');
axesPanel.Layout.Row    = 2;
axesPanel.Layout.Column = 1;

axesLayout = uigridlayout(axesPanel, [7 2]);
axesLayout.RowHeight   = {20, 30, 20, 30, 20, 30, 30};
axesLayout.ColumnWidth = {80, '1x'};

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

%% Initialize workspace variables in dropdowns/listbox
refreshWorkspaceControls();

%% --- Nested helper and callback functions ---

    function onRefreshWorkspace(~, ~)
        refreshWorkspaceControls();
    end

    function refreshWorkspaceControls()
        % Find valid variables in base workspace:
        % numeric, logical, datetime, duration arrays.
        vars       = evalin('base', 'whos');
        validNames = {};

        for k = 1:numel(vars)
            name = vars(k).name;
            try
                val = evalin('base', name);
                if isSupportedArray(val)
                    validNames{end+1} = name; %#ok<AGROW>
                end
            catch
                % Ignore variables that cannot be evaluated
            end
        end

        if isempty(validNames)
            ddXVar.Items   = {'<no valid arrays>'};
            ddXVar.Value   = '<no valid arrays>';
            ddXVar.Enable  = 'off';

            lbYVar.Items   = {};
            lbYVar.Value   = {};
            lbYVar.Enable  = 'off';

            btnPlot.Enable = 'off';
        else
            ddXVar.Items = ['<select X>', validNames];
            if ~ismember(ddXVar.Value, ddXVar.Items)
                ddXVar.Value = '<select X>';
            end
            ddXVar.Enable = 'on';

            lbYVar.Items  = validNames;
            lbYVar.Value  = {};
            lbYVar.Enable = 'on';

            btnPlot.Enable = 'on';
        end
    end

    function tf = isSupportedArray(val)
        tf = isnumeric(val) || islogical(val) || ...
            isdatetime(val) || isduration(val);
    end

    function onClearPlot(~, ~)
        % Clear axes and line state
        cla(ax);
        state.lines   = struct('handle',{},'xName',{},'yName',{});
        lbLines.Items = {};
        lbLines.Value = {};
        updateLegend();

        % Reset style controls
        edtLineName.Value        = '';
        btnColor.BackgroundColor = [0 0.4470 0.7410];
        spLineWidth.Value        = 1.5;
        ddLineStyle.Value        = '-';
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
        if ischar(ySelection)
            ySelection = {ySelection};
        end
        if isempty(ySelection)
            uialert(fig, 'Please select at least one Y variable.', ...
                'Missing Y variable');
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
        if ~isSupportedArray(xVal)
            uialert(fig, 'X variable must be numeric, logical, datetime or duration array.', ...
                'Invalid X variable');
            return;
        end

        xFlat = xVal(:);

        superpose = chkSuperpose.Value;

        % Clear previous lines only if not superposing
        if ~superpose
            cla(ax);
            state.lines = struct('handle',{},'xName',{},'yName',{});
        end

        hold(ax, 'on');

        anyPlotted   = false;
        newLineItems = {};

        % Existing line names when superposing
        existingItems = {};
        if superpose && ~isempty(lbLines.Items)
            existingItems = lbLines.Items;
            if ischar(existingItems)
                existingItems = {existingItems};
            end
        end

        for k = 1:numel(ySelection)
            yName = ySelection{k};
            try
                yVal = evalin('base', yName);
            catch ME
                uialert(fig, sprintf('Cannot evaluate Y variable "%s":\n%s', ...
                    yName, ME.message), 'Error evaluating Y');
                continue;
            end
            if ~isSupportedArray(yVal)
                uialert(fig, sprintf('Y variable "%s" is not a supported array type.', yName), ...
                    'Invalid Y variable');
                continue;
            end

            yFlat = yVal(:);
            if numel(xFlat) ~= numel(yFlat)
                uialert(fig, sprintf( ...
                    'X (%s) and Y (%s) have different number of elements (%d vs %d). Skipping "%s".', ...
                    xName, yName, numel(xFlat), numel(yFlat), yName), ...
                    'Size mismatch');
                continue;
            end

            % Plot with default style
            hLine = plot(ax, xFlat, yFlat, ...
                'LineWidth',   1.5, ...
                'LineStyle',   '-', ...
                'DisplayName', yName);

            lineInfo         = struct();
            lineInfo.handle  = hLine;
            lineInfo.xName   = xName;
            lineInfo.yName   = yName;
            state.lines(end+1) = lineInfo; %#ok<AGROW>

            anyPlotted      = true;
            newLineItems{end+1} = yName; %#ok<AGROW>
        end

        hold(ax, 'off');

        if ~anyPlotted
            % If nothing new was plotted, keep existing lines when
            % superposing, otherwise clear line list.
            if ~superpose || isempty(state.lines)
                lbLines.Items = {};
                lbLines.Value = {};
                updateLegend();
            end
            return;
        end

        % Combine existing and new line names
        allItems = newLineItems;
        if ~isempty(existingItems)
            allItems = [existingItems, newLineItems];
        end

        lbLines.Items = allItems;
        if ~isempty(newLineItems)
            lbLines.Value = newLineItems{1};
        elseif ~isempty(allItems)
            lbLines.Value = allItems{1};
        else
            lbLines.Value = {};
        end

        syncStyleWithSelectedLine();
        updateLegend();
    end

    function idx = getSelectedLineIndex()
        % Return index of selected line in state.lines, or 0 if none
        idx = 0;
        if isempty(state.lines) || isempty(lbLines.Items) || isempty(lbLines.Value)
            return;
        end
        selValue = lbLines.Value;
        allItems = lbLines.Items;
        if ischar(allItems)
            allItems = {allItems};
        end
        idx = find(strcmp(selValue, allItems), 1, 'first');
        if isempty(idx) || idx > numel(state.lines)
            idx = 0;
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
            spLineWidth.Value        = 1.5;
            ddLineStyle.Value        = '-';
            return;
        end

        hLine = state.lines(idx).handle;
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
        spLineWidth.Value = hLine.LineWidth;

        % Style
        ddLineStyle.Value = hLine.LineStyle;
    end

    function onLineNameChanged(~, ~)
idx = getSelectedLineIndex();
if idx == 0
    return;
end
hLine = state.lines(idx).handle;
if ~isvalid(hLine)
    return;
end

newName = edtLineName.Value;
if isempty(newName)
    newName = state.lines(idx).yName;
end
hLine.DisplayName = newName;

items = lbLines.Items;
if ischar(items)
    items = {items};
end
if idx <= numel(items)
    items{idx} = newName;
end
lbLines.Items = items;
lbLines.Value = newName;

updateLegend();
end

function onPickColor(~, ~)
% Interactive color picker using uisetcolor
idx = getSelectedLineIndex();
if idx ~= 0 && isvalid(state.lines(idx).handle)
    initColor = state.lines(idx).handle.Color;
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
if idx ~= 0
    hLine = state.lines(idx).handle;
    if isvalid(hLine)
        hLine.Color = newColor;
    end
end
end

% onRGBChanged no longer used (kept for compatibility if needed)
% function onRGBChanged(~, ~)
% end

function onWidthChanged(~, ~)
    idx = getSelectedLineIndex();
    if idx == 0
        return;
    end
    hLine = state.lines(idx).handle;
    if ~isvalid(hLine)
        return;
    end
    hLine.LineWidth = spLineWidth.Value;
end
hLine = state.lines(idx).handle;
if ~isvalid(hLine)
    return;
end
hLine.Color = [spR.Value, spG.Value, spB.Value];
end

function onStyleChanged(~, ~)
idx = getSelectedLineIndex();
if idx == 0
    return;
end
hLine = state.lines(idx).handle;
if ~isvalid(hLine)
    return;
end
hLine.LineStyle = ddLineStyle.Value;
end

function onAxesTextChanged(~, ~)
title(ax,  edtTitle.Value);
xlabel(ax, edtXLabel.Value);
ylabel(ax, edtYLabel.Value);
end

function onLegendChanged(~, ~)
updateLegend();
end

function updateLegend()
if isempty(state.lines)
    legend(ax, 'off');
    return;
end

if chkLegend.Value
    % Ensure a legend exists, then update its properties
    lgd = legend(ax);
    if ~isempty(lgd) && isvalid(lgd)
        lgd.Location = ddLegendLocation.Value;
        lgd.Visible  = 'on';
    end
else
    legend(ax, 'off');
end
end

function onExport(~, ~)
if isempty(state.lines)
    % Nothing to export, keep silent
    return;
end

codeLines = {};
codeLines{end+1} = '% Auto-generated by plotMenuPrototype';
codeLines{end+1} = 'hFig = figure(''Name'',''Generated plot'');';
codeLines{end+1} = 'ax  = axes(''Parent'', hFig);';
codeLines{end+1} = 'hold(ax,''on'');';
codeLines{end+1} = '';

for k = 1:numel(state.lines)
    info  = state.lines(k);
    hLine = info.handle;
    if ~isvalid(hLine)
        continue;
    end

    lw  = hLine.LineWidth;
    ls  = hLine.LineStyle;
    col = hLine.Color;
    dn  = hLine.DisplayName;
    dnEsc = strrep(dn, '''', '''''');

    lineCode = sprintf( ...
        'plot(ax, %s, %s, ''LineWidth'', %.3g, ''LineStyle'', ''%s'', ''Color'', [%.3g %.3g %.3g], ''DisplayName'', ''%s'');', ...
        info.xName, info.yName, ...
        lw, ls, ...
        col(1), col(2), col(3), dnEsc);

    codeLines{end+1} = lineCode; %#ok<AGROW>
end

codeLines{end+1} = 'hold(ax,''off'');';

% Axes title / labels
if ~isempty(ax.Title.String)
    tStr = ax.Title.String;
    tStr = strrep(tStr, '''', '''''');
    codeLines{end+1} = sprintf('title(ax, ''%s'');', tStr);
end
if ~isempty(ax.XLabel.String)
    xStr = ax.XLabel.String;
    xStr = strrep(xStr, '''', '''''');
    codeLines{end+1} = sprintf('xlabel(ax, ''%s'');', xStr);
end
if ~isempty(ax.YLabel.String)
    yStr = ax.YLabel.String;
    yStr = strrep(yStr, '''', '''''');
    codeLines{end+1} = sprintf('ylabel(ax, ''%s'');', yStr);
end

% Legend
if chkLegend.Value && ~isempty(state.lines)
    codeLines{end+1} = sprintf( ...
        'legend(ax, ''show'', ''Location'', ''%s'');', ...
        ddLegendLocation.Value);
else
    codeLines{end+1} = 'legend(ax, ''off'');';
end

codeLines{end+1} = '';
codeLines{end+1} = 'grid(ax,''on'');';

codeStr = strjoin(codeLines, newline);

try
    clipboard('copy', codeStr);

    % Show transient status text as a bottom-centered popup
    lblStatus.Text = 'graph generation code copied to clipboard';

    figPos      = fig.Position;
    toastWidth  = 320;
    toastHeight = 24;
    lblStatus.Position = [ (figPos(3) - toastWidth) / 2, ...
        10, ...
        toastWidth, ...
        toastHeight ];
    lblStatus.Visible = 'on';

    if ~isempty(statusTimer) && isvalid(statusTimer)
        stop(statusTimer);
        delete(statusTimer);
    end

    statusTimer = timer( ...
        'StartDelay',    2, ...
        'ExecutionMode', 'singleShot', ...
        'TimerFcn',      @(~, ~) set(lblStatus, 'Visible', 'off'));
    start(statusTimer);
catch
    % In case of failure, remain silent to avoid intrusive dialogs
end
end

