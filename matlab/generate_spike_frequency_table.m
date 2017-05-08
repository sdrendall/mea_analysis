function generate_spike_frequency_table(mat_path, output_path, varargin)
%% generate_spike_frequency_table(mat_path, output_path, [options])
%
% Generates a table of spike frequency for each unit specified in the mat file at mat_path
%  see process_spk_files for details on generating this mat file
%
% OPTIONS
%
% bin_size - size of the time bin (in seconds) to use when counting spikes. default = 300 seconds

% anon fcn to test for files
is_file = @(fp) exist(fp, 'file');

parser = inputParser();
parser.addRequired('mat_path', is_file);
parser.addRequired('output_path');
parser.addParameter('bin_size', 300, @isnumeric);
parser.parse(mat_path, output_path, varargin{:});

mat_data = load( ...
    mat_path, ...
    'electrode_containers', ...
    'final_spike_time', ...
    'recording_start_time' ...
);

bin_size = parser.Results.bin_size;
electrode_containers = mat_data.electrode_containers;
final_spike_time = mat_data.final_spike_time;
recording_start_time = mat_data.recording_start_time;

num_units = sum([mat_data.electrode_containers(:).n_clusters]);
num_bins = ceil((final_spike_time - recording_start_time)/seconds(bin_size));

frequency_mat = zeros([num_bins, num_units]);

curr_unit = 1;
unit_names = {};
for iEle = 1:numel(electrode_containers)
    curr_container = electrode_containers(iEle);
    unit_names = [unit_names, curr_container.get_unit_names()];
    for iClust = 1:curr_container.n_clusters
        % skip processing if no data is present (i.e. not enough spikes were detected for clustering)
        if curr_container.contains_data
            % extract the spike_times corresponding to spikes belonging to the current unit
            unit_spike_times = curr_container.spike_times( ...
                curr_container.class_no{curr_container.n_clusters} == iClust ...
            );
            frequency_mat(:, curr_unit) = generate_frequency_timecourse( ...
                unit_spike_times, ...
                'start_time', recording_start_time, ...
                'end_time', final_spike_time, ...
                'bin_size', bin_size ...
            );
        end
        curr_unit = curr_unit + 1;
    end
end

spike_table = array2table(frequency_mat, unit_names);
spike_table.time = [recording_start_time:seconds(bin_size):final_spike_time]';
writetable(spike_table, output_path);
