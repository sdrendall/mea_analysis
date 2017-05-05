function process_spk_file(spk_paths, output_path)
    %% process_spk_file(spk_paths, output_path)
    %
    % processes one or more 

    if ~exist('output_path', 'var')
        [spk_dir, spk_name] = fileparts(spk_paths{1});
        output_path = fullfile(spk_dir, [spk_name, '.mat']);
        disp(['Output path not specified! Saving to ', output_path])
    end

    axis_loader = AxisLoader(spk_paths);
    output_file = matfile(output_path, 'Writable', true);
    cell_shape = axis_loader.get_cell_shape(); % The cell shape is dependent on the size of the plate
    % This is how you have to preallocate object arrays in matlab
    electrode_containers( ...
        cell_shape(1), ...
        cell_shape(2), ...
        cell_shape(3), ...
        cell_shape(4) ...
    ) = ElectrodeContainer();
    % We also need to store the timing of the last spike so that we can draw the x axis while plotting
    final_spike_time = datetime('1945-02-13 00:00:00');

    for i = 1:axis_loader.num_channels
        [spike_data, channel] = axis_loader.load_next_data_set();
        disp(['Num Spikes: ', num2str(length(spike_data))])
        spike_index = [ ... 
            channel.WellRow, ...
            channel.WellColumn, ...
            channel.ElectrodeColumn, ...
            channel.ElectrodeRow ...
        ];
        if length(spike_data) > 20 % Feature Extraction requires at least three spikes
            features = get_spike_features(spike_data); % generate spike features (we only use pca now)
            models = fit_models_to_features(features, 'pca'); % fit models (gmm) to pca
            clusters = cellfun(@(m) m.cluster(features.pc_scores), models, 'UniformOutput', false); % calculate cluster numbers
            spike_times = get_spike_times_from_spike_array(spike_data);
            spike_mat = get_spike_mat_from_spike_array(spike_data);
            % lambda fcn for computing mean waveforms functionally
            fn_get_mean_wfs = @(n) get_average_waveforms(spike_mat, n, clusters{n});
            mean_waveforms = arrayfun(fn_get_mean_wfs, 1:numel(clusters), 'UniformOutput', false);
            electrode_containers( ...
                channel.WellRow, ...
                channel.WellColumn, ...
                channel.ElectrodeColumn, ...
                channel.ElectrodeRow ...
            ) = ElectrodeContainer( ...
                spike_index, ...
                spike_times, ...
                'features', features, ...
                'cluster_model', models, ...
                'class_no', clusters, ...
                'contains_data', true, ...
                'valid', true(size(clusters)), ...
                'mean_waveforms', mean_waveforms ...
            );
            % Update the final spike time
            last_spike_on_electrode_time = max(spike_times);
            final_spike_time = max([final_spike_time, last_spike_on_electrode_time]);
        else
            electrode_containers( ...
                channel.WellRow, ...
                channel.WellColumn, ...
                channel.ElectrodeColumn, ...
                channel.ElectrodeRow ...
            ) = ElectrodeContainer( ...
                spike_index, ...
                'contains_data', false, ...
                'valid', false ...
            );
        end
    end

    % Write data to the output file
    output_file.electrode_containers = electrode_containers;
    output_file.final_spike_time = final_spike_time;
    output_file.recording_start_time = axis_loader.recording_start_time;


function datasets = load_axis_datasets(filepaths)
    datasets = cell(size(filepaths));
    for i = 1:numel(filepaths)
        datasets{i} = AxisFile(filepaths{i}).DataSets.LoadData();
    end

function mean_waveforms = get_average_waveforms(spikes, n_clusters, class_numbers)
    mean_waveforms = zeros([n_clusters, size(spikes, 2)]);
    for i = 1:n_clusters
        mean_waveforms(i, :) = mean(spikes(class_numbers == i, :), 1);
    end
