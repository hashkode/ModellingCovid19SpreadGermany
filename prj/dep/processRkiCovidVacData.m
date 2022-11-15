function rkiCovidVac = processRkiCovidVacData(rkiFilePath)
%PROCESSRKICOVIDVACDATA Read and processe the RKI COVID-19 vaccination data.
%   This function processes the vaccination data by RKI @rkiFilePath and
%   returns the daily and accumulated vaccination data per type - first,
%   second, total - as a struct of timetables @rkiCovidVac.

rkiCovidVacRaw = readtable(rkiFilePath, 'Sheet', 'Impfungen_proTag');

% remove nonrelevant lines
idxSum = find(string(rkiCovidVacRaw(:, 'Datum').Variables) == 'Gesamt');
rkiCovidVacRaw = rkiCovidVacRaw(1:idxSum-1, :);

rkiCovidVacRaw.Datum = datetime(rkiCovidVacRaw.Datum, 'InputFormat', 'dd.MM.yyyy');

daily = table2timetable(rkiCovidVacRaw, 'RowTimes', 'Datum');
daily = sortrows(daily, 'Datum', 'ascend');

accCases = daily;
for j = 1:size(accCases, 1)
    accCases(j, :) = varfun(@sum, daily(1:j, :));
end
accumulated = accCases;

rkiCovidVac.daily = daily;
rkiCovidVac.accumulated = accumulated;
end
