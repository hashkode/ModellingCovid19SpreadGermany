clearvars -except nation counties datasets pathHelper
close all
tStart = tic;
curTime = string(datetime(now, 'ConvertFrom', 'datenum', 'Format', 'yyMMdd_HHmmss'));

%% settings
% enable detailed outputs
verbosity = false;

%%% preprocessing settings
% switch to enable a rerun of preprocessing
rerunPreProcessing = false;
% specify the filter masks to include/exclude agencies in the filter logic
procSettings.includeAgencyList = ["DB"];
procSettings.excludeAgencyList = ["Bus"];
% specify the GTFS data set type as described in the documentation of
% processDelfiData; should match to the entries of "datasets.delfiDataSets"
procSettings.fileTypeGtfs = [1, 2, 2];
procSettings.verbosity = verbosity;

%%% SEIR model simulation settings
% configure days for state transition to removed (lag), death (lag) and exposed (lead)
seirSettings.tLagRemoved = 7;
seirSettings.tLagDeath = 7;
seirSettings.tLeadExposed = 7;
% configure smooth window to reduce spikes in infected and removed data
% estimation
seirSettings.tSmoothCases = 7;
% configure sampling rate h
seirSettings.h = 1;
% switch to enable use of vaccination data
seirSettings.considerVaccinationData = false;
% timerange to simulate
seirSettings.dateStart = datetime("2020-01-01");
seirSettings.dateEnd = today('datetime');
% select counties for SEIR simulation, all or subset; leave empty to use
% all counties
seirSettings.countiesList = [];%[9162, 6611, 11000, 6633, 3153, 3154];
% select which data set to use for mobility behavior, 'nation', 'county',
% 'combined'
seirSettings.mobilityLevel = 'combined';
% specify threshold of population density to remove low density counties in
% analysis in people/km^2
seirSettings.rPopulation = 0;
% enable plot saving to files
seirSettings.saveFigures = true;
% counterfactual simulation settings
seirSettings.counterfactual.type = 'cappedTop';
seirSettings.counterfactual.value = .5;
% misc.
seirSettings.timeSimStart = curTime;

% select which wave to simulate
wave = 0;

switch wave
    case 0
        % use maximum available date range
        seirSettings.dateStart = datetime("2020-02-01");
    case 1
        seirSettings.dateStart = datetime("2020-02-01");
        seirSettings.dateEnd = datetime("2020-09-01");
    case 2
        seirSettings.dateStart = datetime("2020-09-01");
        seirSettings.dateEnd = datetime("2021-03-15");
    case 3
        seirSettings.dateStart = datetime("2021-03-15");
        seirSettings.dateEnd = datetime("2021-08-15");
    case 23 % wave 2 and 3 combined
        seirSettings.dateStart = datetime("2020-09-01");
        seirSettings.dateEnd = datetime("2021-08-15");
end

%%% data plot settings
% switch to enable data plots with COVID-19 data and interior point check
enableDataPlots = false;
% specifcy the ARS codes used for COVID-19 data plots
arsList = [9162, 6611, 11000, 8111];
% specify the ARS code used for interior point check with BKG data
arsCodeIPC = 8111;
% specify test points to test drive the interior point check with BKG data
testpointsIPC = [...
    % testpoint for TUM EI faculty Campus Munich
    11.566184, 48.1503276; ...
    % testpoint for TUM Campus Garching
    11.6700987, 48.2652254];

%% setup data sets and related paths
disp("#> setup")
tStartSection = tic;

if exist('pathHelper', 'var') == false
    [path, ~, ~] = fileparts(mfilename('fullpath'));
    % add dependencies to path
    addpath(genpath(strcat(pwd, '/dep')));
    
    % define file paths
    % dictionary with zip archive path and target directory path
    datasets.bkgRaw = "raw/covid-data/data/bkg/";
    datasets.bkgUnpacked = "unpacked/covid-data/data/bkg/";
    datasets.bkgDataSets = ["vg250-ew_12-31.utm32s.shape.ebenen"];
    
    datasets.delfiRaw = "raw/covid-data/data/delfi/";
    datasets.delfiUnpacked = "unpacked/covid-data/data/delfi/";
    datasets.delfiDataSets = [
        "20200401_fahrplaene_gesamtdeutschland_gtfs";
        "20201210_fahrplaene_gesamtdeutschland_gtfs";
        "20210423_fahrplaene_gesamtdeutschland_gtfs"];
    
    datasets.destatisMobilityPassengerRaw = "raw/covid-data/data/destatis/";
    datasets.destatisMobilityPassengerUnpacked = "unpacked/covid-data/data/destatis/";
    datasets.destatisMobilityPassengerDataSets = ["mobilitaet_personenverkehr_20210623"];
    
    datasets.destatisMobilityCountyRaw = "raw/covid-data/data/destatis/";
    datasets.destatisMobilityCountyUnpacked = "unpacked/covid-data/data/destatis/";
    datasets.destatisMobilityCountyDataSets = ["Veränderungsraten_Mobilität_Kreise_20210722"];
    
    datasets.rkiCovidRaw = "raw/covid-data/data/rki/";
    datasets.rkiCovidUnpacked = "unpacked/covid-data/data/rki/";
    datasets.rkiCovidDataSets = [
        "RKI_COVID19_20200101-20200507";
        "RKI_COVID19_20200101-20210626";
        "RKI_COVID19_20200101-20210820"];
    
    datasets.rkiVaccinationRaw = "raw/covid-data/data/rki/";
    datasets.rkiVaccinationUnpacked = "unpacked/covid-data/data/rki/";
    datasets.rkiVaccinationDataSets = ["Impfquotenmonitoring_20210625"];
    
    datasets.processedRaw = "processed/";
    datasets.processedUnpacked = "unpacked/processed/";
    datasets.processedDataSets = ["GermanyCountyCovid_DB"];
    
    % update path and extract archives
    pathHelper = prepareEnv(datasets, append(path, "/dep/"), append(path, "/dat/"));
    clear path
end
tEndSection = toc(tStartSection);
disp(append("Section runtime: ", string(tEndSection), "s"))

%% extract and process raw data if not available from disk
disp("#> data preprocessing/.mat file loading")
tStartSection = tic;
processedDataFileName = append('/', datasets.processedDataSets(end), '.mat');
% check if .mat file with processed data exists or rerun is enabled
if ~logical(exist(append(pathHelper.getDataSetPath(datasets.processedUnpacked, datasets.processedDataSets(end)), processedDataFileName), 'file')) || rerunPreProcessing
    [nation, counties] = runRawDataExtractionAndProcessing(datasets, pathHelper, procSettings);
else
    % check if data variables are already in workspace
    if ~exist('nation', 'var') || ~exist('counties', 'var')
        load(append(pathHelper.getDataSetPath(datasets.processedUnpacked, datasets.processedDataSets(end)), processedDataFileName))
    end
end
tEndSection = toc(tStartSection);
disp(append("Section runtime: ", string(tEndSection), "s"))

%% run SEIR model
disp("#> run SEIR model")
tStartSection = tic;

if isempty(seirSettings.countiesList)
    seirSettings.countiesList = nation.county.bkg250KrsArs;
end

% run SEIR simulation and store model parameters and error metrics
modelSEIR = runSeirModel(nation, counties, seirSettings);
if seirSettings.saveFigures
    save(append("./SEIR_sim_outputs/", curTime, '/modelSEIR_', string(datetime(now, 'ConvertFrom', 'datenum', 'Format', 'yyMMdd_HHmmss'))), 'modelSEIR');
end
tEndSection = toc(tStartSection);
disp(append("Section runtime: ", string(tEndSection), "s"))

%% call plot scripts
if enableDataPlots
    disp("#> call plot scripts")
    tStartSection = tic;
    
    plotCovidData(nation, counties, arsList, seirSettings);
    
    idxCountyIPC = find(nation.county.bkg250KrsArs == arsCodeIPC);
    testpointInteriorStatus = isinterior(counties(idxCountyIPC).area.polyshape, testpointsIPC);
    plotMapData(nation, counties(idxCountyIPC), testpointsIPC, testpointInteriorStatus, seirSettings);
    tEndSection = toc(tStartSection);
    disp(append("Section runtime: ", string(tEndSection), "s"))
end

%% wrap-up
tEnd = toc(tStart);
disp(append("Total runtime: ", string(tEnd), "s"))