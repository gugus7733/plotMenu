% plotMenu_validation - Toy validation dataset for PlotMenu GUI
% The script seeds the base workspace with a wide range of sample signals,
% containers, and labels for manual testing. Extend any section to add new
% cases without changing the rest of the file.
close all;
clear;
clc;

%% Reproducible random seed
rng(0);

%% Time bases
basicTime = linspace(0, 2*pi, 250);   % uniform sampling (primary base)
slowTime  = linspace(0, 8*pi, numel(basicTime)); % slow trends but aligned to base length
baseTime  = basicTime;                % alias for readability when pairing signals

%% Basic deterministic signals
sineWave      = sin(2*pi*1.2*basicTime);
cosineWave    = cos(2*pi*0.8*basicTime + pi/6);
triadWaves    = [sineWave; 0.6 * cos(2*pi*4*basicTime); 0.3 * sin(2*pi*8*basicTime)];
linearRamp    = 0.1 * basicTime - 0.5;
quadraticRise = (basicTime - mean(basicTime)).^2;

%% Noisy, discontinuous, and extreme-value cases
noisySine    = sineWave + 0.15 * randn(size(sineWave));
stepSignal   = double(baseTime >= pi);
impulseTrain = zeros(size(baseTime));
impulseTrain(50:50:end) = 1;
nanGapSignal = sineWave;
nanGapSignal(80:120) = NaN;        % missing window for gap-handling checks
largeSpikeSignal = sineWave;
largeSpikeSignal(200) = 10;        % outlier to test axis scaling

%% Alternative sampling and mixed units (aligned versions)
irregularTime = cumsum(0.01 + 0.01 * rand(1, numel(baseTime)));
chirpLike     = sin(2*pi*(0.2*irregularTime + 0.05*(irregularTime.^2)));
unitLabels    = ["seconds", "volts", "degrees C"];

% Clearly "bad" timebases for mismatch testing
badTimeShort = linspace(0, 2*pi, 120);
badTimeLong  = linspace(0, 4*pi, 400);
badlyConditionedShort = 2 * mod(badTimeShort * 3 / (2*pi), 1) - 1; % sawtooth-like without toolbox
badlyConditionedShort = badlyConditionedShort + 0.1 * randn(size(badTimeShort));
badlyConditionedLong  = sin(0.6 * badTimeLong) + 0.5 * rand(size(badTimeLong));
badlyConditionedLong(50:60) = NaN; % obvious artifact window

%% Grouped data containers
signalStruct = struct( ...
    'time', basicTime, ...
    'sine', sineWave, ...
    'cosine', cosineWave, ...
    'noisy', noisySine, ...
    'nanGap', nanGapSignal);

sensors = struct();
sensors.temperature.C = 20 + 2*sin(0.5*slowTime);
sensors.humidity.percent = 50 + 5*cos(0.8*slowTime);
sensors.pressure.hPa = 1013 + 3*sin(0.3*slowTime + 0.4);

multiChannelMatrix = [sineWave; noisySine; stepSignal; impulseTrain; largeSpikeSignal]';
channelNames       = {"sine", "noisy", "step", "impulses", "spike"};
matrixWithMeta    = [sineWave.', noisySine.', linearRamp.'];

%% Cell arrays and text-heavy inputs
cellSignals = { ...
    sineWave,          noisySine; ...
    stepSignal,        impulseTrain; ...
    nanGapSignal,      linearRamp};

descriptions = { ...
    'Baseline sine', 'Noisy sine'; ...
    'Unit step',     'Impulse grid'; ...
    'NaN gap',       'Linear ramp'};

%% Integer indices for popup exploration
colIndex   = int32(2);
rowIndex   = 3;
elementIdx = uint8(5);

%% Tables for indexed access
signalTable = table(basicTime.', sineWave.', noisySine.', linearRamp.', ...
    'VariableNames', {'time', 'sine', 'noisy', 'ramp'});
shortTable  = table((1:10).', (1:10).', 'VariableNames', {'shortX', 'shortY'});

%% Struct arrays and nested content
structArray(1).signal = sineWave;
structArray(1).label  = 'clean';
structArray(2).signal = noisySine;
structArray(2).label  = 'noisy';
nestedCells = {cellSignals, multiChannelMatrix; descriptions, channelNames};

%% Frequency metadata and lookup helpers
freqListHz   = [0.2, 1, 4, 8, 16];
freqLabels   = ["very low", "low", "mid", "high", "very high"];
freqStruct   = struct('labels', freqLabels, 'values', freqListHz);

%% Launch the GUI with all variables available for selection
plotMenu();
% start_app();
