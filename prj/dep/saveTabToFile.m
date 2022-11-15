function saveTabToFile(hTab, outFile, saveFigure)
%SAVETABTOFILE Save the tab handle to the specified location
%   This function consumes a plot handle an saves the it to the specified
%   location in the specified format, in case saveFigures evaluetes to
%   true.
if saveFigure
    if ~logical(exist(fileparts(outFile), 'dir'))
        mkdir(fileparts(outFile))
    end
    addpath(fileparts(outFile))
    exportgraphics(hTab, outFile, 'ContentType', 'vector');
end
end