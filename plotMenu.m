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

% Shared state across nested callbacks
state         = struct();
statusTimer   = [];
state.subplots = struct('axes',{},'lines',{},'superpose',{},'legendVisible',{},'legendLocation',{});
state.subplotRows = 1;
state.subplotCols = 1;
state.activeSubplot = 1;

%% Create main UI
fig = uifigure( ...
    'Name',     'Plot Menu', ...
    'Position', [100 100 1400 800], ...
    'Color',    [1 1 1]);

mainLayout = uigridlayout(fig, [1 3]);
mainLayout.ColumnWidth = {'1x', '2x', '1x'};

%% Left panel: data selection
leftPanel  = uipanel(mainLayout, 'Title', 'Data selection', 'BackgroundColor', [1 1 1], ...
    'Scrollable', 'on');
leftPanel.Layout.Row    = 1;
leftPanel.Layout.Column = 1;

leftLayout = uigridlayout(leftPanel, [11 1]);
leftLayout.RowHeight = {'fit', 'fit', 'fit', 'fit', 'fit', 'fit', '1x', 'fit', 'fit', 'fit', 'fit'};

subplotPanel = uipanel(leftLayout, 'Title', 'Subplots', 'BackgroundColor', [1 1 1]);
subplotPanel.Layout.Row    = 1;
subplotPanel.Layout.Column = 1;

subplotLayout = uigridlayout(subplotPanel, [2 1]);
subplotLayout.RowHeight   = {'fit', '1x'};
subplotLayout.BackgroundColor = [1 1 1];

defaultLayoutRowHeights = {'fit', '1x'};
hiddenLayoutRowHeights  = defaultLayoutRowHeights;
hiddenLayoutRowHeights{2} = 0;

subplotLayout.RowHeight = hiddenLayoutRowHeights;

btnLayoutMenu = uibutton(subplotLayout, ...
    'Text', 'Choose layout', ...
    'ButtonPushedFcn', @onLayoutMenuPressed);
btnLayoutMenu.Layout.Row    = 1;
btnLayoutMenu.Layout.Column = 1;

tblLayout = uitable(subplotLayout, ...
    'Data', strings(5), ...
    'RowName', {}, ...
    'ColumnName', {}, ...
    'Multiselect', 'off', ...
    'CellSelectionCallback', @onLayoutCellSelected, ...
    'ColumnWidth', num2cell(repmat(26, 1, 5)));
tblLayout.Layout.Row    = 2;
tblLayout.Layout.Column = 1;
tblLayout.Visible       = 'off';
tblLayout.Enable        = 'off';

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
    'Value', '');
ddXVar.Layout.Row    = 4;
ddXVar.Layout.Column = 1;

lblYVar = uilabel(leftLayout, 'Text', 'Y variable(s):');
lblYVar.Layout.Row    = 5;
lblYVar.Layout.Column = 1;

lbYVar = uilistbox(leftLayout, ...
    'Items',      {}, ...
    'Multiselect','on');
lbYVar.Layout.Row    = 6;
lbYVar.Layout.Column = 1;

btnPlot = uibutton(leftLayout, ...
    'Text',          'Plot selected', ...
    'ButtonPushedFcn', @onPlot);
btnPlot.Layout.Row    = 11;
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

lineLayout = uigridlayout(linePanel, [9 3]);
lineLayout.RowHeight   = {20, 40, 20, 30, 30, 30, 30, 30, '1x'};
lineLayout.ColumnWidth = {80, '1x', 70};

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

sldLineWidth = uislider(lineLayout, ...
    'Limits', [0.1 10], ...
    'MajorTicks', [], ...
    'MinorTicks', [], ...
    'Value', 1.5, ...
    'ValueChangedFcn', @onWidthSliderChanged, ...
    'ValueChangingFcn', @(~, evt) applyLineWidth(evt.Value));
sldLineWidth.Layout.Row    = 5;
sldLineWidth.Layout.Column = 2;

edtLineWidth = uieditfield(lineLayout, 'numeric', ...
    'Limits', [0.1 10], ...
    'Value', 1.5, ...
    'ValueChangedFcn', @onWidthEditChanged);
edtLineWidth.Layout.Row    = 5;
edtLineWidth.Layout.Column = 3;

lblStyle = uilabel(lineLayout, 'Text', 'Line style:');
lblStyle.Layout.Row    = 6;
lblStyle.Layout.Column = 1;

ddLineStyle = uidropdown(lineLayout, ...
    'Items', {'-', '--', ':', '-.'}, ...
    'Value', '-', ...
    'ValueChangedFcn', @onStyleChanged);
ddLineStyle.Layout.Row    = 6;
ddLineStyle.Layout.Column = 2;

chkLineLegend = uicheckbox(lineLayout, ...
    'Text', 'Show in legend', ...
    'Value', true, ...
    'ValueChangedFcn', @onLineLegendToggled);
chkLineLegend.Layout.Row    = 7;
chkLineLegend.Layout.Column = [1 3];

btnRemoveLine = uibutton(lineLayout, ...
    'Text', 'Remove selected line', ...
    'ButtonPushedFcn', @onRemoveLine);
btnRemoveLine.Layout.Row    = 8;
btnRemoveLine.Layout.Column = [1 3];

% --- Axes properties panel ---
axesPanel = uipanel(rightLayout, 'Title', 'Axes properties', 'BackgroundColor', [1 1 1], ...
    'Scrollable', 'on');
axesPanel.Layout.Row    = 2;
axesPanel.Layout.Column = 1;

axesLayout = uigridlayout(axesPanel, [9 2]);
axesLayout.RowHeight   = {20, 30, 20, 30, 20, 30, 30, 30, '1x'};
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

lblActiveSubplot = uilabel(axesLayout, ...
    'Text', 'Active subplot: (1,1)');
lblActiveSubplot.Layout.Row    = 6;
lblActiveSubplot.Layout.Column = [1 2];

chkSubplotSuperpose = uicheckbox(axesLayout, ...
    'Text',  'Superpose in subplot', ...
    'Value', false, ...
    'ValueChangedFcn', @onSubplotSuperposeChanged);
chkSubplotSuperpose.Layout.Row    = 7;
chkSubplotSuperpose.Layout.Column = [1 2];

btnClear = uibutton(axesLayout, ...
    'Text',          'Clear selected subplot', ...
    'ButtonPushedFcn', @onClearPlot);
btnClear.Layout.Row    = 8;
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
            'lines',          struct('handle',{},'xName',{},'yName',{},'legend',{},'datatips',{}), ...
            'superpose',      false, ...
            'legendVisible',  true, ...
            'legendLocation', 'best');
        newSubplots = repmat(defaultSubplot, 1, newCount);

        for idx = 1:newCount
            rIdx = ceil(idx / cols);
            cIdx = mod(idx-1, cols) + 1;

            if idx <= numel(oldSubplots) && isfield(oldSubplots(idx), 'axes') && ...
                    isvalid(oldSubplots(idx).axes)
                axLocal = oldSubplots(idx).axes;
                axLocal.Layout.Row    = rIdx;
                axLocal.Layout.Column = cIdx;
                newSubplots(idx) = oldSubplots(idx);
            else
                axLocal = uiaxes(centerLayout);
                axLocal.Layout.Row    = rIdx;
                axLocal.Layout.Column = cIdx;
                grid(axLocal, 'on');
                title(axLocal, '');
                xlabel(axLocal, '');
                ylabel(axLocal, '');
                axLocal.Color = [1 1 1];

                newSubplots(idx).axes           = axLocal;
                newSubplots(idx).superpose      = false;
                newSubplots(idx).legendVisible  = true;
                newSubplots(idx).legendLocation = ddLegendLocation.Value;
            end

            wireAxesInteractivity(axLocal);
            ensureLineInteractivity(newSubplots(idx).lines);

            % Ensure line structs carry legend flag
            for ln = 1:numel(newSubplots(idx).lines)
                if ~isfield(newSubplots(idx).lines(ln), 'legend')
                    newSubplots(idx).lines(ln).legend = true;
                end
                if ~isfield(newSubplots(idx).lines(ln), 'datatips')
                    newSubplots(idx).lines(ln).datatips = zeros(0, 2);
                end
            end
        end

        for idx = newCount+1:numel(oldSubplots)
            if isfield(oldSubplots(idx), 'axes') && isvalid(oldSubplots(idx).axes)
                delete(oldSubplots(idx).axes);
            end
        end

        state.subplots     = newSubplots;
        state.subplotRows  = rows;
        state.subplotCols  = cols;
        state.activeSubplot = min(state.activeSubplot, newCount);

        setActiveSubplot(state.activeSubplot);
    end

    function setActiveSubplot(idx)
        if idx < 1 || idx > numel(state.subplots)
            return;
        end

        state.activeSubplot = idx;
        ax = state.subplots(idx).axes;

        wireAxesInteractivity(ax);
        ensureLineInteractivity(state.subplots(idx).lines);

        rowIdx = ceil(idx / state.subplotCols);
        colIdx = mod(idx-1, state.subplotCols) + 1;
        lblActiveSubplot.Text = sprintf('Active subplot: (%d,%d)', rowIdx, colIdx);

        chkSubplotSuperpose.Value = state.subplots(idx).superpose;

        syncLegendControlsFromSubplot(idx);
        refreshLineListFromSubplot();

        % Sync axes text fields with the selected subplot
        edtTitle.Value  = ax.Title.String;
        edtXLabel.Value = ax.XLabel.String;
        edtYLabel.Value = ax.YLabel.String;
    end

    function lines = getCurrentLines()
        if isempty(state.subplots)
            lines = struct('handle',{},'xName',{},'yName',{},'legend',{});
            return;
        end
        lines = state.subplots(state.activeSubplot).lines;
    end

    function setCurrentLines(lines)
        state.subplots(state.activeSubplot).lines = lines;
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

    function onLayoutMenuPressed(~, ~)
        setLayoutMenuVisibility(true);
    end

    function onLayoutCellSelected(~, event)
        if isempty(event.Indices)
            return;
        end

        rows = event.Indices(1);
        cols = event.Indices(2);

        applySubplotGrid(rows, cols);

        newIdx = sub2ind([state.subplotRows, state.subplotCols], rows, cols);
        setActiveSubplot(newIdx);

        setLayoutMenuVisibility(false);
    end

    function setLayoutMenuVisibility(showTable)
        if showTable
            tblLayout.Visible = 'on';
            tblLayout.Enable  = 'on';
            rowHeights = defaultLayoutRowHeights;
        else
            tblLayout.Visible = 'off';
            tblLayout.Enable  = 'off';
            rowHeights = hiddenLayoutRowHeights;
        end

        subplotLayout.RowHeight = rowHeights;
    end

    function onSubplotSuperposeChanged(~, ~)
        state.subplots(state.activeSubplot).superpose = chkSubplotSuperpose.Value;
    end

    function clearSubplot(idx)
        if idx < 1 || idx > numel(state.subplots)
            return;
        end

        subplotInfo = state.subplots(idx);
        if isfield(subplotInfo, 'axes') && isvalid(subplotInfo.axes)
            cla(subplotInfo.axes);
        end

        subplotInfo.lines = struct('handle',{},'xName',{},'yName',{},'legend',{},'datatips',{});
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
            hLine = plot(targetAx, xFlat, yFlat, ...
                'LineWidth',   1.5, ...
                'LineStyle',   '-', ...
                'DisplayName', yName);

            wireLineInteractivity(hLine);

            lineInfo         = struct();
            lineInfo.handle  = hLine;
            lineInfo.xName   = xName;
            lineInfo.yName   = yName;
            lineInfo.legend  = true;
            lineInfo.datatips = zeros(0, 2);

            set(hLine.Annotation.LegendInformation, 'IconDisplayStyle', 'on');

            subplotInfo.lines(end+1) = lineInfo; %#ok<AGROW>

            anyPlotted        = true;
            newLineHandles{end+1} = hLine; %#ok<AGROW>
        end

        hold(targetAx, 'off');

        state.subplots(subplotIdx) = subplotInfo;

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
    end

    function onAxesTextChanged(~, ~)
        if isempty(state.subplots) || state.activeSubplot < 1 || ...
                state.activeSubplot > numel(state.subplots)
            return;
        end

        targetAx = state.subplots(state.activeSubplot).axes;
        if isempty(targetAx) || ~isvalid(targetAx)
            return;
        end

        title(targetAx,  edtTitle.Value);
        xlabel(targetAx, edtXLabel.Value);
        ylabel(targetAx, edtYLabel.Value);
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

        if isempty(axHandle) || ~isvalid(axHandle)
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

    function onAxesClicked(axHandle, ~)
        if isempty(axHandle) || ~isvalid(axHandle)
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
        if isempty(axHandle) || ~isvalid(axHandle)
            return;
        end

        idx = findSubplotIndex(axHandle);
        if idx ~= 0
            setActiveSubplot(idx);
        end

        if isa(graphObj, 'matlab.graphics.chart.primitive.Line')
            selectLineHandle(graphObj);
            applyDatatip(graphObj, evt);
        end
    end

    function applyDatatip(hLine, evt)
        if isempty(hLine) || ~isvalid(hLine)
            return;
        end

        tipPos = [];
        try
            tipPos = evt.IntersectionPoint;
        catch
        end

        dtHandle = [];
        try
            if ~isempty(tipPos) && numel(tipPos) >= 2
                dtHandle = datatip(hLine, tipPos(1), tipPos(2));
            else
                dtHandle = datatip(hLine);
            end
        catch
        end

        try
            if ~isempty(dtHandle) && isvalid(dtHandle)
                recordDatatipPosition(hLine, dtHandle.Position);
            elseif ~isempty(tipPos)
                recordDatatipPosition(hLine, tipPos);
            end
        catch
        end
    end

    function recordDatatipPosition(hLine, pos)
        if isempty(hLine) || ~isvalid(hLine) || numel(pos) < 2
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
            lines(lineIdx).datatips = zeros(0, 2);
        end

        pos = pos(:).';
        lines(lineIdx).datatips(end+1, 1:2) = pos(1:2);
        state.subplots(subplotIdx).lines = lines;
    end

    function tgt = getTarget(dtObj)
        tgt = [];
        if isempty(dtObj) || ~isvalid(dtObj)
            return;
        end

        if isprop(dtObj, 'DataSource') && ~isempty(dtObj.DataSource)
            tgt = dtObj.DataSource;
            return;
        end

        if isprop(dtObj, 'Target') && ~isempty(dtObj.Target)
            tgt = dtObj.Target;
        end
    end

    function wireAxesInteractivity(axHandle)
        if isempty(axHandle) || ~isvalid(axHandle)
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

        for s = 1:numel(state.subplots)
            subplotInfo = state.subplots(s);
            if isempty(subplotInfo.lines)
                continue;
            end

            codeLines{end+1} = sprintf('ax = nexttile(tiled, %d); hold(ax,''on'');', s); %#ok<AGROW>

            lineVarNames = cell(1, numel(subplotInfo.lines));

            for k = 1:numel(subplotInfo.lines)
                info  = subplotInfo.lines(k);
                hLine = info.handle;
                if ~isvalid(hLine)
                    continue;
                end

                lineVar = sprintf('hLine_%d_%d', s, k);
                lineVarNames{k} = lineVar;

                lw  = hLine.LineWidth;
                ls  = hLine.LineStyle;
                col = hLine.Color;
                dn  = hLine.DisplayName;
                dnEsc = strrep(dn, '''', '''''');

                lineCode = sprintf( ...
                    '%s = plot(ax, %s, %s, ''LineWidth'', %.3g, ''LineStyle'', ''%s'', ''Color'', [%.3g %.3g %.3g], ''DisplayName'', ''%s'');', ...
                    lineVar, ...
                    info.xName, info.yName, ...
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

                dtPositions = [];
                if isfield(subplotInfo.lines(dtIdx), 'datatips')
                    dtPositions = subplotInfo.lines(dtIdx).datatips;
                end
                if isempty(dtPositions)
                    dtObjects = findall(axLocal, '-class', 'matlab.graphics.datatip.DataTip');
                    targetHandle = subplotInfo.lines(dtIdx).handle;
                    dtPositions = cell2mat(arrayfun(@(dt) reshape(dt.Position(1, 1:2), 1, 2), ...
                        dtObjects(arrayfun(@(dt) isequal(getTarget(dt), targetHandle), dtObjects)), ...
                        'UniformOutput', false).');
                    subplotInfo.lines(dtIdx).datatips = dtPositions;
                    state.subplots(s) = subplotInfo;
                end
                if isempty(dtPositions)
                    continue;
                end

                for tipRow = 1:size(dtPositions, 1)
                    pos = dtPositions(tipRow, :);
                    if numel(pos) < 2
                        continue;
                    end

                    xTip = valueToLiteral(pos(1));
                    yTip = valueToLiteral(pos(2));
                    codeLines{end+1} = sprintf('datatip(%s, %s, %s);', lineVarNames{dtIdx}, xTip, yTip); %#ok<AGROW>
                end
            end

            codeLines{end+1} = '';
        end
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
end

