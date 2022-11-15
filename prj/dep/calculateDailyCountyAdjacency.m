function dailyAdjacency = calculateDailyCountyAdjacency(gtfs, nation)
%CALCULATEDAILYADJACENCY Process the DELFI GTFS data to daily adj. matrices
%   This function processes the DELFI data in the GTFS format @gtfs with
%   the help of the geo information from bkg in the struct @nation. It
%   outputs a cell array @dailyAdjancency with two cells @timeVector and
%   @adjacency. The first is a vector of datetime entries related to the
%   third dimension of the second cell, which is a 3d matrix of transient,
%   daily adjacencies. (dimensions: start county, target county, date)

% select normalization to apply to the adjacency data; normalize to
% 1: maximum coefficient per day, 2: maximum sum of coefficients per row
% (county), 3: sum of coefficients per row per day (yields stochastic mat.)
normalization = 2;

nDelfiData = size(gtfs, 2);

%% calculate adjacency matrix
dailyAdjacency = cell(nDelfiData, 1);
parfor i = 1:nDelfiData
    % determine start and end date and build time vector
    dateStart = datetime(string(min(gtfs(i).calendar(:, 'start_date').Variables)), 'InputFormat', 'yyyyMMdd');
    dateEnd = datetime(string(max(gtfs(i).calendar(:, 'end_date').Variables)), 'InputFormat', 'yyyyMMdd');
    timeVector = [dateStart:dateEnd]';
    % retrieve all service_id values from calendar table 
    serviceIds = sort(gtfs(i).calendar(:, 'service_id').Variables);
    % determine weekday vector for time vector to use with schedule data
    serviceWeekdays = weekday(timeVector);
    serviceWeekdays = serviceWeekdays - 1;
    serviceWeekdays(serviceWeekdays == 0) = 7;
    
    % preallocate variables
    serviceDaily = zeros(size(timeVector, 1), size(serviceIds, 1));
    adjacencyDaily = zeros(size(nation.county.bkg250KrsArs, 1), size(nation.county.bkg250KrsArs, 1), size(timeVector, 1));
    
    % retrieve service status based on cyclic schedule
    for j = 1:size(gtfs(i).calendar, 1)
        for k = 1:7
            serviceStatus = gtfs(i).calendar(j, k + 1).Variables;
            [rowService, ~] = find(serviceWeekdays == k);
            serviceDaily(rowService, j) = serviceStatus;
        end
    end
    
    % compensate service exceptions in daily service status
    for j = 1:size(gtfs(i).calendarDates, 1)
        exception = gtfs(i).calendarDates(j, {'service_id', 'date', 'exception_type'}).Variables;
        exceptionDate = datetime(string(exception(2)), 'InputFormat', 'yyyyMMdd');
        exceptionServiceId = exception(1);
        [~, columnService] = find(serviceIds' == exceptionServiceId);
        [rowService, ~] = find(timeVector == exceptionDate);
        exceptionStatus = exception(3);
        switch exceptionStatus
            case 1
                serviceDaily(rowService, columnService) = 1;
            case 2
                serviceDaily(rowService, columnService) = 0;
            otherwise
                warning(append("unknown 'exception_type' in GTFS 'calendar_dates.txt' data set #", num2str(i), " at row#", num2str(j)))
        end
    end
    
    % build adjacency matrix from service schedule data combined with stops
    % per trip and their ARS code
    stopTimes = gtfs(i).stopTimes(:, {'trip_id', 'ars'}).Variables;
    for j = 1:size(gtfs(i).trips, 1)
        trip = gtfs(i).trips(j, {'trip_id', 'service_id'}).Variables;
        tripId = trip(1);
        [rowStopTimes, ~] = find(stopTimes(:, 1) == tripId);
        tripServiceId = trip(2);
        [~, columnService] = find(serviceIds' == tripServiceId);
        arsVector = stopTimes(rowStopTimes, 2);
        serviceStatus = serviceDaily(:, columnService);
        
        idxArsVector = zeros(size(arsVector, 1), 1);
        for k = 1:size(idxArsVector, 1)
            idxArsVector(k) = find(nation.county.bkg250KrsArs == arsVector(k));
        end
        
        for k = 1:size(idxArsVector, 1)
            for l = k:size(idxArsVector, 1)
                adjacencyDaily(idxArsVector(k), idxArsVector(l), serviceStatus == 1) = adjacencyDaily(idxArsVector(k), idxArsVector(l), serviceStatus == 1) + 1;
            end
        end
    end
    
     % normalize adjacency factors per maximum per service day
     if normalization == 1
         for j = 1:size(adjacencyDaily, 3)
             adjacencyDaily(:, :, j) = adjacencyDaily(:, :, j)/max(adjacencyDaily(:, :, j), [], 'all');
         end
     end
    
    dailyAdjacency{i} = {adjacencyDaily, timeVector};
end

% merge adjacency matrices from different DELFI GTFS data sets, considering
% the most recent data as superior
timeVector = [];
adjacency = [];
for i = 1:nDelfiData
    idx = nDelfiData - i + 1;
    dailyTimeVector = dailyAdjacency{idx}{2};
    if isempty(timeVector)
        timeVector = dailyTimeVector;
        adjacency = dailyAdjacency{idx}{1};
    else
        [newDataTimeVector, idxNewData] = setdiff(dailyTimeVector, timeVector);
        timeVector = [newDataTimeVector; timeVector];
        adjacency = cat(3, dailyAdjacency{1}{1}(:, :, idxNewData), adjacency);
    end
end

% normalize adjacency factors by maximum of sum per row (county)
if normalization == 2
    maxRow = sum(adjacency(:, :, :), 2);
    maxRow = max(maxRow, [], 3);
    
    for i = 1:size(adjacency, 3)
        adjacency(:, :, i) = adjacency(:, :, i)./maxRow;
    end
end

% normalize adjacency factors by sum per row (county) per day
if normalization == 3
    for i = 1:size(adjacency, 3)
        maxRow = sum(adjacency(:, :, i), 2);
        adjacency(:, :, i) = adjacency(:, :, i)./maxRow;
    end
end


adjacency(isnan(adjacency)) = 0;

dailyAdjacency = {timeVector, adjacency};
end
