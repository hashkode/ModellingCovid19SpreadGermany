function plotMapData(nation, testcounty, testpoints, testpointInteriorStatus, seirSettings)
%PLOTMAPDATA Plot the county with mapshow, geoshow and use testpoints
%   This function uses the the BKG data to display a map. Once with mapshow
%   and once with geoshow to show the difference caused by coordinate
%   transformation. Additionally, the function checks whether the tuples in
%   testpoints are within or outside of the are of testcounty and plots the
%   result as a map.

% plot different shape types and interior point check
% global parameters
mapPadding = 0.02;

fMap = figure('Name', 'Map data debug views');
tgMap = uitabgroup(fMap);
% plot BKG - Germany - county level
tMap(1) = uitab(tgMap, 'Title', 'mapshow - GER');
axMap(1) = axes('Parent', tMap(1));

mapshow(axMap(1), nation.county.bkgData, 'FaceColor', [1 1 1]);
axis(axMap(1),'equal');
title('Germany - county level - mapshow');

% plot of inverted projection of BKG - Germany - county level
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

for i = 1:size(bkgData,1)
    geoshow(axMap(2), polyshape(nation.county.bkgData(i).Lon, nation.county.bkgData(i).Lat))
end

hold off
axis(axMap(2),'equal');
title('Germany - county level - geoshow');

outFile = append("./SEIR_sim_outputs/", seirSettings.timeSimStart, "/figures/GER-Map.pdf");
saveTabToFile(tMap(2), outFile, seirSettings.saveFigures);

% plot test county and test points
tMap(3) = uitab(tgMap, 'Title', append('geoshow - ', testcounty.name));
axMap(3) = axes('Parent', tMap(3));
hold on
latlim = [min([testcounty.area.lat, testpoints(:, 2)']) - mapPadding, max([testcounty.area.lat, testpoints(:, 2)']) + mapPadding];
lonlim = [min([testcounty.area.lon, testpoints(:, 1)']) - mapPadding, max([testcounty.area.lon, testpoints(:, 1)']) + mapPadding];
worldmap(latlim, lonlim)
geoshow(axMap(3), testcounty.area.geoshape, 'FaceColor', '#f8f8f8', 'DisplayType', 'polygon')

for i = 1:size(testpointInteriorStatus, 1)
    % define radius and skew factor from projection to plot city points as
    % circles
    radius = .005;
    widthFactor = 1.4849;
    
    if testpointInteriorStatus(i)
        point.lat = testpoints(i, 2);
        point.lon = testpoints(i, 1);
        [point.circle.lat, point.circle.lon] = calculateEllipse(point.lat,  point.lon, radius, radius * widthFactor, 0);
        point.circle.geoshape = geoshape(point.circle.lat, point.circle.lon, 'Geometry', 'Polygon');
        geoshow(axMap(3), point.circle.geoshape, 'FaceColor', 'g', 'DisplayType', 'polygon')
    else
        point.lat = testpoints(i, 2);
        point.lon = testpoints(i, 1);
        [point.circle.lat, point.circle.lon] = calculateEllipse(point.lat,  point.lon, radius, radius * widthFactor, 0);
        point.circle.geoshape = geoshape(point.circle.lat, point.circle.lon, 'Geometry', 'Polygon');
        geoshow(axMap(3), point.circle.geoshape, 'FaceColor', 'r', 'DisplayType', 'polygon')
    end
end

hold off
axis(axMap(3),'equal');
title(append(testcounty.name, ' - plot geoshape'));

% plot test county and test points
tMap(3) = uitab(tgMap, 'Title', append('geoshow - ', testcounty.name));
axMap(3) = axes('Parent', tMap(3));
hold on
latlim = [min([testcounty.area.lat, testpoints(:, 2)']) - mapPadding, max([testcounty.area.lat, testpoints(:, 2)']) + mapPadding];
lonlim = [min([testcounty.area.lon, testpoints(:, 1)']) - mapPadding, max([testcounty.area.lon, testpoints(:, 1)']) + mapPadding];
worldmap(latlim, lonlim)
geoshow(axMap(3), testcounty.area.geoshape, 'FaceColor', '#f8f8f8', 'DisplayType', 'polygon')

for i = 1:size(testpointInteriorStatus, 1)
    % define radius and skew factor from projection to plot city points as
    % circles
    radius = .005;
    widthFactor = 1.4849;
    
    if testpointInteriorStatus(i)
        point.lat = testpoints(i, 2);
        point.lon = testpoints(i, 1);
        [point.circle.lat, point.circle.lon] = calculateEllipse(point.lat,  point.lon, radius, radius * widthFactor, 0);
        point.circle.geoshape = geoshape(point.circle.lat, point.circle.lon, 'Geometry', 'Polygon');
        geoshow(axMap(3), point.circle.geoshape, 'FaceColor', 'g', 'DisplayType', 'polygon')
    else
        point.lat = testpoints(i, 2);
        point.lon = testpoints(i, 1);
        [point.circle.lat, point.circle.lon] = calculateEllipse(point.lat,  point.lon, radius, radius * widthFactor, 0);
        point.circle.geoshape = geoshape(point.circle.lat, point.circle.lon, 'Geometry', 'Polygon');
        geoshow(axMap(3), point.circle.geoshape, 'FaceColor', 'r', 'DisplayType', 'polygon')
    end
end

hold off
axis(axMap(3),'equal');
title(append(testcounty.name, ' - plot geoshape'));

end
