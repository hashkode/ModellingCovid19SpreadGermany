function ars = mergeArsIDs(ars, destArs, sourceArsList)
%MERGEARSIDS Merge a list of ARS ids to a single ARS id
%   This function checks if ars is part of the sourceArsList value and if
%   so, replaces it with destArs.
if ~isempty(intersect(ars, sourceArsList))
    ars = destArs;
end
end
