(function () {
    "use strict";

    let matlabComponent   = null;
    let statusTextElement = null;
    let pingButtonElement = null;

    window.setup = function setup(htmlComponent) {
        matlabComponent   = htmlComponent;
        statusTextElement = document.getElementById("pm-status-text");
        pingButtonElement = document.getElementById("pm-ping-button");

        matlabComponent.addEventListener("DataChanged", onMatlabDataChanged);

        if (pingButtonElement) {
            pingButtonElement.addEventListener("click", onPingButtonClicked);
        }

        if (matlabComponent.Data) {
            onMatlabDataChanged();
        }

        // Notify MATLAB that the UI is ready (via Data)
        sendDataToMatlab("uiReady", { ready: true, ts: Date.now() });
    };

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
        } else if (message.type === "statusMessage") {
            const p = message.payload || {};
            updateStatus(p.text || "Status update");
        } else {
            updateStatus(`Received message: ${message.type}`);
        }
    }

    function onPingButtonClicked() {
        updateStatus("Sending ping to MATLAB...");
        sendDataToMatlab("pingFromUI", { ts: Date.now() });
    }

    function updateStatus(text) {
        if (statusTextElement) {
            statusTextElement.textContent = text;
        }
    }

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
})();
