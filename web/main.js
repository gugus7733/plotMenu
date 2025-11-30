(function () {
    "use strict";

    let matlabComponent = null;

    const state = {
        xCandidates: [],
        yCandidates: [],
        selectedX: "",
        selectedY: [],
        superpose: true,
        legend: true,
        latestUpdate: "Idle",
    };

    const els = {};

    window.setup = function setup(htmlComponent) {
        matlabComponent = htmlComponent;

        cacheDom();
        bindDomEvents();

        matlabComponent.addEventListener("DataChanged", onMatlabDataChanged);

        if (matlabComponent.Data) {
            onMatlabDataChanged();
        }

        updateSummary();
        sendDataToMatlab("uiReady", { ready: true, ts: Date.now() });
    };

    function cacheDom() {
        els.statusText = document.getElementById("pm-status-text");
        els.statusBody = document.getElementById("pm-status-body");
        els.pingButton = document.getElementById("pm-ping-button");
        els.refreshButton = document.getElementById("pm-refresh-button");
        els.xSelect = document.getElementById("pm-x-select");
        els.xMeta = document.getElementById("pm-x-meta");
        els.xCount = document.getElementById("pm-x-count");
        els.yList = document.getElementById("pm-y-list");
        els.yCount = document.getElementById("pm-y-count");
        els.plotButton = document.getElementById("pm-plot-button");
        els.exportButton = document.getElementById("pm-export-button");
        els.latestUpdate = document.getElementById("pm-latest-update");
        els.summaryX = document.getElementById("pm-summary-x");
        els.summaryY = document.getElementById("pm-summary-y");
        els.summarySuperpose = document.getElementById("pm-summary-superpose");
        els.summaryLegend = document.getElementById("pm-summary-legend");
        els.superposeToggle = document.getElementById("pm-superpose-toggle");
        els.legendToggle = document.getElementById("pm-legend-toggle");
        els.connectionPill = document.getElementById("pm-connection-indicator");
    }

    function bindDomEvents() {
        if (els.pingButton) {
            els.pingButton.addEventListener("click", onPingButtonClicked);
        }

        if (els.refreshButton) {
            els.refreshButton.addEventListener("click", requestWorkspaceSnapshot);
        }

        if (els.xSelect) {
            els.xSelect.addEventListener("change", onXSelectionChanged);
        }

        if (els.plotButton) {
            els.plotButton.addEventListener("click", onPlotRequested);
        }

        if (els.exportButton) {
            els.exportButton.addEventListener("click", onExportRequested);
        }

        if (els.superposeToggle) {
            els.superposeToggle.addEventListener("change", function () {
                state.superpose = !!this.checked;
                updateSummary();
            });
        }

        if (els.legendToggle) {
            els.legendToggle.addEventListener("change", function () {
                state.legend = !!this.checked;
                updateSummary();
            });
        }
    }

    function onMatlabDataChanged() {
        const message = matlabComponent.Data;

        if (!message || typeof message !== "object") {
            updateStatus("Received unknown data from MATLAB", true);
            console.log("[PlotMenu] Data from MATLAB:", message);
            return;
        }

        console.log("[PlotMenu] Data from MATLAB:", message);

        const payload = message.payload || {};
        switch (message.type) {
            case "initFromMatlab":
                updateStatus(formatInitLabel(payload));
                requestWorkspaceSnapshot();
                break;
            case "pongFromMatlab":
                updateStatus("Received pong from MATLAB");
                break;
            case "statusMessage":
                updateStatus(payload.text || "Status update", payload.level === "error");
                break;
            case "workspaceSnapshot":
                handleWorkspaceSnapshot(payload);
                break;
            case "yCandidates":
                handleYCandidates(payload);
                break;
            case "plotUpdate":
                handlePlotUpdate(payload);
                break;
            case "exportResult":
                handleExportResult(payload);
                break;
            default:
                updateStatus(`Received message: ${message.type}`);
        }
    }

    function formatInitLabel(info) {
        const label = info.appName ? `${info.appName} v${info.version || "?"}` : "Connected to MATLAB";
        return `Connected · ${label}`;
    }

    function onPingButtonClicked() {
        updateStatus("Sending ping to MATLAB...");
        sendDataToMatlab("pingFromUI", { ts: Date.now() });
    }

    function requestWorkspaceSnapshot() {
        updateStatus("Requesting workspace snapshot...");
        sendDataToMatlab("requestWorkspaceSnapshot", { ts: Date.now() });
    }

    function onXSelectionChanged(event) {
        state.selectedX = event.target.value || "";
        updateSummary();

        if (!state.selectedX) {
            renderYList([]);
            return;
        }

        els.yList.innerHTML = '<div class="pm-empty">Loading Y candidates...</div>';
        sendDataToMatlab("requestYCandidates", { xName: state.selectedX, ts: Date.now() });
    }

    function onPlotRequested() {
        if (!state.selectedX || state.selectedY.length === 0) {
            updateStatus("Select an X variable and at least one Y candidate first.", true);
            return;
        }

        updateStatus("Sending plot request to MATLAB...");
        sendDataToMatlab("plotRequest", {
            xName: state.selectedX,
            yExpressions: state.selectedY.slice(),
            options: {
                superpose: state.superpose,
                legend: state.legend,
            },
            ts: Date.now(),
        });
    }

    function onExportRequested() {
        if (!state.selectedX || state.selectedY.length === 0) {
            updateStatus("Select an X variable and at least one Y candidate first.", true);
            return;
        }

        updateStatus("Requesting export code from MATLAB...");
        sendDataToMatlab("exportRequest", {
            xName: state.selectedX,
            yExpressions: state.selectedY.slice(),
            options: {
                superpose: state.superpose,
            },
            ts: Date.now(),
        });
    }

    function handleWorkspaceSnapshot(payload) {
        state.xCandidates = normalizeToArray(payload.xCandidates);
        renderXCandidates();
        updateStatus(`Workspace: ${state.xCandidates.length} X candidates loaded.`);
    }

    function handleYCandidates(payload) {
        const items = normalizeToArray(payload.items);
        state.yCandidates = items;
        renderYList(items);
        updateStatus(`Received ${items.length} Y candidates.`);
    }

    function handlePlotUpdate(payload) {
        state.latestUpdate = payload.message || "Plot updated.";
        if (els.latestUpdate) {
            els.latestUpdate.textContent = state.latestUpdate;
        }
        updateStatus(state.latestUpdate, payload.status === "error");
    }

    function handleExportResult(payload) {
        const text = payload && payload.message ? payload.message : "Export completed.";
        updateStatus(text, payload.status === "error");
    }

    function renderXCandidates() {
        if (!els.xSelect) {
            return;
        }

        els.xSelect.innerHTML = "";

        if (state.xCandidates.length === 0) {
            const opt = document.createElement("option");
            opt.textContent = "No numeric arrays found";
            opt.value = "";
            opt.disabled = true;
            els.xSelect.appendChild(opt);
            els.xSelect.disabled = true;
            updateXMeta();
            return;
        }

        const placeholder = document.createElement("option");
        placeholder.textContent = "Select an X variable";
        placeholder.value = "";
        placeholder.selected = true;
        placeholder.disabled = true;
        els.xSelect.appendChild(placeholder);

        state.xCandidates.forEach(function (item) {
            const opt = document.createElement("option");
            opt.value = item.name;
            opt.textContent = `${item.name} · ${item.sizeString || item.class}`;
            opt.dataset.meta = JSON.stringify(item);
            els.xSelect.appendChild(opt);
        });

        els.xSelect.disabled = false;
        if (els.xCount) {
            els.xCount.textContent = `${state.xCandidates.length} candidates`;
        }
        updateXMeta();
    }

    function renderYList(items) {
        if (!els.yList) {
            return;
        }

        els.yList.innerHTML = "";
        state.selectedY = [];
        updateSummary();

        if (!items || items.length === 0) {
            els.yList.innerHTML = '<div class="pm-empty">No compatible Y candidates for this X.</div>';
            if (els.yCount) {
                els.yCount.textContent = "0 items";
            }
            return;
        }

        items.forEach(function (item, idx) {
            const wrapper = document.createElement("label");
            wrapper.className = "pm-y-item";

            const checkbox = document.createElement("input");
            checkbox.type = "checkbox";
            checkbox.value = item.expression;
            checkbox.addEventListener("change", function () {
                if (this.checked) {
                    if (!state.selectedY.includes(this.value)) {
                        state.selectedY.push(this.value);
                    }
                } else {
                    state.selectedY = state.selectedY.filter(function (v) { return v !== checkbox.value; });
                }
                updateSummary();
            });

            const textWrap = document.createElement("div");
            const title = document.createElement("div");
            title.className = "pm-y-label";
            title.textContent = item.label || item.expression || `Entry ${idx + 1}`;

            const subtitle = document.createElement("div");
            subtitle.className = "pm-y-expression";
            subtitle.textContent = item.expression || "";

            textWrap.appendChild(title);
            textWrap.appendChild(subtitle);

            wrapper.appendChild(checkbox);
            wrapper.appendChild(textWrap);
            els.yList.appendChild(wrapper);
        });

        if (els.yCount) {
            els.yCount.textContent = `${items.length} items`;
        }
    }

    function updateXMeta() {
        if (!els.xMeta) {
            return;
        }

        const selectedOption = els.xSelect ? els.xSelect.selectedOptions[0] : null;
        if (!selectedOption || !selectedOption.dataset.meta) {
            els.xMeta.textContent = "No selection yet";
            return;
        }

        try {
            const meta = JSON.parse(selectedOption.dataset.meta);
            els.xMeta.textContent = `${meta.class} [${meta.sizeString}]`;
        } catch (err) {
            els.xMeta.textContent = "";
        }
    }

    function updateSummary() {
        if (els.summaryX) {
            els.summaryX.textContent = state.selectedX || "None";
        }
        if (els.summaryY) {
            els.summaryY.textContent = `${state.selectedY.length} selected`;
        }
        if (els.summarySuperpose) {
            els.summarySuperpose.textContent = state.superpose ? "On" : "Off";
        }
        if (els.summaryLegend) {
            els.summaryLegend.textContent = state.legend ? "Visible" : "Hidden";
        }
    }

    function updateStatus(text, isError) {
        if (els.statusText) {
            els.statusText.textContent = text;
        }
        if (els.statusBody) {
            els.statusBody.textContent = text;
        }
        if (els.connectionPill) {
            els.connectionPill.classList.toggle("is-error", !!isError);
        }
    }

    function sendDataToMatlab(type, payload) {
        if (!matlabComponent) {
            console.warn("[PlotMenu] MATLAB component not initialized.");
            return;
        }
        matlabComponent.Data = {
            type: type,
            payload: payload || null,
        };
    }

    function normalizeToArray(value) {
        if (Array.isArray(value)) {
            return value;
        }
        if (value === undefined || value === null) {
            return [];
        }
        return [value];
    }
})();
