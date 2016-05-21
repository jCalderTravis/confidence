function ah = show_data_or_fits(varargin)
% this function does a lot of things. some options:
% 1. show individual data
% 2. (and individual fits)
% 3. show grouped data
% 4. (and group fits)

root_datadir = '~/Google Drive/Will - Confidence/Data/v3_all';
depvars = {'tf'};%,       'g',        'Chat',     'resp',     'rt'};
nBins = 7;
conf_levels = 4;
nRespSquares = 8;
symmetrify = false;
slices = {'c_s'}; % 's', 'c_s', 'c_resp', etc etc etc. figure out how to add a blank
means = {};% 'g', 'resp', 's', 'c', etc etc
tasks = {'A','B'};
axis = struct;
axis.col = 'slice'; % 'subject', 'slice', or 'model'. defaults to subject if not doing group plots
axis.row = 'task'; % 'task', 'model', or 'depvar'
axis.fig = 'none'; % 'model', 'task', 'depvar', 'slice'
trial_types = {'all'}; % 'all', 'correct', 'incorrect', etc...
linewidth = 2;
meanlinewidth = 4;
gutter = [.0175 .025];
margins = 2*[0.06 .01 .06 .04]; % L R B T
models = [];
nPlotSamples = 10;
nFakeGroupDatasets = 100;
plot_reliabilities = [];
show_legend = false;
s_labels = -8:2:8;
errorbarwidth = 1.7;
MCM = ''; % 'dic', 'waic2', whatever. add extra row with MCM scores.
MCM_size = .38; % percentage of plot height taken up by model comparison.
ref_model = [];
assignopts(who, varargin);

if ~isempty(MCM) && strcmp(axis.col, 'model')
    show_MCM = true;
    margins(3) = MCM_size;
else
    show_MCM = false;
end

if strcmp(axis.col, 'subject') || strcmp(axis.fig, 'subject') || strcmp(axis.row, 'subject') % in all non-group plots, subjects are along one axis
    group_plot = false;
else
    group_plot = true;
end

if rem(nBins, 2) == 0; nBins = nBins +1; end % make sure nBins is odd.

nDepvars = length(depvars);
nSlices = length(slices);
nTasks = length(tasks);
nTypes = length(trial_types);

for task = 1:nTasks
    [edges.(tasks{task}), centers.(tasks{task})] = bin_generator(nBins, 'task', tasks{task});
end

real_data = compile_and_analyze_data(root_datadir, 'nBins', nBins,...
    'symmetrify', symmetrify, 'conf_levels', conf_levels, 'trial_types', trial_types,...
    'output_fields', depvars, 'bin_types', union(slices, means), 'group_stats', group_plot);

nSubjects = length(real_data.(tasks{1}).data);

map = load('~/Google Drive/MATLAB/utilities/MyColorMaps.mat');

if isfield(real_data.(tasks{1}).data(1).raw, 'cue_validity') && ~isempty(real_data.(tasks{1}).data(1).raw.cue_validity)
    % attention
    attention_manipulation = true;
else
    nReliabilities = length(unique(real_data.(tasks{1}).data(1).raw.contrast_id));
    attention_manipulation = false;
    
    if isempty(plot_reliabilities); plot_reliabilities = 1:nReliabilities; end
    
    if max(plot_reliabilities) > nReliabilities; error('you requested to plot more reliabilities than there are'); end
end

if ~isempty(models)
    show_fits = true;
    nModels = length(models);
    plot_connecting_line = false;
    
    models = generate_and_analyze_fitted_data(models, tasks, 'real_data', real_data, 'nBins', nBins, 'nPlotSamples', nPlotSamples,...
        'depvars', depvars, 'symmetrify', symmetrify, 'bin_types', union(slices, means),...
        'attention_manipulation', attention_manipulation, 'group_plot', group_plot, 'nFakeGroupDatasets', nFakeGroupDatasets);
else
    show_fits = false;
    nModels = 0;
    plot_connecting_line = true;
end


n = struct;
plot_axes = {'col', 'row', 'fig'};
for i = 1:3
    switch axis.(plot_axes{i})
        case 'depvar'
            n.(plot_axes{i}) = nDepvars;
        case 'task'
            n.(plot_axes{i}) = nTasks;
        case 'model'
            n.(plot_axes{i}) = nModels;
        case 'slice'
            n.(plot_axes{i}) = nSlices;
        case 'subject'
            n.(plot_axes{i}) = nSubjects;
        case 'trial_type'
            n.(plot_axes{i}) = nTypes;
        case 'none'
            n.(plot_axes{i}) = 1;
    end
end

ah = zeros(n.row, n.col, n.fig);

ylabels = rename_var_labels(depvars); % translate from variable names to something other people can understand.

[depvar, task, model, slice, subject, trial_type] = deal(1); % update these in the for loop switch below.

%%
for fig = 1:n.fig
    figure(fig)
    set(gcf,'position', [60 60 250*n.col 325*n.row])
    clf
    
    for col = 1:n.col
        if col == 1
            label_y = true;
        elseif col > 1 && ~strcmp(axis.col, 'depvar')
            label_y = false;
        end
        
        for row = 1:n.row
            for i = 1:3
                switch axis.(plot_axes{i})
                    case 'depvar'
                        depvar = eval(plot_axes{i});
                    case 'task'
                        task = eval(plot_axes{i});
                    case 'model'
                        model = eval(plot_axes{i});
                    case 'slice'
                        slice = eval(plot_axes{i});
                    case 'subject'
                        subject = eval(plot_axes{i});
                    case 'trial_type'
                        trial_type = eval(plot_axes{i});
                end
            end
            
            if show_legend
                if length(slices)==1 || ~any(strcmp('slice', {axis.col, axis.row}))
                    if row==1 && col==1
                        sdp_legend = true;
                    else
                        sdp_legend = false;
                    end
                elseif strcmp('slice', axis.col)
                    if row==1
                        sdp_legend = true;
                    else
                        sdp_legend = false;
                    end
                elseif strcmp('slice', axis.row)
                    if row==1
                        sdp_legend = true;
                    else
                        sdp_legend = false;
                    end
                end
            else
                sdp_legend = false;
            end
            
            ah(row, col, fig) = tight_subplot(n.row, n.col, row, col, gutter, margins);
            
            if symmetrify && any(strcmp(slices{slice}, {'s', 'c_s'})) && strcmp(tasks{task}, 'B')
                symmetrify_s = true;
            else
                symmetrify_s = false;
            end
            
            if row == n.row
                label_x = true;
            else
                label_x = false;
            end
            shortcutplot = @(data, fake_data, x_name, linewidth, plot_reliabilities)...
                single_dataset_plot(data, depvars{depvar}, x_name, ...
                'fake_data', fake_data, 'group_plot', group_plot, ...
                'symmetrify', symmetrify_s, ...
                'linewidth', linewidth, ...
                'plot_reliabilities', plot_reliabilities, ...
                'label_x', label_x, 'label_y', label_y, 's_labels', s_labels,...
                'task', tasks{task}, 'errorbarwidth', errorbarwidth,...
                'plot_connecting_line', plot_connecting_line,...
                'nRespSquares', nRespSquares, 'show_legend', (~fake_data && sdp_legend),...
                'attention_task', attention_manipulation);
            
            % clean this section up?
            fake_data = false;
            % plot real sliced data
            if ~isempty(slices{slice})
                if ~group_plot
                    data = real_data.(tasks{task}).data(subject).stats.(trial_types{trial_type}).(slices{slice});
                else
                    data = real_data.(tasks{task}).sumstats.(trial_types{trial_type}).(slices{slice});
                end
                shortcutplot(data, fake_data, slices{slice}, linewidth, plot_reliabilities);
            end
            
            % plot real "mean" data
            if ~isempty(means) && ~isempty(means{slice})
                if ~group_plot
                    data = real_data.(tasks{task}).data(subject).stats.(trial_types{trial_type}).(means{slice});
                else
                    data = real_data.(tasks{task}).sumstats.(trial_types{trial_type}).(means{slice});
                end
                shortcutplot(data, fake_data, means{slice}, meanlinewidth, []);
            end
            
            % plot fitted sliced data
            if show_fits
                fake_data = true;
                if ~isempty(slices{slice})
                    if ~group_plot
                        data = models(model).extracted(subject).fake_datasets.(tasks{task}).sumstats.(trial_types{trial_type}).(slices{slice});
                    else
                        data = models(model).(tasks{task}).sumstats.(trial_types{trial_type}).(slices{slice}); % fake_group_datasets_and_stats doesn't have support for trial_types. i think that's okay 12/11/15
                    end
                    shortcutplot(data, fake_data, slices{slice}, linewidth, plot_reliabilities);
                end
                
                if ~isempty(means) && ~isempty(means{slice})
                    if ~group_plot
                        data = models(model).extracted(subject).fake_datasets.(tasks{task}).sumstats.(trial_types{trial_type}).(means{slice});
                    else
                        data = models(model).(tasks{task}).sumstats.(trial_types{trial_type}).(means{slice});
                    end
                    shortcutplot(data, fake_data, means{slice}, meanlinewidth, []);
                end
                
            end
            
            % y axis labels for left column
            if col == 1 || strcmp(axis.col, 'depvar')
                if strcmp(axis.row, 'model')
                    yl=ylabel({ylabels{depvar}, ['Task ' tasks{task}], rename_models(models(model).name)});
                    set(yl, 'fontsize', 9)
                else
                    yl=ylabel({ylabels{depvar}, ['Task ' tasks{task}]});
                end
                if strcmp(depvars{depvar}, 'resp')
                    ylpos = get(yl, 'position');
                    if strcmp(slices{slice}, 'c_s')
                        set(yl, 'position', ylpos-[.8 0 0]);
                    elseif strcmp(slices{slice}, 'c_C')
                        set(yl, 'position', ylpos+[.4 0 0]);
                    end
                end
            end
            
            
            % title (and maybe legend) for top row
            if row == 1
                switch axis.col
                    case 'subject'
                        title(upper(real_data.(tasks{task}).data(subject).name));
                    case 'model'
                        title(rename_models(models(model).name));
                    case 'trial_type'
                        title(trial_types{trial_type});
                end
            end
        end
    end
    
    if show_MCM
    % old way of doing it straight across:
    %         tight_subplot(1,1,1,1, 0, [margins(1), margins(2), .1, 1-MCM_size+.07])
    %         [score, group_mean, group_sem] = compare_models(models, 'show_names', true, 'show_model_names', false,...
    %             'group_gutter', gutter(1)/(1-margins(1)-margins(2)), 'bar_gutter', .005, 'ref_model', ref_model,...
    %             'multiple_axes', true);
    
    for col = 1:n.col
        tight_subplot(1, n.col, 1, col, gutter, [margins(1), margins(2), .1, 1-MCM_size+.07]);
        
        % it's dumb to do compare_models each time, but it gets the
        % axes set correctly.
        
        [~, ~, ~, MCM_delta, subject_names] = compare_models(models, 'show_names', true, 'show_model_names', false,...
            'group_gutter', gutter(1)/(1-margins(1)-margins(2)), 'bar_gutter', .005, 'ref_model', ref_model, ...
            'MCM', MCM);
        if col == 1
            yl = get(gca, 'ylim');
        else
            ylabel('');
        end
        
        mybar(MCM_delta(col, :), 'barnames', subject_names);
        ylim(yl);
        
        if col ~= 1
            set(gca, 'yticklabel', '');
        end
    end    
end

end

end