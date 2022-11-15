function gtfs = processDelfiData(pathHelper, delfiUnpacked, delfiDataSets, fileType, nation, counties, includeAgencyList, excludeAgencyList)
%PROCESSDELFIDATA Read and process the DELFI GTFS csv files
%   This function reads the DELFI public transport data in the GTFS file
%   format specified by @pathHelper, @delfiUnpacked, @delfiDataSets and
%   @fileType. It uses auxilliary information like the geo information of
%   counties and ARS identifiers specified by @nation and @counties. The
%   parmaters @includeAgencyList and @excludeAgencyList allow to filter for
%   specific public transport agencies during the analysis.
%   The output is collected in the struct array @gtfs, which holds one
%   struct with filtered, augmented GTFS data per data set.

%% setup
% List of GTFS files that in the order, in which they have to be parsed
% considering dependencies introduced by the filter logic. Each row
% consists of the file name of the GTFS file and columns to be removed.

fileList{1} = {
    '/agency.txt', {'agency_url', 'agency_timezone', 'agency_lang', 'agency_phone'};
    '/routes.txt', {'route_short_name', 'route_long_name', 'route_color', 'route_text_color', 'route_desc'};
    '/trips.txt', {'trip_short_name', 'block_id', 'wheelchair_accessible', 'bikes_allowed'};
    '/stop_times.txt', {'pickup_type', 'drop_off_type', 'stop_headsign'};
    '/stops.txt', {'stop_code', 'stop_desc', 'wheelchair_boarding', 'platform_code', 'level'};
    '/calendar.txt', {};
    '/calendar_dates.txt', {};};
% the following files are not needed, append in case of other usecases
%'/shapes.txt', {};
%'/transfers.txt', {'transfer_type', 'from_route_id', 'to_route_id', 'from_trip_id', 'to_trip_id'};

fileList{2} = fileList{1};
idxStops = find(string(fileList{2}(:, 1)) ==  '/stops.txt', 1);
if ~isempty(idxStops)
    fileList{2}{string(fileList{2}(:, 1)) ==  '/stops.txt', 2} = {'stop_code', 'stop_desc', 'wheelchair_boarding', 'platform_code'};
end

nDelfiData = size(delfiDataSets, 1);

for i = 1:nDelfiData
    gtfs(i) = struct();
end

%% parse and filter raw data from csv files
parfor i = 1:nDelfiData
    delfiGtfsDataSetPath = append(pathHelper.getDataSetPath(delfiUnpacked, delfiDataSets(i)));
    
    fileTypeIdx = fileType(i);
    for j = 1:size(fileList{fileTypeIdx}, 1)
        % file parsing
        switch fileList{fileTypeIdx}{j, 1}
            case '/stops.txt'
                gtfsRaw = readtable(append(delfiGtfsDataSetPath, fileList{fileTypeIdx}{j, 1}), 'Delimiter', ',');
                if fileTypeIdx == 1
                    rawAuto = readtable(append(delfiGtfsDataSetPath, fileList{fileTypeIdx}{j, 1}), 'Format', 'auto');
                    gtfsRaw.parent_station = rawAuto.parent_station;
                end
            case '/stop_times.txt'
                gtfsRaw = readtable(...
                    append(delfiGtfsDataSetPath, fileList{fileTypeIdx}{j, 1}), ...
                    'Format', '%f%{H:mm:ss}D%{H:mm:ss}D%q%f%f%f%q', ...
                    'Delimiter', ',', ...
                    'ReadVariableNames', true, ...
                    'HeaderLines', 0);
            otherwise
                gtfsRaw = readtable(append(delfiGtfsDataSetPath, fileList{fileTypeIdx}{j, 1}), 'Delimiter', ',');
        end
        
        % remove superfluous columns
        if isempty(fileList{fileTypeIdx}{j, 2}) == false
            gtfsRaw = removevars(gtfsRaw, fileList{fileTypeIdx}{j, 2});
        end
        
        % filter data
        switch fileList{fileTypeIdx}{j, 1}
            case '/agency.txt'
                indexFilterMask = contains(gtfsRaw.agency_name, includeAgencyList) & ~contains(gtfsRaw.agency_name, excludeAgencyList, 'IgnoreCase', true);
                gtfsRaw = gtfsRaw(indexFilterMask, :);
            case '/routes.txt'
                agencyIds = gtfsRaw.agency_id;
                indexFilterMask = ismember(agencyIds, gtfs(i).agency.agency_id);
                % TODO: consider adding a filter based on the route_type
                % property of the routes table to filter for rail, etc.
                gtfsRaw = gtfsRaw(indexFilterMask, :);
            case '/trips.txt'
                routeIds = gtfsRaw.route_id;
                indexFilterMask = ismember(routeIds, gtfs(i).routes.route_id);
                gtfsRaw = gtfsRaw(indexFilterMask, :);
            case '/stop_times.txt'
                tripIds = gtfsRaw.trip_id;
                indexFilterMask = ismember(tripIds, gtfs(i).trips.trip_id);
                gtfsRaw = gtfsRaw(indexFilterMask, :);
            case '/stops.txt'
                stopIds = gtfsRaw.stop_id;
                indexFilterMask = ismember(stopIds, gtfs(i).stopTimes.stop_id);
                gtfsRaw = gtfsRaw(indexFilterMask, :);
            case '/calendar.txt'
                serviceIds = gtfsRaw.service_id;
                indexFilterMask = ismember(serviceIds, gtfs(i).trips.service_id);
                gtfsRaw = gtfsRaw(indexFilterMask, :);
            case '/calendar_dates.txt'
                serviceIds = gtfsRaw.service_id;
                indexFilterMask = ismember(serviceIds, gtfs(i).trips.service_id);
                gtfsRaw = gtfsRaw(indexFilterMask, :);
        end
        
        switch fileList{fileTypeIdx}{j, 1}
            case '/agency.txt'
                gtfs(i).agency = gtfsRaw;
            case '/routes.txt'
                gtfs(i).routes = gtfsRaw;
            case '/trips.txt'
                gtfs(i).trips = gtfsRaw;
            case '/stop_times.txt'
                gtfs(i).stopTimes = gtfsRaw;
            case '/stops.txt'
                gtfs(i).stops = gtfsRaw;
            case '/calendar.txt'
                gtfs(i).calendar = gtfsRaw;
            case '/calendar_dates.txt'
                gtfs(i).calendarDates = gtfsRaw;
            case '/shapes.txt'
                gtfs(i).shapes = gtfsRaw;
            case '/transfers.txt'
                gtfs(i).transfers = gtfsRaw;
        end
    end
end

%% augment stops with ARS codes
parfor i = 1:nDelfiData
    loc = gtfs(i).stops(:, {'stop_lon', 'stop_lat'}).Variables;
    
    ars = zeros(size(gtfs(i).stops, 1), 1);
    for j = 1:size(counties, 2)
        stopIdInteriorStatus = isinterior(counties(j).area.polyshape, loc);
        ars(stopIdInteriorStatus, 1) = counties(j).ars;
    end
    
    gtfs(i).stops.ars = ars;
    
    % remove entries with no matching ARS code
    [noArsRow, ~] = find(gtfs(i).stops.ars == 0);
    gtfs(i).stops(noArsRow, :) = [];

%     % uncomment and change parfor to for loop for debug purposes
%     % check ARS for codes without matching stop_id and vice-versa
%     missingArs = setdiff(nation.county.bkg250KrsArs, ars);
%     
%     for j = 1:size(ars, 1)
%         matchedArs(j) = 1 - isequal(ars(j), 0);
%     end
%     
%     nonMatchedStops(i) = numel(find(matchedArs == 0));
%     
%     for j = 1:size(gtfs(i).stops, 1)
%         if matchedArs(j) == 0
%             disp(gtfs(i).stops(j, {'stop_id', 'stop_name'}).Variables)
%         end
%     end
%     
%     for j = 1:size(missingArs, 1)
%         idxCounty = find(nation.county.bkg250KrsArs == missingArs(j));
%         disp(counties(idxCounty).name)
%     end
end

%% augment stopTimes with ARS codes
for i = 1:nDelfiData
    ars = zeros(size(gtfs(i).stopTimes, 1), 1);
    parfor j = 1:size(gtfs(i).stopTimes, 1)
        [stopRow, ~] = find(string(gtfs(i).stopTimes(j, 'stop_id').Variables) == string(gtfs(i).stops(:, {'stop_id'}).Variables));
        
        if ~isempty(stopRow)
            ars(j, 1) = gtfs(i).stops(stopRow, {'ars'}).Variables;
        end
    end
    
    gtfs(i).stopTimes.ars = ars;
    
    % remove entries with no matching ARS code
    [noArsRow, ~] = find(gtfs(i).stopTimes.ars == 0);
    gtfs(i).stopTimes(noArsRow, :) = [];
end
end
