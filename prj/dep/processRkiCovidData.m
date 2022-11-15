function rkiCovidCounty = processRkiCovidData(rkiCovidFilePath, nation)
%PROCESSRKICOVIDDATA Read and processe the RKI COVID-19 data per county.
%   This function reads, extracts and process the RKI COVID-19 data
%   @rkiCovidFilePath into a struct of timetables @rkiCovidCounty that hold
%   the daily and accumulated cases per county per compartment - namely
%   infected, recovered and dead.

rkiCovidRaw = readtable(rkiCovidFilePath, 'Delimiter', ',');

% define superfluous columns in the RKI data table
rkiCovidSpareColumns = {'Altersgruppe', 'Geschlecht', 'Datenstand', ...
    'Meldedatum', 'NeuerFall', 'NeuerTodesfall', 'Altersgruppe2', ...
    'NeuGenesen', 'IstErkrankungsbeginn'};

rkiCovidFiltered = removevars(rkiCovidRaw, rkiCovidSpareColumns);
% rename Refdatum to Datum
rkiCovidFiltered.Properties.VariableNames{8} = 'Datum';
try
    rkiCovidFiltered.Datum = datetime(rkiCovidFiltered.Datum, 'InputFormat', 'yyyy/MM/dd HH:mm:ss');
catch exception
    if(strcmp(exception.identifier,'MATLAB:datetime:ParseErrs'))
        rkiCovidFiltered.Datum = datetime(rkiCovidFiltered.Datum, 'InputFormat', 'yyyy/MM/dd HH:mm:ss+SS');
    else
        rethrow(exception)
    end
end

% merge Berlin counties in RKI data to match BKG data
rkiBerlinArs = [11001;11002;11003;11004;11005;11006;11007;11008;11009;11010;11011;11012];
bkgBerlinArs = 11000;
rkiCovidFiltered.IdLandkreis = table2array(rowfun(@(ars) mergeArsIDs(ars, bkgBerlinArs, rkiBerlinArs), rkiCovidFiltered, 'InputVariables', 'IdLandkreis'));

rkiCovidFilteredTT = table2timetable(rkiCovidFiltered, 'RowTimes', 'Datum');

% aggregate daily cases per county per case class (new, recovered, dead)
% ommitting gender and age group
warning('off');
[daily{1}, ~] = unstack(rkiCovidFilteredTT, 'AnzahlFall', 'IdLandkreis', 'AggregationFunction', @sum);
[daily{2}, ~] = unstack(rkiCovidFilteredTT, 'AnzahlGenesen', 'IdLandkreis', 'AggregationFunction', @sum);
[daily{3}, ~] = unstack(rkiCovidFilteredTT, 'AnzahlTodesfall', 'IdLandkreis', 'AggregationFunction', @sum);
warning('on');

for i = 1:3
    daily{i} = sortrows(daily{i}, 'Datum', 'ascend');
    daily{i}.Properties.VariableNames = ...
        cellfun(@(x) x(2:end), daily{i}.Properties.VariableNames, 'UniformOutput', false);
end

parfor i = 1:3
    accCases = daily{i};
    for j = 1:size(accCases, 1)
        accCases(j, :) = varfun(@sum, daily{i}(1:j, :));
    end
    accumulated{i} = accCases;
end

% get IDs as numerical array
rkiKrsArs = cell2mat(cellfun(@(x) str2double(x), daily{1}.Properties.VariableNames, 'UniformOutput', false))';

if ~isequal(nation.county.bkg250KrsArs, rkiKrsArs)
    error("BKG ARS list does not match with RKI ARS list")
end

for i = 1:size(daily, 2)
    rkiCovidCounty.daily{i} = daily{i};
    rkiCovidCounty.accumulated{i} = accumulated{i};
end
end
