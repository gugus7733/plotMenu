(function () {
    "use strict";

    // Keep reference to the htmlComponent (MATLAB side object).
    let matlabComponent = null;

    // DOM elements used in the minimal shell.
    let statusTextElement = null;
    let pingButtonElement = null;

    //----------------------------------------------------------------------
    // Mandatory entry point for MATLAB uihtml: setup(htmlComponent)
    // This function is automatically called by MATLAB when the HTML loads.
    //----------------------------------------------------------------------
    window.setup = function setup(htmlComponent) {
        matlabComponent  = htmlComponent;
        statusTextElement = document.getElementById("pm-status-text");
        pingButtonElement = document.getElementById("pm-ping-button");

        // Listen for Data changes coming from MATLAB (htmlComponent.Data).
        matlabComponent.addEventListener("DataChanged", onMatlabDataChanged);

        // Wire button click to send a message to MATLAB.
        if (pingButtonElement) {
            pingButtonElement.addEventListener("click", onPingButtonClicked);
        }

        // On initial setup, if MATLAB already set some Data, process it.
        if (matlabComponent.Data) {
            onMatlabDataChanged();
        }

        // Notify MATLAB that the UI is ready.
        sendEventToMatlab("uiReady", { ready: true, ts: Date.now() });
    };

    //----------------------------------------------------------------------
    // Handle DataChanged events from MATLAB (MATLAB set htmlComponent.Data).
    //----------------------------------------------------------------------
    function onMatlabDataChanged() {
        const message = matlabComponent.Data;

        if (!message || typeof message !== "object") {
            updateStatus("Received unknown data from MATLAB");
            console.log("[PlotMenu] Data from MATLAB:", message);
            return;
        }

        console.log("[PlotMenu] Data from MATLAB:", message);

        if (message.type === "initFromMatlab") {
            const info = message.payload || {};
            const label = info.appName
                ? `${info.appName} v${info.version || "?"}`
                : "Connected to MATLAB";

            updateStatus(`Connected · ${label}`);
        } else if (message.type === "pongFromMatlab") {
            updateStatus("Received pong from MATLAB");
        } else {
            updateStatus(`Received message: ${message.type}`);
        }
    }

    //----------------------------------------------------------------------
    // Handle click on the "Ping MATLAB" button.
    //----------------------------------------------------------------------
    function onPingButtonClicked() {
        updateStatus("Sending ping to MATLAB...");
        sendDataToMatlab("pingFromUI", { ts: Date.now() });
    }

    //----------------------------------------------------------------------
    // Convenience: update status line in the UI.
    //----------------------------------------------------------------------
    function updateStatus(text) {
        if (statusTextElement) {
            statusTextElement.textContent = text;
        }
    }

    //----------------------------------------------------------------------
    // Bridge helpers
    //----------------------------------------------------------------------

    // Send a message via the Data property (triggers DataChangedFcn in MATLAB).
    function sendDataToMatlab(type, payload) {
        if (!matlabComponent) {
            console.warn("[PlotMenu] MATLAB component not initialized.");
            return;
        }

        matlabComponent.Data = {
            type:    type,
            payload: payload || null
        };
    }

    // Send an event to MATLAB (triggers HTMLEventReceivedFcn in MATLAB).
    function sendEventToMatlab(eventName, data) {
        if (!matlabComponent || typeof matlabComponent.sendEventToMATLAB !== "function") {
            console.warn("[PlotMenu] sendEventToMATLAB not available.");
            return;
        }

        matlabComponent.sendEventToMATLAB(eventName, data || null);
    }

})();