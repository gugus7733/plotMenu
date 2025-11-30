function handleDataChanged(src, event)
    % src   : HTML component (uihtml)
    % event : event object with .Data field

    persistent backendState
    if isempty(backendState)
        backendState = struct( ...
            'workspaceMeta', [], ...
            'figure', [], ...
            'axes', [], ...
            'version', '0.2.0-preview');
    end

    incomingData = event.Data;

    fprintf('[plotMenu] DataChanged from HTML:\n');
    disp(incomingData);

    if ~isstruct(incomingData) || ~isfield(incomingData, 'type')
        fprintf('[plotMenu] Incoming data has no ''type'' field, ignoring.\n');
        return;
    end

    msgType = incomingData.type;
    if isfield(incomingData, 'payload')
        payload = incomingData.payload;
    else
        payload = [];
    end

    switch msgType
        case 'pingFromUI'
            src.Data = struct( ...
                'type',    'pongFromMatlab', ...
                'payload', struct('time', datestr(now)) );

        case 'uiReady'
            fprintf('[plotMenu] UI reported ready.\n');
            sendStatus(src, 'MATLAB backend connected.', 'info');
            backendState.workspaceMeta = getWorkspaceSnapshot();
            sendWorkspaceSnapshot(src, backendState.workspaceMeta);

        case 'requestWorkspaceSnapshot'
            backendState.workspaceMeta = getWorkspaceSnapshot();
            sendWorkspaceSnapshot(src, backendState.workspaceMeta);

        case 'requestYCandidates'
            yList = buildYCandidates(payload, backendState.workspaceMeta);
            src.Data = struct( ...
                'type', 'yCandidates', ...
                'payload', struct('items', yList, 'xName', getField(payload, 'xName', '')));

        case 'plotRequest'
            [result, backendState] = performPlotRequest(payload, backendState);
            src.Data = struct('type', 'plotUpdate', 'payload', result);

        case 'exportRequest'
            result = performExportRequest(payload);
            src.Data = struct('type', 'exportResult', 'payload', result);

        otherwise
            fprintf('[plotMenu] Unknown message type: %s\n', msgType);
            sendStatus(src, sprintf('Unknown message: %s', msgType), 'warn');
    end
end

%-------------------------------------------------------------------------%
function sendWorkspaceSnapshot(src, workspaceMeta)
    xCandidates = buildXCandidates(workspaceMeta);
    snapshotPayload = struct( ...
        'xCandidates', xCandidates, ...
        'generatedAt', datestr(now));

    src.Data = struct('type', 'workspaceSnapshot', 'payload', snapshotPayload);
end

function xCandidates = buildXCandidates(workspaceMeta)
    xCandidates = struct('name', {}, 'class', {}, 'size', {}, 'sizeString', {});
    if nargin < 1 || isempty(workspaceMeta)
        return;
    end

    validEntries = workspaceMeta([workspaceMeta.isValidXCandidate]);
    for k = 1:numel(validEntries)
        entry = validEntries(k);
        xCandidates(end+1) = struct( ... %#ok<AGROW>
            'name', entry.name, ...
            'class', entry.class, ...
            'size', entry.size, ...
            'sizeString', formatSize(entry.size));
    end
end

function yList = buildYCandidates(payload, workspaceMeta)
    yList = struct('label', {}, 'expression', {}, 'dimSizes', {});
    if nargin < 2 || isempty(workspaceMeta)
        workspaceMeta = getWorkspaceSnapshot();
    end

    xName = char(string(getField(payload, 'xName', '')));
    if isempty(xName)
        return;
    end

    try
        xVal = evalin('base', xName);
    catch ME
        fprintf('[plotMenu] Unable to evaluate X "%s": %s\n', xName, ME.message);
        return;
    end

    xLen = numel(xVal(:));
    if xLen < 2
        return;
    end

    for k = 1:numel(workspaceMeta)
        entry = workspaceMeta(k);
        try
            val = evalin('base', entry.name);
        catch
            continue;
        end

        kindLocal = classifyValueKind(val);
        switch kindLocal
            case 'array'
                [sampleDim, isCompat] = findSampleDim(size(val), xLen);
                if ~isCompat
                    continue;
                end
                orientedExpr = ensureColumnExpression(entry.name, size(val), xLen);
                yList(end+1) = struct( ... %#ok<AGROW>
                    'label', entry.name, ...
                    'expression', orientedExpr, ...
                    'dimSizes', size(val));

            case 'table'
                try
                    colNames = val.Properties.VariableNames;
                catch
                    colNames = {};
                end
                for c = 1:numel(colNames)
                    colName = colNames{c};
                    if isvarname(colName)
                        expr = sprintf('%s.%s', entry.name, colName);
                    else
                        expr = sprintf('%s.("%s")', entry.name, colName);
                    end
                    try
                        colVal = evalin('base', expr);
                    catch
                        continue;
                    end
                    [sampleDim, isCompat] = findSampleDim(size(colVal), xLen);
                    if ~isCompat || ~isSupportedArray(colVal)
                        continue;
                    end
                    orientedExpr = ensureColumnExpression(expr, size(colVal), xLen);
                    label = sprintf('%s · %s', entry.name, colName);
                    yList(end+1) = struct( ... %#ok<AGROW>
                        'label', label, ...
                        'expression', orientedExpr, ...
                        'dimSizes', size(colVal));
                end

            case 'struct'
                if numel(val) == 1
                    fields = fieldnames(val);
                    for fIdx = 1:numel(fields)
                        fname = fields{fIdx};
                        expr = sprintf('%s.%s', entry.name, fname);
                        try
                            fieldVal = evalin('base', expr);
                        catch
                            continue;
                        end
                        [sampleDim, isCompat] = findSampleDim(size(fieldVal), xLen);
                        if ~isCompat || ~isSupportedArray(fieldVal)
                            continue;
                        end
                        orientedExpr = ensureColumnExpression(expr, size(fieldVal), xLen);
                        label = sprintf('%s.%s', entry.name, fname);
                        yList(end+1) = struct( ... %#ok<AGROW>
                            'label', label, ...
                            'expression', orientedExpr, ...
                            'dimSizes', size(fieldVal));
                    end
                end
        end %#ok<*SWITCH>
    end
end

function [result, backendState] = performPlotRequest(payload, backendState)
    result = struct('status', 'error', 'message', 'Invalid request', 'lineCount', 0);

    if ~isstruct(payload) || ~isfield(payload, 'xName') || ~isfield(payload, 'yExpressions')
        result.message = 'Missing xName or yExpressions in request.';
        return;
    end

    xName = char(string(payload.xName));
    yExpressions = payload.yExpressions;
    if isstring(yExpressions)
        yExpressions = cellstr(yExpressions);
    end
    if ~iscell(yExpressions)
        yExpressions = {yExpressions};
    end
    options = getField(payload, 'options', struct());
    superpose = getField(options, 'superpose', true);
    showLegend = getField(options, 'legend', true);

    try
        xVal = evalin('base', xName);
    catch ME
        result.message = sprintf('Unable to evaluate X "%s": %s', xName, ME.message);
        return;
    end

    xData = xVal(:);
    xLen = numel(xData);
    if xLen < 2
        result.message = 'X must have at least two elements.';
        return;
    end

    series = struct('yData', {}, 'label', {});
    for idx = 1:numel(yExpressions)
        expr = yExpressions{idx};
        try
            yVal = evalin('base', expr);
        catch ME
            warning('plotMenu:plotRequest', 'Could not evaluate %s: %s', expr, ME.message);
            continue;
        end

        [sampleDim, isCompat] = findSampleDim(size(yVal), xLen);
        if ~isCompat
            warning('plotMenu:plotRequest', 'Expression %s not compatible with X length.', expr);
            continue;
        end

        [seriesData, labels] = reshapeSeriesForPlot(yVal, sampleDim, expr);
        for sIdx = 1:size(seriesData, 2)
            series(end+1) = struct( ... %#ok<AGROW>
                'yData', seriesData(:, sIdx), ...
                'label', labels{sIdx});
        end
    end

    if isempty(series)
        result.message = 'No compatible Y data to plot.';
        return;
    end

    [ax, backendState] = getOrCreateAxes(backendState);
    if ~superpose
        cla(ax);
    end
    hold(ax, 'on');

    for sIdx = 1:numel(series)
        plot(ax, xData, series(sIdx).yData, 'DisplayName', series(sIdx).label);
    end

    if showLegend && numel(series) > 1
        legend(ax, 'show');
    end
    if ~superpose
        hold(ax, 'off');
    end

    result.status = 'ok';
    result.lineCount = numel(series);
    result.message = sprintf('Plotted %d line(s) from %d Y input(s).', numel(series), numel(yExpressions));
end

function result = performExportRequest(payload)
    result = struct('status', 'error', 'message', 'Invalid export request');

    if ~isstruct(payload) || ~isfield(payload, 'xName') || ~isfield(payload, 'yExpressions')
        result.message = 'Missing xName or yExpressions for export.';
        return;
    end

    xName = char(string(payload.xName));
    yExpressions = payload.yExpressions;
    if isstring(yExpressions)
        yExpressions = cellstr(yExpressions);
    end
    if ~iscell(yExpressions)
        yExpressions = {yExpressions};
    end
    options = getField(payload, 'options', struct());
    superpose = getField(options, 'superpose', true);
    showLegend = getField(options, 'legend', true);

    lines = {
        '% PlotMenu web export snippet', ...
        '% Recreate the last plotted selection', ...
        sprintf('x = %s;', xName)
        };

    for idx = 1:numel(yExpressions)
        lines{end+1} = sprintf('y%d = %s;', idx, yExpressions{idx}); %#ok<AGROW>
    end

    if superpose
        lines{end+1} = 'figure; hold on;'; %#ok<AGROW>
    else
        lines{end+1} = 'figure;'; %#ok<AGROW>
    end

    for idx = 1:numel(yExpressions)
        lines{end+1} = sprintf('plot(x, y%d);', idx); %#ok<AGROW>
    end

    if superpose
        lines{end+1} = 'hold off;'; %#ok<AGROW>
    end

    if showLegend && numel(yExpressions) > 1
        lines{end+1} = 'legend show;'; %#ok<AGROW>
    end

    codeStr = strjoin(lines, newline);

    try
        clipboard('copy', codeStr);
        result.status = 'ok';
        result.message = 'Exported code copied to clipboard.';
    catch ME
        warning('plotMenu:export', 'Clipboard copy failed: %s', ME.message);
        result.status = 'ok';
        result.message = 'Export generated. Clipboard copy may have failed.';
    end
end

%-------------------------------------------------------------------------%
function status = sendStatus(src, text, level)
    if nargin < 3
        level = 'info';
    end
    status = struct('type', 'statusMessage', 'payload', struct('level', level, 'text', text));
    src.Data = status;
end

function val = getField(s, name, defaultVal)
    val = defaultVal;
    if isstruct(s) && isfield(s, name)
        val = s.(name);
    end
end

function meta = getWorkspaceSnapshot()
    vars = evalin('base', 'whos');
    meta = struct('name', {}, 'class', {}, 'size', {}, 'isSupportedArray', {}, 'numel', {}, ...
        'isIntegerScalar', {}, 'kind', {}, 'scalarValue', {}, 'isNumeric', {}, 'isValidXCandidate', {});

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

function tf = isSupportedArray(val)
    tf = isnumeric(val) || islogical(val) || isdatetime(val) || isduration(val);
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

function txt = formatSize(sz)
    if isempty(sz)
        txt = '';
        return;
    end
    txt = strjoin(string(sz), 'x');
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

function expr = ensureColumnExpression(expr, dimSizes, targetLen)
    if nargin < 2
        dimSizes = [];
    end
    if nargin < 3
        targetLen = [];
    end

    if isempty(targetLen) || isempty(dimSizes)
        return;
    end

    [sampleDim, isCompat] = findSampleDim(dimSizes, targetLen);
    if ~isCompat || sampleDim == 1
        return;
    end

    expr = sprintf('(%s)''', char(string(expr)));
end

function [seriesData, labels] = reshapeSeriesForPlot(yVal, sampleDim, baseLabel)
    order = [sampleDim, setdiff(1:ndims(yVal), sampleDim)];
    yReordered = permute(yVal, order);
    seriesData = reshape(yReordered, size(yReordered, 1), []);

    if size(seriesData, 2) <= 1
        labels = {baseLabel};
        return;
    end

    labels = cell(1, size(seriesData, 2));
    for idx = 1:size(seriesData, 2)
        labels{idx} = sprintf('%s [%d]', baseLabel, idx);
    end
end

function [ax, backendState] = getOrCreateAxes(backendState)
    ax = [];
    if ~isfield(backendState, 'figure') || isempty(backendState.figure) || ~ishghandle(backendState.figure)
        backendState.figure = figure('Name', 'PlotMenu Web Plots', 'NumberTitle', 'off');
    end

    if ~isfield(backendState, 'axes') || isempty(backendState.axes) || ~ishghandle(backendState.axes)
        backendState.axes = axes('Parent', backendState.figure);
    end

    ax = backendState.axes;
end
