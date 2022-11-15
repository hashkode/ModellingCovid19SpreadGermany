function [infSim, remSim, expSim]= simulateSeirModel(h, betaE, betaI, sigma, gamma, A1, A3, infectedT0, removedT0, exposedT0, timeVector, behavior)
%CALIBRATESEIRMODEL Simulate a calibrated, networked SEIR model
%   This function simulates the pandemic parameters of a networked SEIR
%   model based on a global scale @h, the SEIR model parameters @betaE,
%   @betaI, @sigma, @gamma, a static adjacency matrix @A1, a transient
%   adjacency matrix @A3, initial pandemic parameters per county 
%   @infectedT0, @removedT0, @exposedT0, a time range to simulate for
%   @timeVector and a behavior vector or matrix @behavior.
%   It outputs the simulated pandemic parameters per compartment @infSim,
%   @remSim and @expSim.

% This is the discrete euler's method approx. of the mean field approx of
% the continuous 2^n mode;

[~, nCounty] = size(infectedT0);

A3_rep = repmat(A3(:,:,end), [1 1 timeVector]);
A3 = cat(3, A3, A3_rep);

A2 = eye(nCounty);

infSim = zeros(timeVector, nCounty);
remSim = zeros(timeVector, nCounty);
expSim = zeros(timeVector, nCounty);

infSim(1, :) = infectedT0;
remSim(1, :) = removedT0;
expSim(1, :) = exposedT0;

for i = 1:timeVector-1
    E_i = diag(expSim(i, :));
    I_i = diag(infSim(i, :));
    R_i = diag(remSim(i, :));
    S_i = eye(nCounty) - (E_i + I_i + R_i);
    
    if size(behavior{1}, 2) == 1
        A1_i = behavior{1}(i) * A1;
        A2_i = behavior{2}(i) * A2;
        A3_i = behavior{3}(i) * A3(:, :, i);
    else
        A1_i = diag(behavior{1}(i, :)) * A1;
        A2_i = diag(behavior{2}(i, :)) * A2;
        A3_i = diag(behavior{3}(i, :)) * A3(:, :, i);
    end
    
    expSim(i+1, :) = expSim(i,:) + h * ( ...
            S_i * betaE(1) * A1_i * (expSim(i,:)') + S_i * betaE(2) * A2_i * (expSim(i,:)') + S_i * betaE(3) * A3_i * (expSim(i,:)') ...
            + S_i * betaI(1) * A1_i * (infSim(i,:)') + S_i * betaI(2) * A2_i * (infSim(i,:)') + S_i * betaI(3) * A3_i * (infSim(i,:)') ...
            - sigma * (expSim(i,:)'))';
    infSim(i+1, :) = infSim(i,:) + h *(sigma * expSim(i,:) - gamma * infSim(i,:));
    remSim(i+1, :) = remSim(i,:) + h * gamma * infSim(i,:);
end
