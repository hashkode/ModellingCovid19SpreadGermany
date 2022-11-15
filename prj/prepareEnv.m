function pathHelper = prepareEnv(datasets, dependenciesPath, dataSetPath)
% add dependencies to path
addpath(genpath(dependenciesPath));

sysType = computer();
pathHelper = dataSetFilePath(dataSetPath);

switch sysType
    case 'PCWIN64'
        disp("PCWIN64")
        unpackArchives(datasets, pathHelper);
        updatePath();
    case 'MACI64'
        disp("MACI64")
        unpackArchives(datasets, pathHelper);
        updatePath();
    case 'GLNXA64'
        disp("GLNXA64")
        unpackArchives(datasets, pathHelper);
        updatePath();
    otherwise
        disp("unknown computer type")
end

% assemble paths and unpack data sets
    function unpackArchives(datasets, pathHelper)
        
        % assemble BKG data set paths
        offset = 0;        
        for i = 1:size(datasets.bkgDataSets, 1)
            datasetArchives(offset + i, 1) = pathHelper.getDataSetPath(datasets.bkgRaw, datasets.bkgDataSets(i));
            datasetArchives(offset + i, 2) = pathHelper.getDataSetPath(datasets.bkgUnpacked, datasets.bkgDataSets(i));
        end
        
        % assemble DELFI GTFS data set paths
        offset = offset + i;        
        for i = 1:size(datasets.delfiDataSets, 1)
            datasetArchives(offset + i, 1) = pathHelper.getDataSetPath(datasets.delfiRaw, datasets.delfiDataSets(i));
            datasetArchives(offset + i, 2) = pathHelper.getDataSetPath(datasets.delfiUnpacked, datasets.delfiDataSets(i));
        end

        % assemble Destatis mobility passenger data set paths
        offset = offset + i;        
        for i = 1:size(datasets.destatisMobilityPassengerDataSets, 1)
            datasetArchives(offset + i, 1) = pathHelper.getDataSetPath(datasets.destatisMobilityPassengerRaw, datasets.destatisMobilityPassengerDataSets(i));
            datasetArchives(offset + i, 2) = pathHelper.getDataSetPath(datasets.destatisMobilityPassengerUnpacked, datasets.destatisMobilityPassengerDataSets(i));
        end
        
        % assemble Destatis mobility county data set paths
        offset = offset + i;        
        for i = 1:size(datasets.destatisMobilityPassengerDataSets, 1)
            datasetArchives(offset + i, 1) = pathHelper.getDataSetPath(datasets.destatisMobilityCountyRaw, datasets.destatisMobilityCountyDataSets(i));
            datasetArchives(offset + i, 2) = pathHelper.getDataSetPath(datasets.destatisMobilityCountyUnpacked, datasets.destatisMobilityCountyDataSets(i));
        end
                
        % assemble RKI COVID-19 data set paths
        offset = offset + i;        
        for i = 1:size(datasets.rkiCovidDataSets, 1)
            datasetArchives(offset + i, 1) = pathHelper.getDataSetPath(datasets.rkiCovidRaw, datasets.rkiCovidDataSets(i));
            datasetArchives(offset + i, 2) = pathHelper.getDataSetPath(datasets.rkiCovidUnpacked, datasets.rkiCovidDataSets(i));
        end
        
        % assemble RKI COVID-19 vaccination data set paths
        offset = offset + i;
        for i = 1:size(datasets.rkiVaccinationDataSets, 1)
            datasetArchives(offset + i, 1) = pathHelper.getDataSetPath(datasets.rkiVaccinationRaw, datasets.rkiVaccinationDataSets(i));
            datasetArchives(offset + i, 2) = pathHelper.getDataSetPath(datasets.rkiVaccinationUnpacked, datasets.rkiVaccinationDataSets(i));
        end
        
        % assemble processed data set path
        offset = offset + i;
        for i = 1:size(datasets.processedDataSets, 1)
            datasetArchives(offset + i, 1) = pathHelper.getDataSetPath(datasets.processedRaw, datasets.processedDataSets(i));
            datasetArchives(offset + i, 2) = pathHelper.getDataSetPath(datasets.processedUnpacked, datasets.processedDataSets(i));
        end
        
        % unzip archives into specified directories
        for i = 1:size(datasetArchives, 1)
            if(exist(datasetArchives(i, 2), 'file'))
                disp([datasetArchives(i, 1), ' already extracted'])
            else
                unzip(datasetArchives(i, 1), datasetArchives(i, 2));
            end
        end
    end

    function updatePath()
        [path, name, ext] = fileparts(mfilename('fullpath'));
        addpath(genpath(path));
    end
end