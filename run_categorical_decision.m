function run_categorical_decision(initial)
% cd C:\GitHub\Confidence-Theory
% initial = 'rd_p1_run02_notrain'; % 'rdshortnotrain'
% initial = 'testfast';

if nargin==0
    % initial = 'rd_p1_run02_notrain'; % 'rdshortnotrain'
    initial = 'notrain';
end

exp_type = 'AB'; %'attention' or 'AB'
new_subject = false;

staircase = false;
new_staircase = false;

if staircase & new_staircase
    psybayes_struct = [];
elseif staircase & ~new_staircase
    % replace file name here with your own .mat file.
    old = load('/Users/purplab/Desktop/Rachel/Confidence/confidence/data/notrain_20160316_121157.mat');
    psybayes_struct = old.psybayes_struct;
end

switch exp_type
    case 'attention'
        room_letter = 'Carrasco_L1'; % 'mbp','Carrasco_L1','1139'
        category_type = 'same_mean_diff_std'; % 'same_mean_diff_std','sym_uniform'
        eye_tracking = true;
        nStimuli = 4;
        choice_only = true;
        
        category_type = 'same_mean_diff_std'; % 'same_mean_diff_std','sym_uniform'
        stim_type = 'grate';
        
        categorical_decision(category_type, initial, new_subject, ...
            room_letter, nStimuli, eye_tracking, stim_type, [], [], ...
            choice_only, false, false, staircase, psybayes_struct)
    case 'AB'
        cd('C:\GitHub\Confidence-Theory')
        test_feedback = false;
        two_response = false;
        
        stim_type = 'grate';
        room_letter = '1139';
        nStimuli = 1;
        eye_tracking = false;
        
        multi_prior = true;

        first_task_letter = 'A';
        category_types = {'diff_mean_same_std', 'same_mean_diff_std'};
        if strcmp(first_task_letter, 'B')
            category_types = fliplr(category_types);
        end
        for i = 1:2
            categorical_decision(category_types{i}, initial, new_subject, ...
                room_letter, nStimuli, eye_tracking, stim_type, i, 2, [], ...
                two_response, test_feedback, staircase, [], multi_prior)
        end

end

return

%%
figure
for i = 1:3
    mean(mean(Test.responses{i}.tf))
    subplot(1,3,i)
    hist(Test.responses{i}.conf(:))
end

%%
all_resp = [Test.responses{1}.c(:); Test.responses{2}.c(:); Test.responses{3}.c(:)]
all_s = [Test.R.draws{1}(:); Test.R.draws{2}(:); Test.R.draws{3}(:)]


plot(all_s,all_resp+.2*rand(size(all_resp)),'.')