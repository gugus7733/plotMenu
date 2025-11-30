function start_app()
    % Determine repo root from this file location:
    %
    % This file lives in: <repo_root>/+plotmenu/start_app.m
    % So the repo root is one level up from the parent folder.
    thisFileFullPath = mfilename('fullpath');
    packageFolder    = fileparts(thisFileFullPath);
    repoRoot         = fileparts(packageFolder);
    
    % Path to the web front-end (index.html).
    webFolder        = fullfile(repoRoot, 'web');
    htmlFile         = fullfile(webFolder, 'index.html');
    
    if ~isfile(htmlFile)
        error('plotMenu:MissingHTML', ...
              'Could not find web front-end at %s', htmlFile);
    end
    
    % Create main UI figure.
    mainFigure = uifigure( ...
        'Name',        'Plot Menu (Web UI)', ...
        'Position',    [100 100 1200 800], ...
        'Color',       [0.11 0.12 0.13], ...
        'Resize',      'on', ...
        'CloseRequestFcn', @localCloseRequest );
    
    % Create the HTML component.
    htmlComponent = uihtml( ...
        mainFigure, ...
        'HTMLSource',          htmlFile, ...
        'Position',            [0 0 mainFigure.Position(3:4)], ...
        'DataChangedFcn',      @plotmenu.handleDataChanged, ...
        'HTMLEventReceivedFcn', @plotmenu.handleHtmlEvent );
    
    % Make HTML fill the figure when resized.
    mainFigure.SizeChangedFcn = @(src, ~) localResizeHtml(src, htmlComponent);
    
    % Initial message to the web UI so Codex can later react to it.
    initialPayload = struct( ...
        'appName',  'PlotMenu', ...
        'version',  '0.1.0', ...
        'timestamp', datestr(now) );
    
    htmlComponent.Data = struct( ...
        'type',    'initFromMatlab', ...
        'payload', initialPayload );
    
    
    %----------------------------------------------------------------------
    % Nested helper: resize html component with the figure
    %----------------------------------------------------------------------
    function localResizeHtml(figHandle, htmlHandle)
        figPosition      = figHandle.Position;
        htmlHandle.Position = [0 0 figPosition(3) figPosition(4)];
    end

    %----------------------------------------------------------------------
    % Nested helper: clean shutdown
    %----------------------------------------------------------------------
    function localCloseRequest(figHandle, ~)
        % Place here any cleanup logic for backend if needed later.
        delete(figHandle);
    end
end