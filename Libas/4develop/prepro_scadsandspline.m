function [EEG_allcond] =  prepro_scadsandspline(datapath, logpath, stringlength, skiptrials)

    thresholdChanTrials = 2.5; 
    thresholdTrials = 1.25;
    thresholdChan = 2.5;
    
    % skip a few initial trials tyo accomodate learning experiments
    if nargin < 4, skiptrials = 1; end % default no initial trials are skipped

    basename  = datapath(1:stringlength); 

     %read data into eeglab
     EEG = pop_readegi(datapath, [],[],'auto');
     EEG=pop_chanedit(EEG, 'load',{'GSN-HydroCel-129.sfp','filetype','autodetect'});
     EEG.setname='temp';
     EEG = eeg_checkset( EEG );
     
     % bandpass filter
     filtord = 5; 
     [B,A] = butter(filtord,[3 30]/(EEG.srate/2));
     filtereddata = filtfilt(B,A,double(EEG.data)')'; % 
     EEG.data =  single(filtereddata); 
     EEG = eeg_checkset( EEG );

     % eye blink correction with Biosig
     [~,S2] = regress_eog(double(EEG.data'), 1:128, sparse([125,128,25,127,8,126],[1,1,2,2,3,3],[1,-1,1,-1,1,-1]));
     EEG.data = single(S2');
     EEG = eeg_checkset( EEG );
    
     %read conditions from log file;
     conditionvec = getcon_konio(logpath);

      % now get rid of excess event markers 
      for indexlat = 1:size(EEG.event,2)
        markertimesinSP(indexlat) = EEG.event(indexlat).latency;
      end

      tempdiff1 = diff([0 markertimesinSP]);

      eventsend = markertimesinSP(tempdiff1>20);

      eventsdiscard = (tempdiff1<20);

      disp(['a total of ' num2str(length(eventsend)) ' markers were found in the file'])

      EEG.event(find(eventsdiscard)) = [];

     % now we replace the DIN with the condition  
      counter = 1; 
      for x = 1:size(EEG.event,2) %  
          if strcmp(EEG.event(x).type(1:3), 'DIN')
              EEG.event(x).type = num2str(conditionvec(counter)); 
              counter = counter+1; 
          end
      end

     % Epoch the EEG data 
     EEG_allcond = pop_epoch( EEG, {  '21' '22' '23' '24' }, [-0.6 3.802], 'newname', 'allcond', 'epochinfo', 'yes');
     EEG_allcond = eeg_checkset( EEG_allcond );
     EEG_allcond = pop_rmbase( EEG_allcond, [-600 0] ,[]);
     inmat3d = double(EEG_allcond.data);

     % find generally bad channels
     [outmat3d, BadChanVec] = scadsAK_3dchan(inmat3d, 'HC1-128.ecfg', thresholdChan); 
     EEG_allcond.data = single(outmat3d); 
     EEG_allcond = eeg_checkset( EEG_allcond );

    % find bad channels in epochs
    [ outmat3d, badindexmat] = scadsAK_3dtrialsbychans(outmat3d, thresholdChanTrials, 'HC1-128.ecfg');
     EEG_allcond.data = single(outmat3d);
     EEG_allcond = eeg_checkset( EEG_allcond );

      % find bad trials and reject in epochs
    [ outmat3d, badindexvec, NGoodtrials ] = scadsAK_3dtrials(outmat3d, thresholdTrials);
      EEG_allcond = pop_select( EEG_allcond, 'notrial', badindexvec);

     %% select conditions
     % 21
     EEG_21 = pop_selectevent( EEG_allcond,  'type', '21' );
     EEG_21 = eeg_checkset( EEG_21 );
     % 22
     EEG_22 = pop_selectevent( EEG_allcond,  'type', '22' );
     EEG_22= eeg_checkset( EEG_22 );  
     % 23
     EEG_23 = pop_selectevent( EEG_allcond,  'type', '23' );
     EEG_23= eeg_checkset( EEG_23 );
     % 24
     EEG_24 = pop_selectevent( EEG_allcond,  'type', '24' );
     EEG_24 = eeg_checkset( EEG_24 );

      %% create output file for artifact summary. 
      artifactlog.globalbadchans = BadChanVec;
      artifactlog.epochbadchans = badindexmat;
      artifactlog.badtrialstotal = badindexvec; 
      artifactlog.badtrialsbycondition = [size(EEG_21.data, 3),size(EEG_22.data, 3), size(EEG_23.data, 3),size(EEG_24.data, 3)];

      %% create avg reference 3-D mats
      Mat21 = avg_ref_add3d(double(EEG_21.data));
      Mat22 = avg_ref_add3d(double(EEG_22.data));
      Mat23 = avg_ref_add3d(double(EEG_23.data));
      Mat24 = avg_ref_add3d(double(EEG_24.data));

      %% compute ERPs
     ERP21 = double(avg_ref_add(squeeze(mean(EEG_21.data(:, :, skiptrials:end), 3))));
     ERP22 = double(avg_ref_add(squeeze(mean(EEG_22.data(:, :, skiptrials:end), 3))));
     ERP23 = double(avg_ref_add(squeeze(mean(EEG_23.data(:, :, skiptrials:end), 3))));
     ERP24 = double(avg_ref_add(squeeze(mean(EEG_24.data(:, :, skiptrials:end), 3)))); 

     %% save output
     % the ERPs
     SaveAvgFile([basename '.at21.ar'],ERP21,[],[], 500, [], [], [], [], 301); 
     SaveAvgFile([basename '.at22.ar'],ERP22,[],[], 500, [], [], [], [], 301); 
     SaveAvgFile([basename '.at23.ar'],ERP23,[],[], 500, [], [], [], [], 301); 
     SaveAvgFile([basename '.at24.ar'],ERP24,[],[], 500, [], [], [], [], 301); 

     % the 3d mat files
     save([basename '.trls.21.mat'], 'Mat21', '-mat')
     save([basename '.trls.22.mat'], 'Mat22', '-mat')
     save([basename '.trls.23.mat'], 'Mat23', '-mat')
     save([basename '.trls.24.mat'], 'Mat24', '-mat')

     % the artifact info
     save([basename '.artiflog.mat'], 'artifactlog', '-mat')






    



     