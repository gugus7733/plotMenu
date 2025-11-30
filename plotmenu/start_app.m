function start_app()
    % Determine repo root from this file location
    thisFileFullPath = mfilename('fullpath');
    thisFolder       = fileparts(thisFileFullPath);
    repoRoot         = fileparts(thisFolder);

    webFolder        = fullfile(repoRoot, 'web');
    htmlFile         = fullfile(webFolder, 'index.html');

    if ~isfile(htmlFile)
        error('plotMenu:MissingHTML', ...
              'Could not find web front-end at %s', htmlFile);
    end

    % Main figure and top-level grid to mirror the desktop layout
    mainFigure = uifigure( ...
        'Name',        'Plot Menu (Web UI)', ...
        'Position',    [100 100 1250 820], ...
        'Color',       [0.11 0.12 0.13], ...
        'Resize',      'on', ...
        'CloseRequestFcn', @localCloseRequest );

    outerGrid = uigridlayout(mainFigure, [2 3]);
    outerGrid.RowHeight     = {'1x', 180};
    outerGrid.ColumnWidth   = {340, '1x', 320};
    outerGrid.ColumnSpacing = 12;
    outerGrid.RowSpacing    = 12;
    outerGrid.Padding       = [12 12 12 12];

    % Left panel: HTML-based controls for workspace browsing and plotting
    htmlComponent = uihtml( ...
        outerGrid, ...
        'HTMLSource',     htmlFile, ...
        'DataChangedFcn', @handleDataChanged );
    htmlComponent.Layout.Row    = 1;
    htmlComponent.Layout.Column = 1;

    % Bottom-left strip: layout chooser and subplot selection controls
    layoutPanel = uipanel(outerGrid, ...
        'Title',           'Plot & Layout', ...
        'BackgroundColor', [0.11 0.12 0.13], ...
        'ForegroundColor', [0.94 0.94 0.94]);
    layoutPanel.Layout.Row    = 2;
    layoutPanel.Layout.Column = 1;

    layoutGrid = uigridlayout(layoutPanel, [2 2]);
    layoutGrid.RowHeight     = {'fit', 'fit'};
    layoutGrid.ColumnWidth   = {'1x', '1x'};
    layoutGrid.Padding       = [10 8 10 10];
    layoutGrid.RowSpacing    = 8;
    layoutGrid.ColumnSpacing = 8;

    uilabel(layoutGrid, ...
        'Text', 'Layout', ...
        'FontWeight', 'bold', ...
        'HorizontalAlignment', 'left', ...
        'FontColor', [0.94 0.94 0.94]);

    layoutDropdown = uidropdown(layoutGrid, ...
        'Items', {'1 x 1', '1 x 2', '2 x 1', '2 x 2'}, ...
        'Value', '1 x 1');
    layoutDropdown.Layout.Row    = 1;
    layoutDropdown.Layout.Column = 2;

    uilabel(layoutGrid, ...
        'Text', 'Target subplot', ...
        'HorizontalAlignment', 'left', ...
        'FontWeight', 'bold', ...
        'FontColor', [0.94 0.94 0.94]);

    subplotDropdown = uidropdown(layoutGrid, ...
        'Items', {'Subplot 1'}, ...
        'Value', 'Subplot 1');
    subplotDropdown.Layout.Row    = 2;
    subplotDropdown.Layout.Column = 2;

    % Central plot canvas hosting the UIAxes grid
    plotPanel = uipanel(outerGrid, ...
        'Title',           'Plot Area', ...
        'BackgroundColor', [0.16 0.17 0.18], ...
        'ForegroundColor', [0.94 0.94 0.94]);
    plotPanel.Layout.Row    = [1 2];
    plotPanel.Layout.Column = 2;

    plotGrid = uigridlayout(plotPanel, [1 1]);
    plotGrid.RowHeight     = {'1x'};
    plotGrid.ColumnWidth   = {'1x'};
    plotGrid.Padding       = [10 8 10 10];
    plotGrid.RowSpacing    = 8;
    plotGrid.ColumnSpacing = 8;

    % Right panel reserved for line, axes, and export controls
    rightPanel = uipanel(outerGrid, ...
        'Title',           'Lines & Axes (preview)', ...
        'BackgroundColor', [0.13 0.14 0.15], ...
        'ForegroundColor', [0.94 0.94 0.94]);
    rightPanel.Layout.Row    = [1 2];
    rightPanel.Layout.Column = 3;

    rightGrid = uigridlayout(rightPanel, [3 1]);
    rightGrid.RowHeight     = {'fit', 'fit', '1x'};
    rightGrid.ColumnWidth   = {'1x'};
    rightGrid.Padding       = [10 8 10 10];
    rightGrid.RowSpacing    = 10;

    uilabel(rightGrid, 'Text', 'Line list (coming soon)', ...
        'FontWeight', 'bold', ...
        'HorizontalAlignment', 'left', ...
        'FontColor', [0.94 0.94 0.94]);
    uilabel(rightGrid, 'Text', 'Axes & export controls will be added here.', ...
        'HorizontalAlignment', 'left', ...
        'FontColor', [0.82 0.82 0.82]);

    % Build initial axes grid and store UI state for the backend callbacks
    uiState = buildAxesGrid(plotGrid, [1 1]);
    uiState.layoutDropdown  = layoutDropdown;
    uiState.subplotDropdown = subplotDropdown;
    refreshAxesTitles();
    updateSubplotDropdown();
    storeUIState();

    layoutDropdown.ValueChangedFcn = @(src, evt) changeLayout(src.Value);
    subplotDropdown.ValueChangedFcn = @(src, evt) selectSubplot(src.Value);

    % Initial message to the web UI
    initialPayload = struct( ...
        'appName',       'PlotMenu', ...
        'version',       '0.2.0-preview', ...
        'timestamp',     datestr(now), ...
        'matlabVersion', version );

    htmlComponent.Data = struct( ...
        'type',    'initFromMatlab', ...
        'payload', initialPayload );

    %---------------- nested helpers --------------------------------------
    function uiStateOut = buildAxesGrid(parentGrid, layoutSize)
        if nargin < 2
            layoutSize = [1 1];
        end

        delete(parentGrid.Children);

        parentGrid.RowHeight   = repmat({'1x'}, 1, layoutSize(1));
        parentGrid.ColumnWidth = repmat({'1x'}, 1, layoutSize(2));

        axesHandles = gobjects(1, prod(layoutSize));
        idx = 1;
        for r = 1:layoutSize(1)
            for c = 1:layoutSize(2)
                ax = uiaxes(parentGrid);
                ax.Layout.Row    = r;
                ax.Layout.Column = c;
                styleAxes(ax);
                ax.ButtonDownFcn = @(axObj, ~) setActiveAxes(axObj); %#ok<NASGU>
                axesHandles(idx) = ax;
                idx = idx + 1;
            end
        end

        uiStateOut = struct( ...
            'axesHandles',    axesHandles, ...
            'activeAxes',     axesHandles(1), ...
            'activeIndex',    1, ...
            'layoutSize',     layoutSize, ...
            'plotGrid',       parentGrid, ...
            'layoutDropdown', [], ...
            'subplotDropdown', []); %#ok<STRNU>
    end

    function styleAxes(ax)
        ax.BackgroundColor = [1 1 1];
        ax.GridColor       = [0.6 0.6 0.6];
        ax.XColor          = [0.2 0.2 0.2];
        ax.YColor          = [0.2 0.2 0.2];
        ax.Box             = 'on';
    end

    function storeUIState()
        setappdata(htmlComponent, 'PlotMenuUIState', uiState);
        setappdata(mainFigure,    'PlotMenuUIState', uiState);
    end

    function refreshAxesTitles()
        pullStateFromAppdata();
        if ~isfield(uiState, 'axesHandles') || isempty(uiState.axesHandles)
            return;
        end
        for idxLocal = 1:numel(uiState.axesHandles)
            ax = uiState.axesHandles(idxLocal);
            if ~isgraphics(ax)
                continue;
            end
            ax.Title.String     = sprintf('Subplot %d', idxLocal);
            ax.Title.FontWeight = 'normal';
            if idxLocal == uiState.activeIndex
                ax.Title.String     = sprintf('Subplot %d (active)', idxLocal);
                ax.Title.FontWeight = 'bold';
            end
        end
    end

    function updateSubplotDropdown()
        pullStateFromAppdata();
        if ~isgraphics(subplotDropdown)
            return;
        end
        labels = arrayfun(@(k) sprintf('Subplot %d', k), 1:numel(uiState.axesHandles), ...
            'UniformOutput', false);
        subplotDropdown.Items = labels;
        activeLabel = sprintf('Subplot %d', uiState.activeIndex);
        if any(strcmp(subplotDropdown.Items, activeLabel))
            subplotDropdown.Value = activeLabel;
        end
    end

    function changeLayout(label)
        pullStateFromAppdata();
        dims = sscanf(label, '%d x %d');
        if numel(dims) ~= 2
            return;
        end
        uiState.layoutSize = dims(:)';
        uiState = buildAxesGrid(plotGrid, uiState.layoutSize);
        uiState.layoutDropdown  = layoutDropdown;
        uiState.subplotDropdown = subplotDropdown;
        uiState.activeIndex     = min(uiState.activeIndex, numel(uiState.axesHandles));
        uiState.activeAxes      = uiState.axesHandles(uiState.activeIndex);
        refreshAxesTitles();
        updateSubplotDropdown();
        storeUIState();
    end

    function selectSubplot(label)
        pullStateFromAppdata();
        token = regexp(label, '(\d+)$', 'tokens', 'once');
        if isempty(token)
            return;
        end
        idxLocal = str2double(token{1});
        if isnan(idxLocal) || idxLocal < 1 || idxLocal > numel(uiState.axesHandles)
            return;
        end
        uiState.activeIndex = idxLocal;
        uiState.activeAxes  = uiState.axesHandles(idxLocal);
        refreshAxesTitles();
        updateSubplotDropdown();
        storeUIState();
    end

    function setActiveAxes(axHandle)
        pullStateFromAppdata();
        matchIdx = find(uiState.axesHandles == axHandle, 1);
        if isempty(matchIdx)
            return;
        end
        uiState.activeIndex = matchIdx;
        uiState.activeAxes  = axHandle;
        refreshAxesTitles();
        updateSubplotDropdown();
        storeUIState();
    end

    function pullStateFromAppdata()
        stored = getappdata(htmlComponent, 'PlotMenuUIState');
        if ~isempty(stored)
            uiState = stored;
        end
    end

    function localCloseRequest(figHandle, ~)
        delete(figHandle);
    end
end
