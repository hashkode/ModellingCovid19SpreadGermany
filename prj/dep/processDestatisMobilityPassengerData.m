function mobilityPassenger = processDestatisMobilityPassengerData(destatisDataPath)
%PROCESSDESTATISMOBILITYPASSENGERDATA Read and interpolate Destatis
%mobility passenger data and assemble in a timetable
%   This function extracts national level mobility data for passenger
%   mobility using different modes of transportation provided by DESTATIS
%   and specified by @destatisDataPath.
%   The data is processed into a timetable with daily mobility per mode of
%   transportation @mobilityPassenger.

mobilityRaw = readtable(destatisDataPath);

mobilityRaw = strrep(string(mobilityRaw(:, :).Variables), ',', '.');
mobilityValues = str2double(mobilityRaw(:, 2:end));
mobilityTimeVector = datetime(mobilityRaw(:, 1), 'Format', 'yyyy/MM/dd');

% adapted from: https://stackoverflow.com/questions/26441525/how-to-interpolate-nan-values-linearly-in-matlab
for i = 1:size(mobilityValues, 2)
    t = 1:numel(mobilityValues(:, i));
    mobilityValues(:, i) = interp1(t(~isnan(mobilityValues(:, i))), mobilityValues((~isnan(mobilityValues(:, i))), i), t, 'linear', 'extrap');
end

% lower bound on relative mobility change, to fix possible intra- or 
% extrapolation errors
mobilityValues(mobilityValues < -100) = -100;

mobilityPassenger = array2timetable(mobilityValues, 'RowTimes', mobilityTimeVector, 'VariableNames', ["rail", "road", "flightNation", "unknown"]);
end
