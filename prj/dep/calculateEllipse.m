function [X,Y] = calculateEllipse(x, y, a, b, angle, steps)
%CALCULATEELLIPSE This functions returns 2d points to draw an ellipse
%  @param x     X coordinate
%  @param y     Y coordinate
%  @param a     Semimajor axis
%  @param b     Semiminor axis
%  @param angle Angle of the ellipse (in degrees)
%  @param steps Number of steps to split line into
%
% source: https://stackoverflow.com/questions/2153768/draw-ellipse-and-ellipsoid-in-matlab

    narginchk(5, 6);
    if nargin<6, steps = 36; end

    beta = -angle * (pi / 180);
    sinbeta = sin(beta);
    cosbeta = cos(beta);

    alpha = linspace(0, 360, steps)' .* (pi / 180);
    sinalpha = sin(alpha);
    cosalpha = cos(alpha);

    X = x + (a * cosalpha * cosbeta - b * sinalpha * sinbeta);
    Y = y + (a * cosalpha * sinbeta + b * sinalpha * cosbeta);

    if nargout==1, X = [X Y]; end
end
