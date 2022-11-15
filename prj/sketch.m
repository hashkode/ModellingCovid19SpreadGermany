% normPower = 2;
% data = modelSEIR.data;
% 
% err.inf = data.realInf - data.simInf;
% err.infNorm = (norm(err.inf*nation.county.residents', normPower))/(norm(data.realInf*nation.county.residents', normPower));
% 
% err.rem = data.realRem - data.simRem;
% err.remNorm = (norm(err.rem*nation.county.residents', normPower))/(norm(data.realRem*nation.county.residents', normPower));
% 
% err.exp = data.realExp - data.simExp;
% err.expNorm = (norm(err.exp*nation.county.residents', normPower))/(norm(data.realExp*nation.county.residents', normPower));
% 
% rem.r = modelSEIR.data.realRem*nation.county.residents';
% max(rem.r)
% 
% rem.s = modelSEIR.data.simRem*nation.county.residents';
% max(rem.s)
% 
% rem.sCF = modelSEIR.data.simRemCF*nation.county.residents';
% max(rem.sCF)

%% output adjacency matrix and list of country centroids
tst = nation.mobility.daily;
adj = tst{2}(:,:,82);
adj = string(adj);
adj(2:end+1,2:end+1) = adj(:,:);
adj(1,1) = NaN;
adj(2:end,1) = nation.county.bkg250KrsArs;
adj(1,2:end) = nation.county.bkg250KrsArs';
writematrix(adj, 'adj.csv', 'Delimiter', ';')

center = nation.county.bkg250KrsArs;

for i = 1:size(nation.county.bkgData,1)
    [center(i, 2), center(i, 3)] = centroid(counties(i).area.polyshape);
end

center = array2table(center);
center.Properties.VariableNames(1:3) = {'Id','Lon','Lat'};
writetable(center,'center.csv')
    
%% plot of inverted projection of BKG - Germany - county level

mapPadding = 0.02;

fMap = figure('Name', 'Map data debug views');
tgMap = uitabgroup(fMap);

tMap(2) = uitab(tgMap, 'Title', 'geoshow - GER');
axMap(2) = axes('Parent', tMap(2));
hold on

latlim = [nation.lat.min - mapPadding, nation.lat.max + mapPadding];
lonlim = [nation.lon.min - mapPadding, nation.lon.max + mapPadding];
worldmap(latlim, lonlim)

faceColors = makesymbolspec('Polygon', ...
    {'INDEX', [1 size(nation.county.bkgData,1)], 'FaceColor', ...
    polcmap(size(nation.county.bkgData,1))});
geoshow(axMap(2), nation.county.bkgData, 'SymbolSpec', faceColors, 'DisplayType', 'polygon')

radius = .015;
widthFactor = 1.6;

warning('off', 'MATLAB:print:ContentTypeImageSuggested')
for i = 1:size(nation.county.bkgData,1)
    [lon, lat] = centroid(polyshape(nation.county.bkgData(i).Lon, nation.county.bkgData(i).Lat));
    [point.circle.lat, point.circle.lon] = calculateEllipse(lat,  lon, radius, radius * widthFactor, 0);
    point.circle.geoshape = geoshape(point.circle.lat, point.circle.lon, 'Geometry', 'Polygon');
    geoshow(axMap(2), point.circle.geoshape, 'FaceColor', 'r', 'DisplayType', 'polygon')
end
warning('on', 'MATLAB:print:ContentTypeImageSuggested')

hold off
axis(axMap(2),'equal');
title('Germany - county level - geoshow');

outFile = append("./SEIR_sim_outputs/", seirSettings.timeSimStart, "/figures/GER-Map.pdf");
saveTabToFile(tMap(2), outFile, seirSettings.saveFigures);