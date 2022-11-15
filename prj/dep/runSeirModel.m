function modelSEIR = runSeirModel(nation, counties, seirSettings)
%RUNSEIRMODEL Estimate networked SEIR model parameters and run simulation
%   This function prepares input data based on @nation, @counties and
%   @seirSettings to calibrate and test/simulate a networked SEIR model
%   using COVID-19 pandemic information alongside network layout and
%   behavior data.
%   The fitted model alongside error metrics are aggregated and returned in
%   the struct @modelSEIR and allow further analysis using e.g. different
%   behavior vectors.

%% setup
% covid data related parameters
tLagRem = seirSettings.tLagRemoved;
tLagDth = seirSettings.tLagDeath;
tLeadExp = seirSettings.tLeadExposed;
tSmooth = seirSettings.tSmoothCases;
rPopulation = seirSettings.rPopulation;
h = seirSettings.h;
considerVacData = seirSettings.considerVaccinationData;
counterfactual = seirSettings.counterfactual;

% simulation time
timevectorSimulation = seirSettings.dateStart:seirSettings.dateEnd;
% counties to use for simulation
countiesList = seirSettings.countiesList;

% configure plots
yLimRange = [0 0.1];
fAspectRatio = [3 2 1];
timeSimStart = seirSettings.timeSimStart;
saveFigures = seirSettings.saveFigures;

% miscellaneous configuration
normPower = 2;

%% calculate input parameters
% normalize accumulated RKI case data by number of residents
confirmedNorm = nation.county.rkiCovid.accumulated{1, 1}.Variables ./ nation.county.residents;
recoveredNorm = nation.county.rkiCovid.accumulated{1, 2}.Variables ./ nation.county.residents;
deathsNorm = nation.county.rkiCovid.accumulated{1, 3}.Variables ./ nation.county.residents;

if considerVacData
    vaccinatedNorm = zeros(size(counties(1).cases.vaccinationSecondAcc, 1), size(counties, 2));
    for i = 1:size(counties, 2)
        vaccinatedNorm(:, i) = counties(i).cases.vaccinationSecondAcc;
    end
    
    vaccinatedNorm = vaccinatedNorm ./ nation.county.residents;
end

% prepare static county adjacency matrix
A = zeros(size(nation.county.bkg250KrsArs, 1));
for i = 1:size(nation.county.bkg250KrsArs, 1)
    for j = 1:size(nation.county.bkg250KrsArs, 1)
        A(i, j) = ~eq(sum(ismember(counties(i).area.polyshape.Vertices, counties(j).area.polyshape.Vertices), 'all'), 0);
    end
end

A = double(A);
% subtract eye matrix to remove possible intra county adjacency factors
A1 = A - eye(size(nation.county.bkg250KrsArs, 1));
A1(A1 < 0) = 0;

% determine policy data vectors
mobilityCounty = 1 + nation.county.mobility.Variables ./ 100;
mobilityCountyArs = str2double(nation.county.mobility.Properties.VariableNames);

if ~isequal(mobilityCountyArs, nation.county.bkg250KrsArs')
    error('ARS codes of BKG and RKI data do not match with DESTATIS data.')
end

railUsage = 1 + nation.mobility.passenger.rail ./ 100;

%% determine simulation input data for the individual compartments
idxSelectedCounties = find(ismember(nation.county.bkg250KrsArs, countiesList));

% filter by population density
populationDensity = nation.county.residents./nation.county.size;
populationDensity = populationDensity(idxSelectedCounties);

rank = zeros(length(populationDensity), 1);
rank(populationDensity > rPopulation) = 1;
rank(populationDensity <= rPopulation & populationDensity >= 0) = 2;

idxSelectedCounties = idxSelectedCounties(rank == 1);

% Special case, eliminate counties with zero cases
zero_col = find(all(confirmedNorm(:, idxSelectedCounties) == 0));
if ~isempty(zero_col)
    zeroCounties = countiesList(zero_col);
    idxSelectedCounties(zero_col, :)=[];
end

% confirmed cases data
confirmedCounty = confirmedNorm(:, idxSelectedCounties);
confirmedCounty = makeColumnsMonotonous(confirmedCounty);

% death cases data
deathsCounty = deathsNorm(:, idxSelectedCounties);
deathsCounty = makeColumnsMonotonous(deathsCounty);

% recovered cases data
recoveredCounty = recoveredNorm(:, idxSelectedCounties);
recoveredCounty = makeColumnsMonotonous(recoveredCounty);

% fully vaccinated cases data
if considerVacData
    vaccinatedCounty = vaccinatedNorm(:, idxSelectedCounties);
end

% estimate removed compartment
[nDate, nCounty] = size(confirmedCounty);
if tLagRem == 0 && tLagDth == 0
    simInRemCnty = recoveredCounty + deathsCounty;
else
    simInRemCnty = zeros(nDate, nCounty);
    for iDate = (tLagRem+1):nDate
        simInRemCnty(iDate, :) = recoveredCounty(iDate - tLagRem, :);
    end
    
    for iDate = (tLagDth+1):nDate
        simInRemCnty(iDate, :) = simInRemCnty(iDate, :) + deathsCounty(iDate - tLagDth, :);
    end
end

% bound removed compartment to 0
simInRemCnty(simInRemCnty < 0) = 0;
simInRemCnty = smoothdata(simInRemCnty, 1, 'movmean', tSmooth);
simInRemCnty = makeColumnsMonotonous(simInRemCnty);

% estimate infectious compartment
simInInfCnty = smoothdata(confirmedCounty - simInRemCnty, 1, 'movmean', tSmooth);
simInInfCnty(simInInfCnty < 1e-15) = 0;

% estimate exposed compartment
simInExpCnty = zeros(nDate, nCounty);
for i = 1:(nDate - tLeadExp)
    simInExpCnty(i, :) = simInInfCnty(i + tLeadExp, :);
end
simInExpCnty(simInExpCnty < 0) = 0;

%% reduce simulation input data to simulation time range
% determine joint time range of mobility, covid and behavioral data
timevectorA3 = nation.mobility.daily{1};
timevectorRki = nation.county.rkiCovid.daily{1}.Properties.RowTimes;

switch seirSettings.mobilityLevel
    case 'county'
    timevectorDestatis = nation.county.mobility.Time;
    case 'nation'
    timevectorDestatis = nation.mobility.passenger.Time;
    case 'combined'
    timevectorDestatis = intersect(nation.mobility.passenger.Time, nation.county.mobility.Time);
end

[timevectorJoint, ~, ~] = intersect(timevectorRki, timevectorA3);
[timevectorJoint, ~, ~] = intersect(timevectorJoint, timevectorDestatis);
[timevectorJoint, ~, ~] = intersect(timevectorJoint, timevectorSimulation);

% simulation time
dateStart = min(timevectorJoint);
dateEnd = max(timevectorJoint);
dateRange = days(dateEnd - dateStart);

% determine indexes of joint time in individual data sets
[~, idxRki, ~] = intersect(timevectorRki, timevectorJoint);
[~, idxA3, ~] = intersect(timevectorA3, timevectorJoint);
[~, idxDestatis, ~] = intersect(timevectorDestatis, timevectorJoint);

% reduce simulation input data to simulation data range
A3 = nation.mobility.daily{2}(:, :, idxA3);
simInInfCnty = simInInfCnty(idxRki, :);
simInRemCnty = simInRemCnty(idxRki, :);
simInExpCnty = simInExpCnty(idxRki, :);

% assemble policy bevahior vector
switch seirSettings.mobilityLevel
    case 'county'
        behavior = mobilityCounty(idxDestatis, idxSelectedCounties);
    case 'nation'
        behavior = railUsage(idxDestatis);
    case 'combined'
        behavior = mobilityCounty(idxDestatis, idxSelectedCounties);
        simInBehavior = repmat({behavior}, 2, 1);
        behavior = railUsage(idxDestatis);
        behavior = repmat(behavior, 1, size(mobilityCounty(idxDestatis, idxSelectedCounties), 2));
        simInBehavior{3} = behavior;
end

switch counterfactual.type
    case 'fixed'
        behaviorCounterfactual = ones(size(behavior, 1), 1) * counterfactual.value;
    case 'scaled'
        behaviorCounterfactual = behavior * counterfactual.value;
    case 'cappedTop'
        behaviorCounterfactual = behavior;
        behaviorCounterfactual(behaviorCounterfactual >= counterfactual.value) = counterfactual.value;
end

if isequal(seirSettings.mobilityLevel, 'county') || isequal(seirSettings.mobilityLevel, 'nation')
    simInBehavior = repmat({behavior}, 3, 1);
end
simInBehaviorCF = simInBehavior;
simInBehaviorCF{3} = behaviorCounterfactual;



% reduce adjacency matrices
A1 = A1(idxSelectedCounties, idxSelectedCounties);
A3 = A3(idxSelectedCounties, idxSelectedCounties, :);

%% SEIR regional
% fit SEIR model
[betaE, betaI, sigma, gamma, betaGammaMu] = calibrateSeirModel(h, A1, A3, simInInfCnty(1:end-tLeadExp, :), simInRemCnty(1:end-tLeadExp, :), simInExpCnty(1:end-tLeadExp, :), tLeadExp, simInBehavior);
model.betaI = betaI;
model.betaE = betaE;
model.sigma = sigma;
model.gamma = gamma;
model.betaGammaMu = betaGammaMu;

% simulate selected duration
[simInf, simRem, simExp] = simulateSeirModel(h, betaE, betaI, sigma, gamma, A1, A3, simInInfCnty(1, :), simInRemCnty(1, :), simInExpCnty(1, :), dateRange, simInBehavior);

% simulate counterfactual for selected duration
[simInfCF, simRemCF, simExpCF] = simulateSeirModel(h, betaE, betaI, sigma, gamma, A1, A3, simInInfCnty(1, :), simInRemCnty(1, :), simInExpCnty(1, :), dateRange, simInBehaviorCF);

% determine start and end date and timevector to compare real data with
% simulation data
idxTimeStartJoint = find(timevectorJoint == dateStart);
% omit last element, as simulation yields n-1 elements
idxTimeEndJoint = find(timevectorJoint == dateEnd) - 1;
dateRangeJoint = timevectorJoint(idxTimeStartJoint:idxTimeEndJoint);

% retrieve infectious data
realInf = simInInfCnty(idxTimeStartJoint:idxTimeEndJoint, :);
simInf = simInf(idxTimeStartJoint:idxTimeEndJoint, :);
simInfCF = simInfCF(idxTimeStartJoint:idxTimeEndJoint, :);

% retrieve removed data
realRem = simInRemCnty(idxTimeStartJoint:idxTimeEndJoint, :);
simRem = simRem(idxTimeStartJoint:idxTimeEndJoint, :);
simRemCF = simRemCF(idxTimeStartJoint:idxTimeEndJoint, :);

% retrieve exposed data
realExp = simInExpCnty(idxTimeStartJoint:(idxTimeEndJoint - tLeadExp), :);
simExp = simExp(idxTimeStartJoint:(idxTimeEndJoint - tLeadExp), :);
simExpCF = simExpCF(idxTimeStartJoint:(idxTimeEndJoint - tLeadExp), :);

% aggregate input and output data
data.realInf = realInf;
data.simInf = simInf;
data.simInfCF = simInfCF;
data.realRem = realRem;
data.simRem = simRem;
data.simRemCF = simRemCF;
data.realExp = realExp;
data.simExp = simExp;
data.simExpCF = simExpCF;

%% create and save figures
% plot preparations
[~, numCounties] = size(simInf);

newcolors = [...
    0.0000 0.4470 0.7410
    0.8500 0.3250 0.0980
    0.9290 0.6940 0.1250
    0.4940 0.1840 0.5560
    0.4660 0.6740 0.1880
    0.3010 0.7450 0.9330
    0.6350 0.0780 0.1840];
nLineGroups = ceil(numCounties / size(newcolors, 1));
newcolors = repmat(newcolors, nLineGroups, 1);

% prepare tab group
fSeirModel = figure('Name', 'SEIR model view');
tgSeirModel = uitabgroup(fSeirModel);

% plot and save simulated inf(t)
tSeirModel(1) = uitab(tgSeirModel, 'Title', 'Simulated infectious cmprt.');
axSeirModel(1) = axes('Parent', tSeirModel(1));

for i=1:numCounties
    plot(axSeirModel(1), dateRangeJoint, simInf(:, i), '-.', 'Color', newcolors(i, :), 'LineWidth', 1)
    hold on
end

ylabel('Infection level inf(t)')
title('Simulated infectious cmprt.')
setFigureSettings(yLimRange, fAspectRatio)

outFile = append("./SEIR_sim_outputs/", timeSimStart, "/figures/SEIR_i_sim.pdf");
saveTabToFile(tSeirModel(1), outFile, saveFigures);

% plot and save real inf(t)
tSeirModel(2) = uitab(tgSeirModel, 'Title', 'Real infectious cmprt.');
axSeirModel(2) = axes('Parent', tSeirModel(2));

for i=1:numCounties
    plot(axSeirModel(2), dateRangeJoint, realInf(:, i), 'Color', newcolors(i, :), 'LineWidth', 2)
    hold on
end

ylabel('Infection level inf(t)')
title('Real infectious cmprt.')
setFigureSettings(yLimRange, fAspectRatio)

outFile = append("./SEIR_sim_outputs/", timeSimStart, "/figures/SEIR_i_real.pdf");
saveTabToFile(tSeirModel(2), outFile, saveFigures);

% plot and save simulated vs. real inf(t)
tSeirModel(3) = uitab(tgSeirModel, 'Title', 'Infectious cmprt. comparison');
axSeirModel(3) = axes('Parent', tSeirModel(3));

for i=1:numCounties
    plot(axSeirModel(3), dateRangeJoint, simInf(:, i), '-.', 'Color', newcolors(i, :), 'LineWidth', 1)
    hold on
    plot(axSeirModel(3), dateRangeJoint, realInf(:, i), 'Color', newcolors(i, :), 'LineWidth', 2)
end

ylabel('Infection level inf(t)')
title('Infectious cmprt. comparison')
setFigureSettings(yLimRange, fAspectRatio)
legend('simulated', 'real', 'Location', 'northwest')

outFile = append("./SEIR_sim_outputs/", timeSimStart, "/figures/SEIR_i_sim-vs-real.pdf");
saveTabToFile(tSeirModel(3), outFile, saveFigures);

% plot and save simulated vs. real exp(t)
tSeirModel(4) = uitab(tgSeirModel, 'Title', 'Exposed cmprt. comparison');
axSeirModel(4) = axes('Parent', tSeirModel(4));

for i=1:numCounties
    plot(axSeirModel(4), dateRangeJoint(idxTimeStartJoint:(idxTimeEndJoint - tLeadExp)), simExp(:, i), '-.', 'Color', newcolors(i, :), 'LineWidth', 1)
    hold on
    plot(axSeirModel(4), dateRangeJoint(idxTimeStartJoint:(idxTimeEndJoint - tLeadExp)), realExp(:, i), 'Color', newcolors(i, :), 'LineWidth', 2)
end

ylabel('Exposed level exp(t)')
title('Exposed cmprt. comparison')
setFigureSettings(yLimRange, fAspectRatio)
legend('simulated', 'real', 'Location', 'northwest')

outFile = append("./SEIR_sim_outputs/", timeSimStart, "/figures/SEIR_e_sim-vs-real.pdf");
saveTabToFile(tSeirModel(4), outFile, saveFigures);

% plot and save simulated vs. real rem(t)
tSeirModel(5) = uitab(tgSeirModel, 'Title', 'Removed cmprt. comparison');
axSeirModel(5) = axes('Parent', tSeirModel(5));

for i=1:numCounties
    plot(axSeirModel(5), dateRangeJoint, simRem(:, i), '-.', 'Color', newcolors(i, :), 'LineWidth', 1)
    hold on
    plot(axSeirModel(5), dateRangeJoint, realRem(:, i), 'Color', newcolors(i, :), 'LineWidth', 2)
end

ylabel('Removed level rem(t)')
title('Removed cmprt. comparison')
setFigureSettings(yLimRange, fAspectRatio)
legend('simulated', 'real', 'Location', 'northwest')

outFile = append("./SEIR_sim_outputs/", timeSimStart, "/figures/SEIR_r_sim-vs-real.pdf");
saveTabToFile(tSeirModel(5), outFile, saveFigures);

% plot comparison of denormalized compartments
% prepare tab group
fCompartComp = figure('Name', 'COVID-19 compartment comparison');
tgCompartComp = uitabgroup(fCompartComp);

% plot exposed compartment
tCompartComp(1) = uitab(tgCompartComp, 'Title', 'Exposed compartment');
axCompartComp(1) = axes('Parent', tCompartComp(1));

realExpDenorm = realExp * nation.county.residents(idxSelectedCounties)';
simExpDenorm = simExp * nation.county.residents(idxSelectedCounties)';
simExpCFDenorm = simExpCF * nation.county.residents(idxSelectedCounties)';

hold on
plot(axCompartComp(1), dateRangeJoint(idxTimeStartJoint:(idxTimeEndJoint - tLeadExp)), realExpDenorm)
plot(axCompartComp(1), dateRangeJoint(idxTimeStartJoint:(idxTimeEndJoint - tLeadExp)), simExpDenorm)
plot(axCompartComp(1), dateRangeJoint(idxTimeStartJoint:(idxTimeEndJoint - tLeadExp)), simExpCFDenorm)
hold off

ylabel('Exposed cases')
title('Exposed cmprt. comparison')
setFigureSettings([], fAspectRatio)
legend('real', 'simulated', 'counterfactual', 'Location', 'northwest')

outFile = append("./SEIR_sim_outputs/", timeSimStart, "/figures/COMP_exp.pdf");
saveTabToFile(tCompartComp(1), outFile, saveFigures);

% plot infectious compartment
tCompartComp(2) = uitab(tgCompartComp, 'Title', 'Infectious compartment');
axCompartComp(2) = axes('Parent', tCompartComp(2));

realInfDenorm = realInf * nation.county.residents(idxSelectedCounties)';
simInfDenorm = simInf * nation.county.residents(idxSelectedCounties)';
simInfCFDenorm = simInfCF * nation.county.residents(idxSelectedCounties)';

hold on
plot(axCompartComp(2), dateRangeJoint, realInfDenorm)
plot(axCompartComp(2), dateRangeJoint, simInfDenorm)
plot(axCompartComp(2), dateRangeJoint, simInfCFDenorm)
hold off

ylabel('Infectious cases')
title('Infectious cmprt. comparison')
setFigureSettings([], fAspectRatio)
legend('real', 'simulated', 'counterfactual', 'Location', 'northwest')

outFile = append("./SEIR_sim_outputs/", timeSimStart, "/figures/COMP_inf.pdf");
saveTabToFile(tCompartComp(2), outFile, saveFigures);

% plot removed compartment
tCompartComp(3) = uitab(tgCompartComp, 'Title', 'Removed compartment');
axCompartComp(3) = axes('Parent', tCompartComp(3));

realRemDenorm = realRem * nation.county.residents(idxSelectedCounties)';
simRemDenorm = simRem * nation.county.residents(idxSelectedCounties)';
simRemCFDenorm = simRemCF * nation.county.residents(idxSelectedCounties)';

hold on
plot(axCompartComp(3), dateRangeJoint, realRemDenorm)
plot(axCompartComp(3), dateRangeJoint, simRemDenorm)
plot(axCompartComp(3), dateRangeJoint, simRemCFDenorm)
hold off

ylabel('Removed cases')
title('Removed cmprt. comparison')
setFigureSettings([], fAspectRatio)
legend('real', 'simulated', 'counterfactual', 'Location', 'northwest')

outFile = append("./SEIR_sim_outputs/", timeSimStart, "/figures/COMP_rem.pdf");
saveTabToFile(tCompartComp(3), outFile, saveFigures);

%% calculate error metrics
err.inf = realInf - simInf;
err.infNorm = (norm(err.inf, normPower))/(norm(realInf, normPower));

err.rem = realRem - simRem;
err.remNorm = (norm(err.rem, normPower))/(norm(realRem, normPower));

err.exp = realExp - simExp;
err.expNorm = (norm(err.exp, normPower))/(norm(realExp, normPower));

%% assemble return value struct
modelSEIR.err = err;
modelSEIR.model = model;
modelSEIR.data = data;
end

function setFigureSettings(yLimRange, fAspectRatio)
if ~isempty(yLimRange)
    ylim(yLimRange)
end
pbaspect(fAspectRatio)
set(gca, 'Fontsize', 14)
end

function compartmentData = makeColumnsMonotonous(compartmentData)
for iDate = 2:size(compartmentData, 1)
    for iCounty = 1:size(compartmentData, 2)
        if compartmentData(iDate, iCounty) < compartmentData(iDate-1, iCounty)
            compartmentData(iDate, iCounty) = compartmentData(iDate-1, iCounty);
        end
    end
end
end