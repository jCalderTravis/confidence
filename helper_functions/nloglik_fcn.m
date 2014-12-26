function nloglik = nloglik_fcn(p_in, raw, model, varargin)
if model.d_noise
    if length(varargin) == 1
        nDNoiseSets = varargin{1};
    else
        nDNoiseSets = 101;
    end
else
    nDNoiseSets = 1;
end

% % this is now going to break non-fmincon optimization, because i took out the constraints
% if length(varargin) == 2 | length(varargin) == 3
%     alg = varargin{2};
%     if strcmp(alg,'snobfit') | strcmp(alg,'mcs') % opt algorithms that don't have linear constraints built in
%         c = varargin{1};
%         p_in = reshape(p_in,length(p_in),1);
%         if any(c.A * p_in > c.b) || any(p_in < c.lb') || any(p_in > c.ub')
%             nloglik = 1e8;
%             %disp('violation!')
%             return
%         end
%     end
% end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SETUP %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

global p conf_levels d_bounds

p = parameter_variable_namer(p_in, model.parameter_names, model);
contrasts = exp(-4:.5:-1.5);
nContrasts = length(contrasts);
nTrials = length(raw.s);

if model.d_noise
    nSTDs = 5;
    weights = normpdf(linspace(-nSTDs, nSTDs, nDNoiseSets), 0, 1);
    normalized_weights = weights ./ sum(weights);
    
    d_noise_draws = linspace(-p.sigma_d*nSTDs, p.sigma_d*nSTDs, nDNoiseSets);
    
    d_noise = repmat(d_noise_draws',1,nContrasts);
    d_noise_big = repmat(d_noise_draws',1,nTrials);% this is for confidence. too hard to figure out the indexing. going to be too many computations, because there's redundancy in the a,b,k vectors. but the bulk of computation has to be on an individual trial basis anyway.
else
    d_noise = 0;
    d_noise_big = 0;
end

if isfield(p,'b_i')
    conf_levels = (length(p.b_i) - 1)/2;
else
    conf_levels = 0;
end

if model.free_cats
    sig1 = p.sig1;
    sig2 = p.sig2;
else
    sig1 = 3; % defaults for qamar distributions
    sig2 = 12;
end
sigs = fliplr(sqrt(max(0,p.sigma_0^2 + p.alpha .* contrasts .^ -p.beta))); % low to high sigma. should line up with contrast id
% now k will only be 6 cols, rather than 3240.
optflag = 0;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% CHOICE PROBABILITY %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% k is the category decision boundary in measurement space for each trial
% f computes the probability mass on the chosen side of k.
if strcmp(model.family, 'opt')% for normal bayesian family of models
    
    if ~model.non_overlap
        optflag = 1; % this is because f gets passed a square root that can be negative. causes it to ignore the negatives
        k1 = .5 * log( (sigs.^2 + sig2^2) ./ (sigs.^2 + sig1^2));% + p.b_i(5); %log(prior / (1 - prior));
        k2 = (sig2^2 - sig1^2) ./ (2 .* (sigs.^2 + sig1^2) .* (sigs.^2 + sig2^2));
        k   = (sqrt(repmat(k1, nDNoiseSets, 1) + d_noise)) ./ repmat(sqrt(k2), nDNoiseSets, 1);
        
    elseif model.non_overlap
        x_bounds = find_intersect_truncated_cats(p, sig1, sig2, contrasts, d_noise_big, raw);
        
        if ~model.d_noise
            k = fliplr(x_bounds(:,4)');
            x_bounds = [zeros(6,1) x_bounds inf(6,1)]; % this is for confidence
        elseif model.d_noise
            % for d noise, need long noisesets x trials matrix
            k = permute(x_bounds(3,:,:),[3 2 1]);
        end
    end
    
elseif strcmp(model.family, 'lin')
    k = max(bf(0) + mf(0) * sigs, 0);
elseif strcmp(model.family, 'quad')
    k = max(bf(0) + mf(0) * sigs.^2, 0);
elseif strcmp(model.family, 'fixed')
    k = bf(0)*ones(1,nContrasts);
elseif strcmp(model.family, 'MAP')
    dx=.5;
    zoomgrid = 0;
    if zoomgrid
        dx_fine = .1;
        fine_length = 2*dx / dx_fine + 1;
    end
    
    x = (0:dx:180)';
    xSteps = length(x);
    shat_lookup_table = zeros(nContrasts,xSteps);
    k = zeros(1,nContrasts);
    ksq1 = sqrt(1./(sigs.^-2 + sig1^-2));
    ksq2 = sqrt(1./(sigs.^-2 + sig2^-2));
    
    for c = 1:nContrasts
        cur_sig = sigs(c);
        mu1 = x*cur_sig^-2 * ksq1(c)^2;
        mu2 = x*cur_sig^-2 * ksq2(c)^2;
        
        shat_lookup_table(c,:) = gmm1max_n2_fast([normpdf(x,0,sqrt(sig1^2 + cur_sig^2)) normpdf(x,0,sqrt(sig2^2 + cur_sig^2))],...
            [mu1 mu2], repmat([ksq1(c) ksq2(c)],xSteps,1));
        
        k(c) = lininterp1(shat_lookup_table(c,:), x, p.b_i(5));
        if zoomgrid
            x_fine = (k(c)-dx : dx_fine : k(c)+dx)';
            mu1 = x_fine*cur_sig^-2 * ksq1(c)^2;
            mu2 = x_fine*cur_sig^-2 * ksq2(c)^2;
            fine_lookup_table = gmm1max_n2_fast([normpdf(x_fine,0,sqrt(sig1^2 + cur_sig^2)) normpdf(x_fine,0,sqrt(sig2^2 + cur_sig^2))],...
                [mu1 mu2], repmat([ksq1(c) ksq2(c)],fine_length,1));
            
            k(c) = lininterp1(fine_lookup_table, x_fine, p.b_i(5));
        end
    end
end
sig = sigs(raw.contrast_id);

if ~(model.non_overlap && model.d_noise)
    % do this for all models except nonoverlap+d noise, where k is already in this form.
    k = k(:,raw.contrast_id);
end

if model.d_noise
    p_choice = -repmat(raw.Chat, nDNoiseSets, 1) .* f(k, repmat(raw.s, nDNoiseSets, 1), repmat(sig, nDNoiseSets, 1), optflag) + 0.5*repmat(raw.Chat, nDNoiseSets, 1) + 0.5;
    p_choice = normalized_weights*p_choice;
else
    p_choice = -raw.Chat .* f(k,raw.s,sig,optflag) + 0.5*raw.Chat + 0.5;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% CONFIDENCE PROBABILITY %%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% a and b are the confidence/category lower and upper decision boundaries in measurement space around the confidence/category response on each trial.
% f computes the prob. mass that falls between a and b
if ~model.choice_only
    if ~isfield(raw, 'g')
        error('You are trying to fit confidence responses in a dataset that has no confidence trials.')
    end
    % there are redundant calculations that go into a and b but i think it's okay, and that getting rid of them wouldn't result in a huge speedup. see note above.
    if strcmp(model.family,'opt')
        
        if ~model.non_overlap
            k1 = k1(raw.contrast_id);
            k2 = k2(raw.contrast_id);
            
            a = sqrt(repmat(k1 - bf((raw.Chat - 1)./2 - raw.Chat .* raw.g), nDNoiseSets, 1) + d_noise_big) ./ repmat(sqrt(k2), nDNoiseSets, 1);
            b = sqrt(repmat(k1 - bf((raw.Chat + 1)./2 - raw.Chat .* raw.g), nDNoiseSets, 1) + d_noise_big) ./ repmat(sqrt(k2), nDNoiseSets, 1);
        elseif model.non_overlap
            %contrast id is more of a sig id. higher means lower contrast. so we need to reverse it.
            % this indexing stuff is a bit of a hack to make sure that term1 and term2 for each trial specify the correct
            % upper and lower bounds on the measurement, from the x_bounds (contrasts X decision boundaries) matrix made above.
            if ~model.d_noise
                a = raw.Chat .* max(x_bounds((4 + raw.Chat .* raw.g) * nContrasts + (nContrasts + 1 - raw.contrast_id)),0);
                b = raw.Chat .* max(x_bounds((4 + raw.Chat .* (raw.g - 1)) * nContrasts + (nContrasts + 1 - raw.contrast_id)),0);
            else
                a = permute(x_bounds(1,:,:),[3 2 1]); % reshape top half of x_bounds
                b = permute(x_bounds(2,:,:),[3 2 1]); % reshape bottom half
            end
        end
    elseif strcmp(model.family, 'lin')
        a = raw.Chat .* max(bf(raw.Chat .* (raw.g    )) + sig .* mf(raw.Chat .* (raw.g    )), 0);
        b = raw.Chat .* max(bf(raw.Chat .* (raw.g - 1)) + sig .* mf(raw.Chat .* (raw.g - 1)), 0);
    elseif strcmp(model.family, 'quad')
        a = raw.Chat .* max(bf(raw.Chat .* (raw.g    )) + sig.^2 .* mf(raw.Chat .* (raw.g    )), 0);
        b = raw.Chat .* max(bf(raw.Chat .* (raw.g - 1)) + sig.^2 .* mf(raw.Chat .* (raw.g - 1)), 0);
    elseif strcmp(model.family, 'fixed')
        a = raw.Chat .* bf(raw.Chat .* (raw.g)    );
        b = raw.Chat .* bf(raw.Chat .* (raw.g - 1));
        
    elseif strcmp(model.family, 'MAP')
        x_bounds = zeros(nContrasts, conf_levels*2-1);
        for c = 1:nContrasts
            cur_sig = sigs(c);
            for r = 1:conf_levels*2-1
                x_bounds(c,r) = lininterp1(shat_lookup_table(c,:), x, p.b_i(1+r));
                if zoomgrid
                    x_fine = (x_bounds(c,r)-dx : dx_fine : x_bounds(c,r)+dx)';
                    mu1 = x_fine*cur_sig^-2 * ksq1(c)^2;
                    mu2 = x_fine*cur_sig^-2 * ksq2(c)^2;
                    fine_lookup_table = gmm1max_n2_fast([normpdf(x_fine,0,sqrt(sig1^2 + cur_sig^2)) normpdf(x_fine,0,sqrt(sig2^2 + cur_sig^2))],...
                        [mu1 mu2], repmat([ksq1(c) ksq2(c)],fine_length,1));
                    x_bounds(c,r) = lininterp1(fine_lookup_table, x_fine, p.b_i(1+r));
                end
            end
        end
        save nltest
        x_bounds = [zeros(6,1) flipud(x_bounds) inf(6,1)];
        a = raw.Chat .* max(x_bounds((4 + raw.Chat .* raw.g) * nContrasts + (nContrasts + 1 - raw.contrast_id)),0);
        b = raw.Chat .* max(x_bounds((4 + raw.Chat .* (raw.g - 1)) * nContrasts + (nContrasts + 1 - raw.contrast_id)),0);
    end
    
    if model.d_noise
        fa = f(a, repmat(raw.s, nDNoiseSets, 1), repmat(sig, nDNoiseSets, 1), optflag);
        fb = f(b, repmat(raw.s, nDNoiseSets, 1), repmat(sig, nDNoiseSets, 1), optflag);
        p_conf_choice = fa - fb;
        
        p_conf_choice = normalized_weights*p_conf_choice;
    else
        p_conf_choice = f(a,raw.s,sig,optflag) - f(b,raw.s,sig,optflag);
         %if sum(p_conf_choice<0)~=0
             %fprintf('%g trials where f(b)>f(a)\n',sum(p_conf_choice<0))
             %save nltest.mat
         %end
        p_conf_choice = max(0,p_conf_choice); % this max is a hack. it covers for non overlap x_bounds being weird.
    end
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% LAPSES %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
if isfield(p, 'lambda_i')
    p_full_lapse = p.lambda_i(raw.g)/2;
    p.lambda = sum(p.lambda_i);
else
    if ~isfield(p, 'lambda') % this is only for a few d_noise models that are probably deprecated
        p.lambda=0;
    end
    p_full_lapse = p.lambda/8;
end

if ~isfield(p, 'lambda_g')
    p.lambda_g = 0;
end

if ~model.choice_only
    p_repeat = [0 diff(raw.resp)==0];
else
    p_repeat = [0 diff(raw.Chat)==0];
end

if ~isfield(p, 'lambda_r')
    p.lambda_r = 0;
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% COMPUTE LOG LIKELIHOOD %%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if ~model.choice_only
    loglik_vec = log (p_full_lapse + ...
        (p.lambda_g / 4) * p_choice + ...
        p.lambda_r * p_repeat + ...
        (1 - p.lambda - p.lambda_g - p.lambda_r) * p_conf_choice);
    
else % choice models
    loglik_vec = log(p.lambda / 2 + ...
        p.lambda_r * p_repeat + ...
        (1 - p.lambda - p.lambda_r) * p_choice);
    
end

% Set all -Inf logliks to an arbitrarily small number. It looks like these
% trials are all ones in which abs(s) was very large, and the subject
% didn't respond with full confidence. This occurs about .3% of trials.
% Shouldn't happen with lapse rate
loglik_vec(loglik_vec < -1e5) = -1e5;
nloglik = - sum(loglik_vec);

if ~isreal(nloglik)
    % this is a big problem for truncated cats.
    %fprintf('imaginary nloglik\n')
    %nloglik
    %save nl_unreal.mat
    nloglik = real(nloglik) + 1e3; % is this an okay way to avoid "undefined at initial point" errors? it's a hack.
end
if nloglik == Inf % is this ever happening?
    %fprintf('infinite nloglik\n')
    %save nl_inf.mat
    %nloglik = 1e10;
end
end

function retval = f(y,s,sigma,optflag)
retval              = zeros(size(s)); % length of all trials
if optflag
    idx           = find(y>0);      % find all trials where y is greater than 0. y is either positive or imaginary. so a non-positive y would indicate negative a or b
    s                   = s(idx);
    sigma               = sigma(idx);
    y                   = y(idx);
else
    idx = find(s);
end
retval(idx)   = .5 * (erf((s+y)./(sigma*sqrt(2))) - erf((s-y)./(sigma*sqrt(2)))); % erf is faster than normcdf.
end

function bval = bf(name)
global p conf_levels
%bval = p.b_i(name + repmat(conf_levels + 1, 1, length(name)));
bval = p.b_i(name + conf_levels + 1);
end

function mval = mf(name)
global p conf_levels
mval = p.m_i(name + conf_levels + 1);
end

function aval = af(name)
global p conf_levels
aval = p.a_i(name + conf_levels + 1);
end

function d_boundsval = d_boundsf(name)
global conf_levels d_bounds
d_boundstmp = [Inf d_bounds 0];
d_boundsval = d_boundstmp(name + conf_levels + 1);
end

