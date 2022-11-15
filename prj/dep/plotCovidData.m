function plotCovidData(nation, counties, arsList, seirSettings)
%PLOTCOVIDDATA Plot the COVID-19 data for selected ARS values
%   This function plots the COVID-19 data for the counties specified by
%   their ARS identitier in the arsList parameter
fCases = figure('Name', 'COVID-19 cases per county');
tgMap = uitabgroup(fCases);
for i = 1:size(arsList, 2)
    countyIdx = find(nation.county.bkg250KrsArs == arsList(i));
    tCases(i) = uitab(tgMap, 'Title', counties(countyIdx).name);
    stackedplot(tCases(i), counties(countyIdx).cases, 'Title', counties(countyIdx).name);
    outFile = append("./SEIR_sim_outputs/", seirSettings.timeSimStart, "/figures/COVID-Data", string(i), ".pdf");
    saveTabToFile(tCases(i), outFile, seirSettings.saveFigures);
end
end
