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

    % Main figure
    mainFigure = uifigure( ...
        'Name',        'Plot Menu (Web UI)', ...
        'Position',    [100 100 1200 800], ...
        'Color',       [0.11 0.12 0.13], ...
        'Resize',      'on', ...
        'CloseRequestFcn', @localCloseRequest );

    % HTML component – ONLY Data/DataChangedFcn for R2022a
    htmlComponent = uihtml( ...
        mainFigure, ...
        'HTMLSource',     htmlFile, ...
        'Position',       [0 0 mainFigure.Position(3:4)], ...
        'DataChangedFcn', @handleDataChanged );

    % Resize behavior
    mainFigure.SizeChangedFcn = @(src, ~) localResizeHtml(src, htmlComponent);

    % Initial message to the web UI
    initialPayload = struct( ...
        'appName',  'PlotMenu', ...
        'version',  '0.1.0', ...
        'timestamp', datestr(now) );

    htmlComponent.Data = struct( ...
        'type',    'initFromMatlab', ...
        'payload', initialPayload );

    %---------------- nested helpers --------------------------------------
    function localResizeHtml(figHandle, htmlHandle)
        figPosition         = figHandle.Position;
        htmlHandle.Position = [0 0 figPosition(3) figPosition(4)];
    end

    function localCloseRequest(figHandle, ~)
        delete(figHandle);
    end
end
