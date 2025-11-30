function handleHtmlEvent(src, event)
    % src   : HTML component
    % event : MATLAB event object with fields:
    %         - EventName
    %         - Data
    
    fprintf('[plotMenu] Event from HTML:\n');
    fprintf('  Name: %s\n', event.EventName);
    fprintf('  Data:\n');
    disp(event.Data);
    
    % Skeleton for future routing:
    % switch event.EventName
    %     case 'uiReady'
    %         % UI has completed its initial mounting
    %     case 'pingFromUI'
    %         % Example: respond back
    %         src.Data = struct('type', 'pongFromMatlab', ...
    %                           'payload', struct('time', datestr(now)));
    %     otherwise
    %         fprintf('[plotMenu] Unknown HTML event: %s\n', event.EventName);
    % end
end
