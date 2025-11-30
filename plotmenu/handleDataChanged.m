function handleDataChanged(src, event)
    % src   : HTML component (uihtml)
    % event : event object with .Data field

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
            % Simple ping/pong demo
            src.Data = struct( ...
                'type',    'pongFromMatlab', ...
                'payload', struct('time', datestr(now)) );

        case 'uiReady'
            % UI reports it is ready
            fprintf('[plotMenu] UI reported ready.\n');

            src.Data = struct( ...
                'type', 'statusMessage', ...
                'payload', struct( ...
                    'level', 'info', ...
                    'text',  'MATLAB backend connected.' ) );

        otherwise
            fprintf('[plotMenu] Unknown message type: %s\n', msgType);
    end
end
