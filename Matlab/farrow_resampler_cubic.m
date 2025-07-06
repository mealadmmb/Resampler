function y_out = farrow_resampler_cubic(x_in, fs_in, fs_out)
% x_in     : input signal
% fs_in    : input sample rate (e.g., 10e6)
% fs_out   : output sample rate (e.g., 8e6 or 25)
% y_out    : output resampled signal using cubic polynomial Farrow

rate = fs_in/fs_out ;      % resampling ratio
phase = 0;                  % fractional phase accumulator
ptr = 2;                    % pointer to input samples (safe index start)
L = length(x_in);
y_out = [];

while (ptr + 2 <= L)  % need 4 points: x[n-1], x[n], x[n+1], x[n+2]
    mu = phase;       % fractional delay in [0,1)

    % === Get 4 input samples for cubic interpolation ===
    x0 = x_in(ptr-1);
    x1 = x_in(ptr);
    x2 = x_in(ptr+1);
    x3 = x_in(ptr+2);

    % === Cubic polynomial coefficients (from samples) ===
    % Based on Keys' cubic convolution (Catmull-Rom spline, a = -0.5)
    a = -0.5;  % tension parameter

    a0 = x1;
    a1 = -0.5*x0 + 0.5*x2;
    a2 = x0 - 2.5*x1 + 2*x2 - 0.5*x3;
    a3 = -0.5*x0 + 1.5*x1 - 1.5*x2 + 0.5*x3;

    % === Evaluate cubic polynomial using Horner's method ===
    y = ((a3*mu + a2)*mu + a1)*mu + a0;
    y_out = [y_out, y];

    % === Update phase accumulator ===
    phase = phase + rate;
    while phase >= 1
        phase = phase - 1;
        ptr = ptr + 1;
    end
end
end
