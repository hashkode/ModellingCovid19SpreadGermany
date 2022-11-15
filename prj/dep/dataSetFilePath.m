classdef dataSetFilePath
    %DATASETFILEPATH A class to assemble data set filepaths
    %   The class provides a basePath property to keep track of the global
    %   data set storage location. The method getDataSetPath then assembles
    %   the basePath property, the dataSetRoot (in case the data sets are
    %   grouped) and the dataSetName and returns the combined string.
    
    properties
        basePath
    end
    
    methods
        function obj = dataSetFilePath(basePath)
            %DATASETFILEPATH Construct an instance of this class
            %   Initialise basePath property
            obj.basePath = basePath;
        end
        
        function filepath = getDataSetPath(obj, dataSetRoot, dataSetName)
            %GETDATASETPATH Construct an instance of this class
            %   Join basePath with data set group path and data set name
            filepath = strcat(obj.basePath, dataSetRoot, dataSetName);
        end
    end
end

