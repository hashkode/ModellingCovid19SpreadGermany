function [betaE, betaI, sigma, gamma, betaGammaMu] = calibrateSeirModel(h, A1, A3, infected, removed, exposed, preExposed, behavior)
%CALIBRATESEIRMODEL Calibrate parameters of a networked SEIR model
%   This function calculates the parameters of a networked SEIR model 
%   based on a global scale @h, a static adjacency matrix @A1, a transient
%   adjacency matrix @A3, pandemic parameters per county @infected,
%   @removed, @exposed, a static delay between exposure and infection
%   @preExposed and a behavior vector or matrix @behavior.
%   It outputs the identified model parameters @betaI, @betaE @sigma,
%   @gamma and @betaGammaMu.

[nDate, nCounty] = size(infected);

infectedSim = reshape(infected', nDate*nCounty, 1);
removedSim = reshape(removed', nDate*nCounty, 1);
exposedSim = reshape(exposed', nDate*nCounty, 1);

% number of parameters (3 betaE, 3 betaI, sigma, gamma)
q = 8;

Alpha = zeros(nDate * nCounty - nCounty, q);
Phi = zeros(nDate * nCounty - nCounty, q);
Sigma = zeros(nDate * nCounty - nCounty, q);

% Calculate difference quotient accross compartments
infectedDiff = infectedSim(nCounty+1:end) - infectedSim(1:nDate*nCounty-nCounty);
removedDiff = removedSim(nCounty+1:end) - removedSim(1:nDate*nCounty-nCounty);
exposedDdiff = exposedSim(nCounty+1:end) - exposedSim(1:nDate*nCounty-nCounty);
diff = [exposedDdiff; infectedDiff; removedDiff];

A2 = eye(nCounty);

for i = 1:nDate-1
    e_i = exposedSim(nCounty*(i-1)+1:nCounty*i);
    i_i = infectedSim(nCounty*(i-1)+1:nCounty*i);
    r_i = removedSim(nCounty*(i-1)+1:nCounty*i);
    S_i = eye(nCounty) - (diag(e_i) + diag(i_i) + diag(r_i));
    
    if size(behavior{1}, 2) == 1
        A1_i = behavior{1}(i) * A1;
        A2_i = behavior{2}(i) * A2;
        A3_i = behavior{3}(i) * A3(:, :, i);
    else
        A1_i = diag(behavior{1}(i, :)) * A1;
        A2_i = diag(behavior{2}(i, :)) * A2;
        A3_i = diag(behavior{3}(i, :)) * A3(:, :, i);
    end
    
    Alpha((nCounty*(i-1)+1):(nCounty*i), :) = [...
        h * S_i * A1_i * e_i, ...
        h * S_i * A2_i * e_i, ...
        h * S_i * A3_i * e_i, ...
        h * S_i * A1_i * i_i, ...
        h * S_i * A2_i * i_i, ...
        h * S_i * A3_i * i_i, ...
        -h * e_i, ...
        zeros(length(i_i), 1)];
    
    Sigma((nCounty*(i-1)+1):(nCounty*i), :) = [...
        zeros(length(i_i), 1), ...
        zeros(length(i_i), 1), ...
        zeros(length(i_i), 1), ...
        zeros(length(i_i), 1), ...
        zeros(length(i_i), 1), ...
        zeros(length(i_i), 1), ...
        h * e_i, ...
        -h * i_i];
    
    Phi((nCounty*(i-1)+1):(nCounty*i), :) = [...
        zeros(length(i_i), 1), ...
        zeros(length(i_i), 1), ...
        zeros(length(i_i), 1), ...
        zeros(length(i_i), 1), ...
        zeros(length(i_i), 1), ...
        zeros(length(i_i), 1), ...
        zeros(length(i_i), 1), ...
        h * i_i];  
end

P = [Alpha; Sigma; Phi];

betaGammaMu = pinv(P) * diff;

cvx_begin
cvx_solver mosek

% optimization variables
variables bE1 bE2 bE3 bI1 bI2 bI3 sig gam

% constraints
bI1 >= 0;
bI2 >= 0;
bI3 >= 0;

bE1 >= 0;
bE2 >= 0;
bE3 >= 0;

gam >= 0;
gam <= 1;

sig >= 0;
sig <= 1/(preExposed);

% comment out for reduced simulation time
for i = 1:nDate-1
    if size(behavior{1}, 2) == 1
        A1_i = behavior{1}(i) * A1;
        A2_i = behavior{2}(i) * A2;
        A3_i = behavior{3}(i) * A3(:, :, i);
    else
        A1_i = diag(behavior{1}(i, :)) * A1;
        A2_i = diag(behavior{2}(i, :)) * A2;
        A3_i = diag(behavior{3}(i, :)) * A3(:, :, i);
    end
    
    for j = 1:length(A1_i(:, 1))
        sum(A1_i(j,:)) * bI1 + sum(A2_i(j,:)) * bI2 + sum(A3_i(j,:)) * bI3 ...
            + sum(A1_i(j,:)) * bE1 + sum(A2_i(j,:)) * bE2 + sum(A3_i(j,:)) * bE3 ...
            <= 1/h;
    end
end

minimize(norm(P * [bE1; bE2; bE3; bI1; bI2; bI3; sig; gam] - diff, 2))
cvx_end

betaE = [bE1; bE2; bE3];
betaI = [bI1; bI2; bI3];

sigma = sig;
gamma = gam;
end
