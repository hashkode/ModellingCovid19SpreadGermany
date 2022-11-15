function mobility = processDestatisMobilityCountyData(destatisDataPath)
%PROCESSDESTATISMOBILITYPASSENGERDATA Read and interpolate Destatis
%mobility passenger data and assemble in a timetable
%   This function extracts mobility data per county provided by DESTATIS
%   and specified by @destatisDataPath.
%   The data is processed into a timetable with daily mobility per county
%   @mobility.

mobilityRaw = readtable(destatisDataPath, 'Sheet', 2);

tmp = mobilityRaw.Properties.VariableNames(3:end);

for i = 1:size(tmp, 2)
    timeVector(i) = string(strrep(tmp{i}, 'x', ''));
end

mobilityTimeVector = datetime(timeVector ,'InputFormat', 'yyyy_MM_dd')';

idARS = str2double(string(mobilityRaw(:, 1).Variables))';

mobilityValues = mobilityRaw(:, 3:end).Variables';

% adapted from: https://stackoverflow.com/questions/26441525/how-to-interpolate-nan-values-linearly-in-matlab
for i = 1:size(mobilityValues, 2)
    t = 1:numel(mobilityValues(:, i));
    mobilityValues(:, i) = interp1(t(~isnan(mobilityValues(:, i))), mobilityValues((~isnan(mobilityValues(:, i))), i), t, 'linear', 'extrap');
end

% lower bound on relative mobility change, to fix possible intra- or 
% extrapolation errors
mobilityValues(mobilityValues < -100) = -100;

mobility = array2timetable(mobilityValues, 'RowTimes', mobilityTimeVector, 'VariableNames', string(idARS));
end
