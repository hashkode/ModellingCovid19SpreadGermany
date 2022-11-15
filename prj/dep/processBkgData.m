function nation = processBkgData(bkg250KrsShapePath)
%PROCESSBKGDATA Process the BKG data using the projection information.
%   This function process the BKG data @bkg250KrsShapePath and calculates
%   the latitude/longitude tuples using the projection information in the
%   parameter bkgDataInfo. Additionally, it removes auxilliary county
%   entries, which indicate water areas and are not of interest for the
%   COVID-19 analysis.
%   The result is returned in the struct @nation.

bkgData = shaperead(bkg250KrsShapePath);
bkgDataInfo = shapeinfo(bkg250KrsShapePath);

% process coordinates
warPolyshape = 'MATLAB:polyshape:repairedBySimplify';
warning('off', warPolyshape)
for i = 1:size(bkgData,1)
    % invert coordinate projection to yield latitude, longitude
    [bkgData(i).Lat, bkgData(i).Lon] = projinv(bkgDataInfo.CoordinateReferenceSystem, bkgData(i).X, bkgData(i).Y);
    % attach a polyshape and geoshape of the county
    bkgData(i).Polyshape = polyshape(bkgData(i).Lon, bkgData(i).Lat);
    bkgData(i).Geoshape = geoshape(bkgData(i));
end
warning('on', warPolyshape)

bkg250KrsArs = str2double(string(cell2mat(extractfield(bkgData, 'ARS')')));

% tidy special characters in names in BKG data
for i = 1:size(bkgData, 1)
    bkgData(i).GEN = native2unicode(double(char(bkgData(i).GEN)), 'UTF-8');
    bkgData(i).GEN = strrep(bkgData(i).GEN, '��', 'ß');
end

% determine duplicate entries in BKG data, as they indicate water ares,
% which are not of interest for COVID analysis
% from: https://stackoverflow.com/questions/44572449/matlab-find-and-number-duplicates-within-an-array
[~, ia, ic] = unique(bkg250KrsArs, 'stable');
[~, idxDuplicate] = ismember(bkg250KrsArs, bkg250KrsArs(ia(accumarray(ic,1)>1)));

idxSingle = idxDuplicate;
for i = 1:max(idxDuplicate)
    idxDup = find(idxDuplicate == i);
    idxSingle(min(idxDup)) = 0;
end

% remove duplicate entries and prepare output structure
nation.county.bkg250KrsArs = bkg250KrsArs(idxSingle == 0);
nation.lat.min = min(extractfield(bkgData,'Lat'));
nation.lat.max = max(extractfield(bkgData,'Lat'));
nation.lon.min = min(extractfield(bkgData,'Lon'));
nation.lon.max = max(extractfield(bkgData,'Lon'));
nation.county.bkgData = bkgData(idxSingle == 0);

end
