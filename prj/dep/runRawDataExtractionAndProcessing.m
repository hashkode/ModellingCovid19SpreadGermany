function [nation, counties] = runRawDataExtractionAndProcessing(datasets, pathHelper, procSettings)
%RUNRAWDATAEXTRACTIONANDPROCESSING Extract and process als raw data sets
%   This function extracts, processes and fuses the data sets used for the
%   networked SEIR model approach. The data sets are specified by
%   @datasets, their location by @pathHelper and the processing can be
%   tuned with @procSettings.
%   The extracted data are grouped in two structs @nation and @county
%   indicating on which level/granularity the data is provided.

%% data pre-processing - BKG shape data
disp("##> data pre-processing - BKG shape data")
tStartSection = tic;
if exist('nation', 'var') == false
    bkg250KrsShapeName = '/vg250-ew_12-31.utm32s.shape.ebenen/vg250-ew_ebenen_1231/VG250_KRS.shp';
    bkgDataPath = append(pathHelper.getDataSetPath(datasets.bkgUnpacked, datasets.bkgDataSets), bkg250KrsShapeName);
    nation = processBkgData(bkgDataPath);
    clear bkg250KrsShapeName bkgDataPath
end
tEndSection = toc(tStartSection);
disp(append("Subsection runtime: ", string(tEndSection), "s"))

%% data pre-processing - Destatis mobility passenger data
disp("##> data pre-processing - Destatis mobility passenger data")
tStartSection = tic;
% check if mobility is already available
runDestatisProcessing = false;
if isfield(nation, 'mobility') == false
    runDestatisProcessing = true;
else
    if isfield(nation.mobility, 'passenger') == false
        runDestatisProcessing = true;
    end
end

if runDestatisProcessing
    % use only most recent Destatis mobility passenger data set
    destatisFileName = datasets.destatisMobilityPassengerDataSets(end);
    destatisDataPath = append(pathHelper.getDataSetPath(datasets.destatisMobilityPassengerUnpacked, datasets.destatisMobilityPassengerDataSets(end)), '/', destatisFileName);
    nation.mobility.passenger = processDestatisMobilityPassengerData(destatisDataPath);
    clear destatisFileName destatisDataPath
end
clear runDestatisProcessing
tEndSection = toc(tStartSection);
disp(append("Subsection runtime: ", string(tEndSection), "s"))

%% data pre-processing - Destatis mobility county data
disp("##> data pre-processing - Destatis mobility county data")
tStartSection = tic;
% check if mobility is already available
runDestatisProcessing = false;
if isfield(nation, 'county') == false
    runDestatisProcessing = true;
else
    if isfield(nation.county, 'mobility') == false
        runDestatisProcessing = true;
    end
end

if runDestatisProcessing
    % use only most recent Destatis mobility county data set
    destatisFileName = datasets.destatisMobilityCountyDataSets(end);
    destatisDataPath = append(pathHelper.getDataSetPath(datasets.destatisMobilityCountyUnpacked, datasets.destatisMobilityCountyDataSets(end)), '/', destatisFileName);
    nation.county.mobility = processDestatisMobilityCountyData(destatisDataPath);
    clear destatisFileName destatisDataPath
end
clear runDestatisProcessing
tEndSection = toc(tStartSection);
disp(append("Subsection runtime: ", string(tEndSection), "s"))

%% data pre-processing - RKI COVID-19 data
disp("##> data pre-processing - RKI COVID-19 data")
tStartSection = tic;
if isfield(nation.county, 'rkiCovid') == false
    % use only most recent RKI COVID-19 data set
    rkiFileName = datasets.rkiCovidDataSets(end);
    rkiDataPath = append(pathHelper.getDataSetPath(datasets.rkiCovidUnpacked, datasets.rkiCovidDataSets(end)), '/', rkiFileName);
    nation.county.rkiCovid = processRkiCovidData(rkiDataPath, nation);
    clear rkiFileName rkiDataPath
end
tEndSection = toc(tStartSection);
disp(append("Subsection runtime: ", string(tEndSection), "s"))

%% data pre-processing - RKI COVID-19 vaccination data
disp("##> data pre-processing - RKI COVID-19 vaccination data")
tStartSection = tic;
if isfield(nation, 'rkiCovidVac') == false
    % use only most recent RKI COVID-19 vaccination data set
    rkiFileName = datasets.rkiVaccinationDataSets(end);
    rkiDataPath = append(pathHelper.getDataSetPath(datasets.rkiVaccinationUnpacked, datasets.rkiVaccinationDataSets(end)), '/', rkiFileName);
    nation.rkiCovidVac = processRkiCovidVacData(rkiDataPath);
    clear rkiFileName rkiDataPath
end
tEndSection = toc(tStartSection);
disp(append("Subsection runtime: ", string(tEndSection), "s"))

%% extract data per county - all counties
disp("##> extract data per county - all counties")
tStartSection = tic;
if exist('counties', 'var') == false
    counties = extractCountyData(nation);
    
    % extract number of residents per county as vector
    nation.county.residents = [counties(:).residents];
    nation.county.size = [counties(:).area];
    nation.county.size = [nation.county.size(:).size];
end
tEndSection = toc(tStartSection);
disp(append("Subsection runtime: ", string(tEndSection), "s"))

%% data pre-processing - DELFI GTFS data
disp("##> data pre-processing - DELFI GTFS data")
tStartSection = tic;
if exist('delfiGtfs', 'var') == false
    delfiGtfs = processDelfiData(pathHelper, datasets.delfiUnpacked, datasets.delfiDataSets, procSettings.fileTypeGtfs, nation, counties, procSettings.includeAgencyList, procSettings.excludeAgencyList);
    clear fileList
end
tEndSection = toc(tStartSection);
disp(append("Subsection runtime: ", string(tEndSection), "s"))

if procSettings.verbosity
    disp("--> DELFI GTFS data size")
    s = whos('delfiGtfs');
    disp(append("whos on delfiGtfs yielded ", num2str(s.bytes/(1e9)), " GB bytesize"))
    clear s
    fNames = fieldnames(delfiGtfs);
    
    for i = 1:size(fNames, 1)
        disp(append("---> ", fNames(i)))
        
        for j = 1:size(delfiGtfs, 2)
            eval(append("tmp = delfiGtfs(j).", fNames(i), ";"));
            s = whos('tmp');
            disp(append("whos on delfiGtfs(", num2str(j), ") yielded ", num2str(s.bytes/(1e6)), " MB bytesize"))
            clear tmp s
        end
    end
end

%% calculate adjacency matrix
disp("##> calculuate adjacency matrix")
tStartSection = tic;
% check if mobility is already available
runAdjacencyProcessing = false;
if isfield(nation, 'mobility') == false
    runAdjacencyProcessing = true;
else
    if isfield(nation.mobility, 'daily') == false
        runAdjacencyProcessing = true;
    end
end

if runAdjacencyProcessing
    % prepare transient county adjacency matrix
    nation.mobility.daily = calculateDailyCountyAdjacency(delfiGtfs, nation);
end
clear runAdjacencyProcessing
tEndSection = toc(tStartSection);
disp(append("Subsection runtime: ", string(tEndSection), "s"))
end
