addpath(genpath('../Libraries/eeglab12_0_2_5b'));
%Prasad is gay
f = ls('dataset1/*calib*.mat');

eeglab; clc;

%this for loop iterates over all datasets in dataset1. i've commented out
%the iteration because we will implement the algorithms for one dataset
%first.
for fid = 1%:size(f,1) 
   
   fn = cat(2, 'dataset1/',strtrim(f(fid,:)));
   data= load(fn);
    
   %in order to store eeg information in EEGLAB through scripts, we must
   %first create a struct with several properties. Some of these properties
   %are known, but some are not, but they still need to be initialized.
   NE.setname = strtrim(f(fid,:));
   NE.filename = '';
   NE.filepath = '';
   NE.pnts = size(data.cnt, 1);
   NE.nbchan = size(data.cnt,2);
   NE.srate = data.nfo.fs;
   %NE.ref = '';
   NE.data = 0.1*double(data.cnt');
   NE.icawinv = [];
   NE.icasphere= [];
   NE.icaweights = [];
   NE.icaact = [];  
   NE.trials = 0;
   NE.comments =[];
   NE.xmin = 0;
   NE.xmax = NE.pnts*NE.srate;
   
   %channel information processing
   for i = 1:length(data.nfo.clab)
        NE.chanlocs(i).labels = data.nfo.clab{i};
        NE.chanlocs(i).X = data.nfo.xpos(i);
        NE.chanlocs(i).Y= data.nfo.ypos(i);
   end
    
   %event information processing
   for i = 1:length(data.mrk.y);
       NE.event(i).type = data.mrk.y(i);
       NE.event(i).latency = data.mrk.pos(i);
   end
   
   eeg_checkset(NE);
   classes=data.nfo.classes;
   [ALLEEG, ~, ~] = eeg_store(ALLEEG, NE); 
   
   %we slice the eeg recordings into several epochs (0.5 to 3.5s after the stimulus), and grab the epochs
   %with -1 and +1 labels seperately.
   EEG = pop_epoch( NE, {  '-1'  }, [0.5         3.5], 'newname', '-1 epochs', 'epochinfo', 'yes');
   [ALLEEG, EEG, ~] = eeg_store(ALLEEG, EEG);
    class1=EEG.data; %eeg epocjs corresponding to class 1 in a m x n x o (channels x timepoints x epochs) matrix where o is the number of epochs
   
   EEG = pop_epoch( NE,  {  '1'  }, [0.5         3.5], 'newname', '+1 epochs', 'epochinfo', 'yes');
   [ALLEEG, EEG, ~] = eeg_store(ALLEEG, EEG); 
   class2=EEG.data;
   eeglab redraw
end

n = size(class1,3);

% the below code is for cross validation 

testamt = ceil(0.2*n); %amount of testing set 
testingIndices = n:-1:n-testamt; %index values for testing set

trainamt = n - testamt; %amount of training set
subsetRatio  = 0.9; %percentage of training labels used for cross validation

%%
%these are function handles for nearest means (nm), naive bayes(nb),
%mahalanobis distance (md), and balanced error (ber)

nmd = @(p1, p2) sum(sum((p1-p2).^2));
nbd = @(p1, p2,s) sum(sum(((p1-p2)./s).^2));
md = @(P1, M,R) sum(sum(((P1-M)'*R*(P1-M)).^2));
ber = @(a,b,c,d) .5*(a/(a+b) + c/(c+d));

nfolds=10;
err_nm = zeros(1, nfolds);
err_nb = zeros(1, nfolds);
err_md = zeros(1, nfolds);
err_knn = zeros(1, nfolds);
    
for folds = 1:nfolds
    trainingIndices1 = randperm(round(subsetRatio*trainamt)); %index values for training set
    trainingIndices2 = randperm(round(subsetRatio*trainamt)); %index values for training set
    
    traindata1 = class1(:,:,trainingIndices1);
    traindata2 = class1(:,:,trainingIndices2);
    
    m1 = mean(traindata1, 3);
    s1 = std(traindata1,1,3);
    
    m2 = mean(traindata2, 3);
    s2 = std(traindata2,1,3);
    
    %covariance 
    r1 = zeros(size(traindata1,1));
    r2 = zeros(size(traindata1,1));
    
    for pages = 1:size(traindata1)
       r1 = r1 + cov(traindata1(:,:,pages)');
       r2 = r2 + cov(traindata1(:,:,pages)');
    end
    r1 = r1/pages;
    r2 = r2/pages;
    
    %nearest means
    a=0;b=0;c=0;d=0;
   
    for i = testingIndices
       cts1 = class1(:,:,i);
       d1 = nmd(cts1, m1);
       d2 = nmd(cts1, m2);
       if(d2>d1)a=a+1; else b=b+1; end
       
       cts2 = class2(:,:,i);
       d1 = nmd(cts2, m1);
       d2 = nmd(cts2, m2);
       if(d1>d2)d=d+1; else c=c+1; end
    end
    err_nm(folds) = ber(a,b,c,d);
    
    %naive bayes
    a=0;b=0;c=0;d=0;
   
    for i = testingIndices
       cts1 = class1(:,:,i);
       d1 = nbd(cts1, m1, s1);
       d2 = nbd(cts1, m2, s2);
       if(d2>d1)a=a+1; else b=b+1; end
       
       cts2 = class2(:,:,i);
       d1 = nbd(cts2, m1, s1);
       d2 = nbd(cts2, m2, s2);
       if(d1>d2)d=d+1; else c=c+1; end
    end
    err_nb(folds) = ber(a,b,c,d);
   
    % mahalobonis distance
    a=0;b=0;c=0;d=0;
    
    for i = testingIndices
       cts1 = class1(:,:,i);
       d1 = md(cts1, m1, r1);
       d2 = md(cts1, m2, r2);
       if(d2>d1)a=a+1; else b=b+1; end
       
       cts2 = class2(:,:,i);
       d1 = md(cts2, m1,r1);
       d2 = md(cts2, m2,r2);
       if(d1>d2)d=d+1; else c=c+1; end
    end
    err_md(folds) = ber(a,b,c,d);
    
    % 3-nearest means
    k=5;
    distances1 = zeros(1,size(traindata1,3));
    distances2 = zeros(1,size(traindata1,3));
    
    for i = testingIndices
       cts = class1(:,:,i);
       
       for j = 1:size(traindata1,3)
        distances1(j) = nmd(cts, traindata1(:,:,j));
        distances2(j) = nmd(cts, traindata2(:,:,j));
       end
       ds = [distances1, distances2];
       [sds, IDX] = sort(ds, 'descend');
       
       classvec = [ones(1, size(class1,3)) 2*ones(1, size(class1,3))];
       newclassvec = classvec(IDX);
       
       if(mode(newclassvec(1:k))==2) a=a+1; else b=b+1; end
       
       
       cts2 = class2(:,:,i);
       
       for j = 1:size(traindata1,3)
        distances1(j) = nmd(cts2, traindata1(:,:,j));
        distances2(j) = nmd(cts2, traindata2(:,:,j));
       end
        ds = [distances1, distances2];
       [sds, IDX] = sort(ds, 'descend');
       
       classvec = [ones(1, size(class1,3)) 2*ones(1, size(class1,3))];
       newclassvec = classvec(IDX);
       
        if(mode(newclassvec(1:k))==1)d=d+1; else c=c+1; end
    end
        err_knn(folds) = ber(a,b,c,d);
        
        
end

fprintf('Nearest Means: %0.4f (%0.4f)\n', mean(err_nm), std(err_nm));
fprintf('Naive Bayes: %0.4f (%0.4f)\n', mean(err_nb), std(err_nb));
fprintf('Mahalanobis Distance: %0.4f (%0.4f)\n', mean(err_md), std(err_md));
fprintf('3 Nearest Neighbors: %0.4f (%0.4f)\n', mean(err_knn), std(err_knn));