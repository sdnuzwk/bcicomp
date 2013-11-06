addpath('dataset1');
addpath(genpath('../Libraries/eeglab12_0_2_5b'));
f = ls('dataset1/*calib*.mat');

eeglab
for fid = 1%:size(f,1)
   
   fn = cat(2, 'dataset1/',strtrim(f(fid,:)));
   data= load(fn);
    
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
   
   EEG = pop_epoch( NE, {  '-1'  }, [0.5         3.5], 'newname', '-1 epochs', 'epochinfo', 'yes');
   [ALLEEG, EEG, ~] = eeg_store(ALLEEG, EEG);
    class1=EEG.data; 
   
   EEG = pop_epoch( NE,  {  '1'  }, [0.5         3.5], 'newname', '+1 epochs', 'epochinfo', 'yes');
   [ALLEEG, EEG, ~] = eeg_store(ALLEEG, EEG); 
   class2=EEG.data;
   eeglab redraw
end

n = size(class1,3);

testamt = ceil(0.1*n); %amount of testing set 
testingIndices = n:-1:n-testamt; %index values for testing set

trainamt = n - testamt; %amount of training set
subsetRatio  = 0.9; %percentage of training labels used for cross validation



nmd = @(p1, p2) sum(sum((p1-p2).^2));
nbd = @(p1, p2,s) sum(sum(((p1-p2)./s).^2));
md = @(p1, p2,s) sum(sum(((p1-p2)./s).^2));
ber = @(a,b,c,d) .5*(a/(a+b) + c/(c+d));
for folds = 1:10
    trainingIndices1 = randperm(round(subsetRatio*trainamt)); %index values for training set
    trainingIndices2 = randperm(round(subsetRatio*trainamt)); %index values for training set
    
    traindata1 = class1(:,:,trainingIndices1);
    traindata2 = class1(:,:,trainingIndices2);
    
    m1 = mean(traindata1, 3);
    s1 = std(traindata1,1,3);
    
    m2 = mean(traindata1, 3);
    s2 = std(traindata2,1,3);
    
    %nearest means
    a=0;b=0;c=0;d=0;
    err_nm = [];
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
    err_nm(end+1) = ber(a,b,c,d);
    
    %naive bayes
    a=0;b=0;c=0;d=0;
    err_nb = [];
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
    err_nb(end+1) = ber(a,b,c,d);
   
end
fprintf('Nearest Means: %0.4f (%0.4f)\n', mean(err_nm), std(err_nm));
fprintf('Naive Bayes: %0.4f (%0.4f)\n', mean(err_nb), std(err_nb));


