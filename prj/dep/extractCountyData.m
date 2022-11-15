function counties = extractCountyData(nation)
%EXTRACTCOUNTYDATA Decompose nation level COVID-19 data into county data.
%   This function processes the COVID-19 data struct @nation and returns
%   COVID-19 data and auxilliary information per county in a struct array
%   @counties.

for i = 1:size(nation.county.bkg250KrsArs, 1)
    % BKG data
    counties(i).ars = nation.county.bkg250KrsArs(i);
    counties(i).name = nation.county.bkgData(i).GEN;
    counties(i).area.lat = nation.county.bkgData(i).Lat;
    counties(i).area.lon = nation.county.bkgData(i).Lon;
    counties(i).area.polyshape = nation.county.bkgData(i).Polyshape;
    counties(i).area.geoshape = nation.county.bkgData(i).Geoshape;
    counties(i).area.size = nation.county.bkgData(i).KFL;
    counties(i).residents = nation.county.bkgData(i).EWZ;
end
    
for i = 1:size(nation.county.bkg250KrsArs, 1)    
    % RKI COVID-19 data
    counties(i).cases = nation.county.rkiCovid.daily{1}(:, i);
    counties(i).cases.Properties.VariableNames{1} = 'infected';
    counties(i).cases.recovered = nation.county.rkiCovid.daily{2}(:, i).Variables;
    counties(i).cases.dead = nation.county.rkiCovid.daily{3}(:, i).Variables;
    
    counties(i).cases.infectedAcc = nation.county.rkiCovid.accumulated{1}(:, i).Variables;
    counties(i).cases.recoveredAcc = nation.county.rkiCovid.accumulated{2}(:, i).Variables;
    counties(i).cases.deadAcc = nation.county.rkiCovid.accumulated{3}(:, i).Variables;

    % RKI COVID-19 vaccination data
    totalResidents = sum([counties(:).residents]);
    vaccFirstRatio = nation.rkiCovidVac.accumulated.Erstimpfung/totalResidents;
    vaccSecondRatio = nation.rkiCovidVac.accumulated.Zweitimpfung/totalResidents;
    vaccTotalRatio = nation.rkiCovidVac.accumulated.GesamtzahlVerabreichterImpfstoffdosen/totalResidents;
    
    vaccTimeVector = nation.rkiCovidVac.accumulated.Datum;
    vaccinationFirst = timetable(vaccTimeVector, vaccFirstRatio * counties(i).residents, 'VariableNames', {'vaccinationFirstAcc'});
    vaccinationSecond = timetable(vaccTimeVector, vaccSecondRatio * counties(i).residents, 'VariableNames', {'vaccinationSecondAcc'});
    
    casesTimeVector = counties(i).cases.Datum;
    
    counties(i).cases = synchronize(counties(i).cases, vaccinationFirst);    
    counties(i).cases = synchronize(counties(i).cases, vaccinationSecond);
    
    [~, idxVaccDataMissing] = setdiff(casesTimeVector, vaccTimeVector);
    counties(i).cases.vaccinationFirstAcc(idxVaccDataMissing) = 0;
    counties(i).cases.vaccinationSecondAcc(idxVaccDataMissing) = 0;
    
    % ensure monotonous increasing columns
    for iRow = 2:size(counties(i).cases, 1)
        if counties(i).cases.vaccinationFirstAcc(iRow) < counties(i).cases.vaccinationFirstAcc(iRow-1)
            counties(i).cases.vaccinationFirstAcc(iRow) = counties(i).cases.vaccinationFirstAcc(iRow-1);
        end
        
        if counties(i).cases.vaccinationSecondAcc(iRow) < counties(i).cases.vaccinationSecondAcc(iRow-1)
            counties(i).cases.vaccinationSecondAcc(iRow) = counties(i).cases.vaccinationSecondAcc(iRow-1);
        end
    end
    
    counties(i).cases.susceptible = counties(i).residents - ...
        (counties(i).cases.infectedAcc ...
        + counties(i).cases.recoveredAcc ...
        + counties(i).cases.deadAcc ...
        + counties(i).cases.vaccinationSecondAcc);
end
end
