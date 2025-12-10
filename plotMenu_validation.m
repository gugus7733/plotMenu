% plotMenu_validation - Structured validation dataset for PlotMenu GUI
% This script seeds the base workspace with a concise, well-documented set of
% variables that exercise PlotMenu features (X/Y selection, indexing, nested
% containers, tables, timeseries, etc.). Each section highlights a data type or
% feature so manual testing feels like running a set of mini unit tests.

%% Section 1: Clear workspace and basic setup
% Ensures a clean starting point and reproducible random content where needed.
close all;
clear;
clc;
rng(0);

%% Section 2: Define integer index variables
% Tests index selection for cells, structs, tables, and matrices.
idx_row_1 = 1;       % simple row index
idx_row_2 = 2;       % alternate row index
idx_col_1 = int32(1);% first column selector (explicit integer class)
idx_col_3 = int32(3);% third column selector for multi-column data
idx_element_5 = uint8(5); % generic element index for vectors/cells

%% Section 3: Define simple vectors and matrices (core numeric X/Y signals)
% Tests basic X/Y selection with row vs column vectors and multi-column matrices.
vec_time_uniform = linspace(0, 2*pi, 250);            % [1xN] row time base
vec_time_slow    = linspace(0, 8*pi, numel(vec_time_uniform)); % slower sweep

vec_signal_sine      = sin(2*pi*1.0*vec_time_uniform);           % [1xN]
vec_signal_cosine    = cos(2*pi*0.5*vec_time_uniform + pi/4);    % [1xN]
vec_signal_ramp      = 0.2 * vec_time_uniform - 0.5;             % [1xN]
vec_signal_noisy     = vec_signal_sine + 0.1 * randn(size(vec_time_uniform));
vec_signal_nan_gap   = vec_signal_sine; vec_signal_nan_gap(80:120) = NaN; % gap
vec_signal_outlier   = vec_signal_sine; vec_signal_outlier(200) = 8;      % spike

% Matrix with multiple channels to test column selection.
matrix_signals_3xN = [
    vec_signal_sine;
    vec_signal_cosine;
    vec_signal_ramp
]; % size 3xN (rows = channels, columns = samples)

% Alternative orientation to check row/column handling.
matrix_signals_Nx3 = matrix_signals_3xN.'; % size Nx3 (columns = channels)

%% Section 4: Define large-dimension matrix / multi-dimensional arrays
% Tests dimension detection and large matrices without flooding the workspace.
matrix_large_dimension = reshape(1:2400, [60, 40]); % 60x40 grid
array_multi_dimensional = reshape(1:360, [6, 5, 12]); % 3-D array to test slice selection

%% Section 5: Define cell arrays
% Tests cell indexing using integer indices and mixed content handling.
cell_signals_mixed = {
    vec_signal_sine, vec_signal_noisy;           % numeric vectors
    vec_signal_nan_gap, {vec_signal_cosine, 'meta note'}; % nested cell with text
};

cell_grid_for_indexing = {
    vec_signal_sine, vec_signal_cosine, vec_signal_ramp;
    vec_signal_noisy, vec_signal_outlier, vec_signal_nan_gap;
}; % 2x3 cell array to combine with idx_row/col variables

%% Section 6: Define tables
% Tests table column selection and time alignment.
vec_temperature = 20 + 2*sin(0.3 * vec_time_slow);
vec_pressure    = 1013 + 5*cos(0.25 * vec_time_slow + 0.2);
vec_humidity    = 50 + 10*sin(0.5 * vec_time_slow - 0.1);

table_measurements = table(...
    vec_time_slow.', vec_temperature.', vec_pressure.', vec_humidity.', ...
    'VariableNames', {'Time', 'Temperature_C', 'Pressure_hPa', 'Humidity_percent'});

% Short table for quick column picking
vec_short_x = (1:10).';
vec_short_y = (1:10).' + 5;
table_short_example = table(vec_short_x, vec_short_y, 'VariableNames', {'Sample', 'Value'});

%% Section 7: Define structs / nested structs
% Tests struct field navigation and nested fields.
struct_signals = struct(...
    'time', vec_time_uniform,...
    'sine', vec_signal_sine,...
    'cosine', vec_signal_cosine,...
    'noisy', vec_signal_noisy,...
    'nan_gap', vec_signal_nan_gap);

struct_experiment.metadata.description = 'Synthetic experiment';
struct_experiment.metadata.sample_rate_hz = numel(vec_time_uniform) / (vec_time_uniform(end) - vec_time_uniform(1));
struct_experiment.sensors.temperature = vec_temperature;
struct_experiment.sensors.pressure = vec_pressure;
struct_experiment.sensors.humidity = vec_humidity;
struct_experiment.results.multichannel = matrix_signals_Nx3;

%% Section 8: Define timeseries (if applicable)
% Tests timeseries support with clear names and simple signals.
ts_temperature = timeseries(vec_temperature.', vec_time_slow.');
ts_temperature.Name = 'Temperature (C)';

ts_pressure = timeseries(vec_pressure.', vec_time_slow.');
ts_pressure.Name = 'Pressure (hPa)';

%% Section 9: Launch PlotMenu
% Opens GUI with all variables available for selection and manual exploration.
plotMenu();
% start_app();
