function [responses, flag, blockscore] = run_exp(n, R, t, scr, color, P, type, blok, new_subject, task_str, final_task, varargin)    

if length(varargin) == 1
    R2 = varargin{1};
    attention_manipulation = true;
else
    attention_manipulation = false;
end

try
    flag = 0;
    %binary matrix of correct/incorrect responses
    responses.tf = zeros(n.sections, n.trials);
    responses.c = zeros(n.sections, n.trials);
    responses.conf = zeros(n.sections, n.trials);
    responses.rt = zeros(n.sections, n.trials);
    
    
    % text before trials
    if k == 1
        switch type
            case 'Training'
                str='Coming up: Category Training';
            case 'Confidence Training'
                str=['Let''s get some quick practice with confidence ratings.\n\n'...
                    'Coming up: ' task_str 'Confidence Training'];
            case 'Attention Training'
                str=['Let''s practice the attention task.\n\n'... % more instructions here?
                    'Coming up: ' task_str 'Training']
            case 'Test'
                str='Coming up: Testing';
        end
        [~,ny]=DrawFormattedText(scr.win,str,'center','center',color.wt);
        flip_key_flip(scr,'begin',ny,color, false);
    end

%             if ~notrain
%                 [nx,ny] = DrawFormattedText(scr.win,['You will now begin\n\n' task_str ' Category Training before\n\n'...
%                     task_str 'Testing Block ' num2str(k+1) '.'],'center','center',color.wt,50);
%             else
%                 [nx,ny] = DrawFormattedText(scr.win,['You will now begin\n\n'...
%                     task_str 'Testing Block ' num2str(k+1) '.'],'center','center',color.wt,50);
%             end
%             flip_pak_flip(scr,ny,color,'begin');
%             

    
    
    
    
    %%%Run trials %%%

    for section = 1:n.sections
        for trial = 1:n.trials
            
            stim = struct;
            stim(1).ort = R.draws{blok}(section, trial);        %orientation
            stim(1).cur_sigma = R.sigma{blok}(section, trial);  %contrast
            stim(1).phase = R.phase{blok}(section, trial);      %phase (not needed by ellipse)

            Screen('DrawTexture', scr.win, scr.cross);
            t0 = Screen('Flip', scr.win);

            if ~attention_manipulation
                WaitSecs(t.betwtrials/1000);
            elseif attention_manipulation 
                stim(2).ort = R2.draws{blok}(section, trial);
                stim(2).cur_sigma = R2.sigma{blok}(section, trial);
                stim(2).phase = R2.phase{blok}(section, trial);
                
                % DISPLAY SPATIAL ATTENTION CUE
                if R2.cue{blok}(section, trial) == 1
                    Screen('DrawTexture', scr.win, scr.cueL);
                elseif R2.cue{blok}(section, trial) == 2
                    Screen('DrawTexture', scr.win, scr.cueR);
                end
                t_cue = Screen('Flip', scr.win, t0 + t.betwtrials/1000);
                Screen('DrawTexture', scr.win, scr.cross);
                t_cue_off = Screen('Flip', scr.win, t_cue + t.cue_dur/1000);
                
                %%% should make this timing exact by interfacing with grate
                WaitSecs(t.cue_target_isi/1000);
            end
            
            
            if strcmp(P.stim_type, 'gabor')
                r_gabor(P, scr, t, stim); % haven't yet added phase info to this function
            elseif strcmp(P.stim_type, 'grate')
                grate(P, scr, t, stim);
            elseif strcmp(P.stim_type, 'ellipse')
                ellipse(P, scr, t, stim); % ellipse doesn't need phase info
            end
            
            if attention_manipulation
                % DISPLAY RESPONSE CUE (i.e. probe)
                %%% should make this timing exact by interfacing with grate
                Screen('DrawTexture', scr.win, scr.cross);
                t_target_off = Screen('Flip', scr.win);
                if R2.probe{blok}(section, trial) == 1
                    Screen('DrawTexture', scr.win, scr.resp_cueL);
                    cval = R.trial_order{blok}(section, trial);
                elseif R2.probe{blok}(section, trial) == 2
                    Screen('DrawTexture', scr.win, scr.resp_cueR);
                    cval = R2.trial_order{blok}(section, trial);
                end
                t_resp_cue = Screen('Flip', scr.win, t_target_off + t.cue_target_isi/1000);
            else
                cval = R.trial_order{blok}(section, trial); %class
            end
            
            
            clc;
            fprintf('blok %g, section %g, trial %g\n\n',blok,section,trial)
            %subject input
            t0 = GetSecs;
            resp = 0;
            while resp == 0;
                [~, tResp, keyCode] = KbCheck;
                
                %To quit script, press x,z ONLY simultaneously
                %if keyCode(scr.keyx) && keyCode(scr.keyz) && sum(keyCode)==2
                %To quit script, press insert and enter ONLY
                %simultaneously
                if keyCode(scr.keyinsert) && keyCode(scr.keyenter) && sum(keyCode)==2
                    error('You cancelled the script by pressing the insert and enter keys simultaneously.')
                end
                
                if strcmp(type, 'Training')
                    if keyCode(scr.key5) % cat 1
                        resp = 1;
                    elseif keyCode(scr.key6) % cat 2
                        resp = 2;
                    end
                else % if not in non-conf training
                    if keyCode(scr.key1) || keyCode(scr.key2) || keyCode(scr.key3) || keyCode(scr.key4) %cat 1 keys
                        resp = 1;
                    elseif keyCode(scr.key7) || keyCode(scr.key8) || keyCode(scr.key9) || keyCode(scr.key10) %cat 2 keys
                        resp = 2;
                    end
                    
                    if keyCode(scr.key1) || keyCode(scr.key10)
                        conf = 4;
                        confstr = 'VERY HIGH';
                    elseif keyCode(scr.key2) || keyCode(scr.key9)
                        conf = 3;
                        confstr = 'SOMEWHAT HIGH';
                    elseif keyCode(scr.key3) || keyCode(scr.key8)
                        conf = 2;
                        confstr = 'SOMEWHAT LOW';
                    elseif keyCode(scr.key4) || keyCode(scr.key7)
                        conf = 1;
                        confstr = 'VERY LOW';
                    end
                end
            end
            
            %record 1 if correct, 0 if incorrect
%             fprintf('cat %d - ACC %d\n', resp, resp==cval) % for debugging
            responses.tf(section, trial) = (resp == cval);
            responses.c(section, trial) = resp;
            if ~strcmp(type, 'Training') % if not in non-conf training
                responses.conf(section, trial) = conf;
            end
            responses.rt(section,trial) = tResp - t0;
            
            if strcmp(type, 'Training') || strcmp(type,'Confidence Training') || strcmp(type,'Attention Training') %to add random feedback during test: || rand > .9 %mod(sum(sum(tfresponses)) ,10)==9
                %feedback
                if resp == cval
                    status = 'Correct!';
                    stat_col = color.grn;
                else
                    status = 'Incorrect!';
                    stat_col = color.red;
                end
                
                switch type
                    case 'Training'
                        [~,ny]=DrawFormattedText(scr.win,['You said: Category ' num2str(resp)],'center',scr.cy-50,color.wt);
                        [~,ny]=DrawFormattedText(scr.win,['\n' status],'center',ny+10,stat_col);
                    case 'Confidence Training'
                        [~,ny]=DrawFormattedText(scr.win,['You said: Category ' num2str(resp) ' with ' confstr ' confidence.'],'center',scr.cy-50,color.wt);
                    case 'Attention Training'
                        [~,ny]=DrawFormattedText(scr.win,['You said: Category ' num2str(resp) ' with ' confstr ' confidence.'],'center',scr.cy-50,color.wt);
                        [~,ny]=DrawFormattedText(scr.win,['\n' status],'center',ny+10,stat_col);
                end
                
                Screen('Flip',scr.win, tResp+t.pause/1000);
                
                WaitSecs(t.feedback/1000);
                
            end
            
        end
        
        %if another section in the same block immediately follows
        if section ~= n.sections
            [~,scorereport]=calcscore(responses,n.trials);
            if strcmp('Training', type) && blok == 1 % partway through training block 1. when experimenter should leave room
                midtxt = sprintf('Very good! You got %s\n\nYou have completed\n\n%s of %sCategory Training.',scorereport,fractionizer(section,n.sections), task_str);
                str = 'continue';
            elseif strcmp('Training', type) % this isn't happening right now;
                midtxt = ['Coming up: Testing Block ' num2str(section+1) '\n\n'...
                    'Training Block ' num2str(blok) '\n\n\n\n'];
                str = 'begin';
            else
                midtxt = sprintf('You have completed\n\n%s of %sTesting Block %i of %i.',fractionizer(section,n.sections),task_str,blok,n.blocks);
                str = 'continue';
            end
            
            [~,ny]=DrawFormattedText(scr.win,midtxt,'center','center',color.wt);
            flip_key_flip(scr,str,ny,color,false);
            
        end
        
        
    end
    [blockscore,scorereport]= calcscore(responses,n.sections*n.trials);
    
    experimenter_needed = false;
    switch type
        case 'Training'
            if blok > 1
                hitxt = ['Nice work! You just got ' scorereport ...
                    '\n\nComing up: ' task_str 'Testing Block ' num2str(blok) ' of ' num2str(n.blocks)];
                str = 'begin';
            else % first block
                if ~new_subject || (~strcmp(task_str,'') && nExperiments > 1) % because they will have seen this already
                    hitxt = ['Great job! You just got ' scorereport '\n\n\n'];
                    str = 'continue';
                else
                    hitxt = ['Great job! You just got ' scorereport '\n\n\n'...
                        'Please go get the experimenter from the other room!'];
                    experimenter_needed = true;
                end
            end
            [~,ny]=DrawFormattedText(scr.win,hitxt,'center','center',color.wt);

        case 'Confidence Training'
            hitxt = ['Great job! You have just finished Confidence Training.\n\n'...
                'Coming up: ' task_str 'Testing']; % have just removed hard-coded block number for now
            %             'Coming up: Task ' task_letter ' Testing Block 1 of 3']; % number of blocks is hard coded here!!! BAD!!!
            str = 'begin';
            [~,ny]=DrawFormattedText(scr.win,hitxt,'center','center',color.wt);

        case 'Attention Training'
            hitxt = ['Great job! You have just finished Attention Training.\n\n'...
                'Coming up: ' task_str 'Testing'];
            str = 'begin';
            [~,ny]=DrawFormattedText(scr.win,hitxt,'center','center',color.wt);

        case 'Test'
            hitxt = ['Great! You''ve just finished ' task_str 'Testing Block ' num2str(blok) ' with\n\n' scorereport];
            str = 'continue';
            [~,ny]=DrawFormattedText(scr.win,hitxt,'center','center',color.wt);

    end
    flip_key_flip(scr,str,ny,color,experimenter_needed);

    
    if strcmp(type, 'Test')
        %load top scores
        load top_ten
        ranking = 11 - sum(blockscore>=top_ten.(category_type).scores); % calculate current ranking
 
        if ranking < 11
            top_ten.(category_type).scores = [top_ten.(category_type).scores(1:(ranking-1));  blockscore;  top_ten.(category_type).scores(ranking:9)];
            for m = 10:-1:ranking+1
                top_ten.(category_type).initial{m} = top_ten.(category_type).initial{m-1};
            end
            top_ten.(category_type).initial{ranking} = initial;
            hitxt=['\n\nCongratulations! You made the ' task_str 'Top Ten!\n\n'];
        else
            hitxt='\n\n\n\n';
        end

        if ~any(strfind(initial,'test'))
            save top_ten top_ten;
        end

        [nx,ny] = DrawFormattedText(scr.win,[hitxt 'Your score for Testing Block ' num2str(k) ': ' num2str(blockscore,'%.1f') '%\n\n'...
            task_str 'Top Ten:\n\n'],'center',-90,color.wt);
        for j = 1:10
            [nx,ny] = DrawFormattedText(scr.win,[num2str(j) ') ' num2str(top_ten.(category_type).scores(j),'%.1f') '%    ' top_ten.(category_type).initial{j} '\n'],scr.cx*.8 - (j==10)*20,ny,color.wt);
        end

        
        if k ~= Test.n.blocks % if didn't just finish final testing block
            [nx,ny] = DrawFormattedText(scr.win,'\nPlease take a short break.\n\n\nYou may begin the next Training Block\n\n','center',ny,color.wt);
            [nx,ny] = DrawFormattedText(scr.win,'in ',scr.cx-570,ny,color.wt);
            countx=nx; county=ny;
            [nx,ny] = DrawFormattedText(scr.win,'   seconds, but you may take a\n\n',countx,county,color.wt);
            [nx,ny] = DrawFormattedText(scr.win,['longer break and leave the room\n\n'...
                'or walk around.'],'center',ny,color.wt,50);
            
            %  'Coming up:\n\n'...
%                     task_str 'Testing Block ' num2str(k+1)],'center',ny,color.wt,50);
            countdown(scr,color,countx,county)

            flip_key_flip(scr,'continue',ny,color,false);

        else % final block
            if ~final_task % if have more tasks left
                if new_subject
                    [nx,ny] = DrawFormattedText(scr.win,['\nYou''re done with ' task_str '\n\n\n'...
                        'Please go get the experimenter from the other room!'],'center',ny,color.wt);
%                     experimenter_needed = true;
                    %             Screen('Flip',scr.win);
                    %WaitSecs(5);
%                     flip_wait_for_experimenter_flip(scr.keyenter, scr);
                    %             KbWait;
                    %             Screen('Flip',scr.win);
                    
                elseif ~new_subject% if just finished experiment one, and there's another experiment coming up.
                    [nx,ny] = DrawFormattedText(scr.win,['\nYou''re done with ' task_str '\n\n\n'],'center',ny,color.wt);
                    [nx,ny] = DrawFormattedText(scr.win,['You may begin Task ' other_task_letter ' in '],scr.cx-570,ny,color.wt);
                    countx=nx; county=ny;
                    [nx,ny] = DrawFormattedText(scr.win,'   seconds,\n\n',countx,county,color.wt);
                    [nx,ny] = DrawFormattedText(scr.win,['but you may take a longer break\n\n'...
                        'and leave the room or walk around.\n\n\n'...
                        'Coming up: Task ' other_task_letter],'center',ny,color.wt,50);
                    
                    countdown(scr,color,countx,county);
                    
%                     flip_pak_flip(scr,ny,color,'begin','initial_wait',0);
                    
                end
                
                flip_key_flip(scr,'begin',ny,color,new_subject, 'initial_wait',0);
                
            elseif final_task % if done with all experiments (incl if there is only one experiment)
                [nx,ny] = DrawFormattedText(scr.win,'\n\n\n\nYou''re done with the experiment.\n\nThank you for participating!','center',ny,color.wt);
                Screen('Flip',scr.win)
                WaitSecs(1);
                KbWait([], 0, GetSecs+180); % automatically quit after 3 minutes
            end
            
            WaitSecs(1);
        end
        

%     flip_key_flip(scr,str,ny,color,experimenter_needed);
%     if experimenter_needed
%         flip_wait_for_experimenter_flip(scr.keyenter, scr);
%     else
%         flip_pak_flip(scr,ny,color,str)
%     end
    
    end
    
    
catch
    % I think these lines just indicate where an error occurred when you look back at the data.
    responses.tf(section, trial) = -1;
    responses.c(section, trial) = -1;
    responses.conf(section, trial) = -1;
    responses.rt(section, trial) = -1;
    
    
    psychrethrow(psychlasterror)
    save responses
    flag = 1;
    
end
end

function str = fractionizer(numerator,denominator)
n = {'one','two','three','four','five'};
d = {'','half','third','quarter','fifth'};

if numerator > denominator
    warning('numerator greater than denominator!')
    str = '';
else
    if numerator==denominator
        str = 'all';
    else
        if numerator==1
            str = sprintf('%s %s',n{1}, d{denominator});
        else
            str = sprintf('%s %ss',n{numerator}, d{denominator});
        end
    end
end
end