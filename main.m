clc
load('DataFSp.mat')

% Robot constants.
scanner_displacement = 30.0;
ticks_to_mm = 0.349;
robot_width = 155.0;

% Cylinder extraction and matching constants.
minimum_valid_distance = 20.0;
depth_jump = 100.0;
cylinder_offset = 90.0;

% Filter constants.
control_motion_factor = 0.35;  % Error in motor control.
control_turn_factor = 0.6;  % Additional error due to slip when turning.
measurement_distance_stddev = 200.0;  % Distance measurement error of cylinders.
measurement_angle_stddev = 15.0 / 180.0 * pi;  % Angle measurement error.
minimum_correspondence_likelihood = 0.001;  % Min likelihood of correspondence.

% Generate initial particles. Each particle is (x, y, theta).
number_of_particles = 25;
start_state = [500.0, 0.0, 45.0 / 180.0 * pi];
landmark_positions(:,:,1) = [0,0];
landmark_covariances(:,:,1) = eye(2);
clearvars initial_particles fs

for i = 1:number_of_particles
    initial_particles(i) = particle;
    initial_particles(i).pose = start_state;
end
% Setup filter.
for i = 1:number_of_particles
    fs(i) = FastSLAM(robot_width, scanner_displacement,control_motion_factor,control_turn_factor,...
              measurement_distance_stddev, measurement_angle_stddev,minimum_correspondence_likelihood,initial_particles(i));
end

clearvars i robot_width control_motion_factor control_turn_factor measurement_distance_stddev...
    measurement_angle_stddev minimum_correspondence_likelihood landmark_positions landmark_covariances
        
loop = length(left);
print_particles={}; 
printMean = zeros(loop,3);   printErrors = zeros(loop,4);
        
for k = 1: loop
    control = [left(k), right(k)] * ticks_to_mm;
    fs = predict(fs,control);
    % Correction.
    h=helperLib;
    cylinders = get_cylinders_from_scan(h,scanner(k,:), depth_jump,minimum_valid_distance, cylinder_offset);
    fs = correct(fs, cylinders);
    % Output particles.
    current_list_particles=getSingleValue4rmAll(h,fs);
    print_particles(k)={current_list_particles};
    % Output state estimated from all particles.
    mean = get_mean(h,fs);
    printMean(k,:)=[mean(1) + scanner_displacement * cos(mean(3)),mean(2) + scanner_displacement * sin(mean(3)), mean(3)];
    % Output error ellipse and standard deviation of heading.
    [ellipse_angle,eigenvals0,eigenvals1,var_heading] = get_error_ellipse_and_heading_variance(fs, mean);
    printErrors(k,:) = [ellipse_angle,eigenvals0,eigenvals1,var_heading];
end

clearvars k control mean scanner_displacement ellipse_angle eigenvals0 eigenvals1 var_heading ticks_to_mm robot_width ...
        control_motion_factor control_turn_factor loop current_list_particles initial_particles scanner_displacement ...
        ticks_to_mm  minimum_valid_distance  depth_jump  cylinder_offset h cylinders
