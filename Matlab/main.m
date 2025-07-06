% Input signal parameters
fs_in = 10e6;          % 10 MSPS
fs_out = 50e6;           % e.g., resample to 25 SPS
duration = 50e-6;       % short duration to see resampling clearly

% Generate sine input
t_in = 0:1/fs_in:duration;
f_sin = 0.1e6;           % 1 MHz sine wave
x_in = sin(2*pi*f_sin*t_in);

% Run Farrow cubic resampler
y_out = farrow_resampler_cubic(x_in, fs_in, fs_out);
t_out = (0:length(y_out)-1) / fs_out;

% Plot
figure;
subplot(2,1,1); plot(t_in*1e6, x_in); title('Input Signal'); xlabel('Time (μs)'); ylabel('Amplitude');
subplot(2,1,2); plot(t_out*1e6, y_out, 'r'); title('Resampled Signal (Cubic)'); xlabel('Time (μs)'); ylabel('Amplitude');
