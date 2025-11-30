function handleDataChanged(src, event)
    % src   : HTML component
    % event : MATLAB event object with .Data field
    
    incomingData = event.Data;
    
    % For now, just log to the Command Window.
    fprintf('[plotMenu] DataChanged from HTML:\n');
    disp(incomingData);
    
    % Example of how you might branch later:
    % if isstruct(incomingData) && isfield(incomingData, 'type')
    %     switch incomingData.type
    %         case 'plotRequest'
    %             % TODO: implement plotting logic
    %         case 'uiStateChanged'
    %             % TODO: save/restore UI state
    %         otherwise
    %             fprintf('[plotMenu] Unknown message type: %s\n', ...
    %                     incomingData.type);
    %     end
    % end
end