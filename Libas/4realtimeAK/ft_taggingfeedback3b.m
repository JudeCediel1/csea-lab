function [data, powsum] = ft_taggingfeedback3mac(cfg, targfreq, distfreq)

% reads a file from disk (or in realtime) 
% uses new FFT-Spectrum routine and plots data along with uncorrected spectrum
% based ON:
% FT_REALTIME_POWERESTIMATE is an example realtime application for online
% power estimation. It should work both for EEG and MEG.
%
% Use as
%   ft_realtime_powerestimate(cfg)
% with the following configuration options
%   cfg.channel    = cell-array, see FT_CHANNELSELECTION (default = 'all')
%   cfg.foilim     = [Flow Fhigh] (default = [0 120])
%   cfg.blocksize  = number, size of the blocks/chuncks that are processed (default = 1 second)
%   cfg.bufferdata = whether to start on the 'first or 'last' data that is available (default = 'last')
%
% The source of the data is configured as
%   cfg.dataset       = string
% or alternatively to obtain more low-level control as
%   cfg.datafile      = string
%   cfg.headerfile    = string
%   cfg.eventfile     = string
%   cfg.dataformat    = string, default is determined automatic
%   cfg.headerformat  = string, default is determined automatic
%   cfg.eventformat   = string, default is determined automatic
%
% To stop the realtime function, you have to press Ctrl-C

% Copyright (C) 2008, Robert Oostenveld
%
% Subversion does not use the Log keyword, use 'svn log <filename>' or 'svn -v log | less' to get detailled information

% set the default configuration options
if ~isfield(cfg, 'dataformat'),     cfg.dataformat = [];      end % default is detected automatically
if ~isfield(cfg, 'headerformat'),   cfg.headerformat = [];    end % default is detected automatically
if ~isfield(cfg, 'eventformat'),    cfg.eventformat = [];     end % default is detected automatically
if ~isfield(cfg, 'blocksize'),      cfg.blocksize = 1;        end % in seconds
if ~isfield(cfg, 'channel'),        cfg.channel = 'all';      end
if ~isfield(cfg, 'foilim'),         cfg.foilim = [0 120];     end
if ~isfield(cfg, 'bufferdata'),     cfg.bufferdata = 'last';  end % first or last

% translate dataset into datafile+headerfile
if ~isfield(cfg, 'dataset') && ~isfield(cfg, 'header') && ~isfield(cfg, 'datafile')
  cfg.dataset = 'buffer://localhost:1972';
end
cfg = ft_checkconfig(cfg, 'dataset2files', 'yes');
cfg = ft_checkconfig(cfg, 'required', {'datafile' 'headerfile'});

% ensure that the persistent variables related to caching are cleared
clear ft_read_header
% start by reading the header from the realtime buffer
hdr = ft_read_header(cfg.headerfile, 'cache', true, 'retry', true);

% define a subset of channels for reading
cfg.channel = ft_channelselection(cfg.channel, hdr.label);
chanindx    = match_str(hdr.label, cfg.channel);
nchan       = length(chanindx);
if nchan==0
  error('no channels were selected');
end

summandappend = []; 

% determine the size of blocks to process
blocksize = round(cfg.blocksize * hdr.Fs);

% this is used for scaling the figure
powmax = 0;

% set up the lowpass filter at 40 Hz and highpass at 5 Hz

  [Blow,Alow] = butter(2, 24/(hdr.Fs/2)); 
    
  [Bhigh,Ahigh] = butter(4, 5/(hdr.Fs/2), 'high'); 
	

% enter the loop 
prevSample  = 0;
count       = 0;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% this is the general BCI loop where realtime incoming data is handled
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
while true 

  % determine number of samples available in buffer
  hdr = ft_read_header(cfg.headerfile, 'cache', true);

  % see whether new samples are available
  newsamples = (hdr.nSamples*hdr.nTrials-prevSample);

  if newsamples>=blocksize

    % determine the samples to process
    if strcmp(cfg.bufferdata, 'last')
      begsample  = hdr.nSamples*hdr.nTrials - blocksize + 1;
      endsample  = hdr.nSamples*hdr.nTrials;
    elseif strcmp(cfg.bufferdata, 'first')
      begsample  = prevSample+1;
      endsample  = prevSample+blocksize ;
    else
      error('unsupported value for cfg.bufferdata');
    end

    % remember up to where the data was read
    prevSample  = endsample;
    count       = count + 1;
    fprintf('processing segment %d from sample %d to %d\n', count, begsample, endsample);

    % read data segment from buffer
    dat = ft_read_data(cfg.datafile, 'header', hdr, 'begsample', begsample, 'endsample', endsample, 'chanindx', chanindx, 'checkboundary', false);
    datsize = size(dat); 
    
    % flip and filter
    dat = dat'; 
    lowpasssig = filtfilt(Blow,Alow, dat); 
    lowhighpasssig = filtfilt(Bhigh, Ahigh, lowpasssig);
    dat = lowhighpasssig'; 
  
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % from here onward it is specific to the power estimation from the data
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % put the data in a fieldtrip-like raw structure
    data.trial{count} = dat';
    data.time{count}  = offset2time(begsample, hdr.Fs, endsample-begsample+1);
    data.label    = hdr.label(chanindx);
    data.hdr      = hdr;
    data.fsample  = hdr.Fs;
    data.label;

    % apply preprocessing options first high then lowpass
   % data.trial{1} = ft_preproc_baselinecorrect(data.trial{1});
   
    figure(5)
    plot (data.trial{count})

   
 % size(data.trial{1}) 
 % data.fsample
    
    [pow, phase, freqs] = FFT_spectrum(data.trial{count}', data.fsample);
   
    %calculate the frequencies, the differences, and the tone
    % first extract the frequencies of interest
    
    targindex = find(round(freqs.*100) == targfreq.*100);
    distindex = find(round(freqs.*100) == distfreq.*100);
    
    minfreqplotIndex = min(targindex, distindex) - round(length(freqs)./40) 
    maxfreqplotIndex = max(targindex, distindex) + round(length(freqs)./40) 
    
   if nchan > 1
    pow    = sum(pow/nchan); 
   end
        
    summand = mean(((pow(1,targindex)- pow(1, distindex)))).*15; %./(pow(1, targindex)+pow(1, distindex)).*100)); 
    summandappend = [summandappend summand]; 
    figure(10), plot(summandappend)
    taxis = 0:0.001:1; 
    sound(double((sin((1000-summand).*pi .*taxis)))) 
    
  figure(1)
    h = get(gca, 'children');
    hold on

    if ~isempty(h)
      % done on every iteration
      delete(h);
    end

    if isempty(h)
      % done only once
      powmax = 0;
      grid on
    end
    
    freqs(minfreqplotIndex); 
    
    powmax = max(max(pow)); % this keeps a history
    
    size(freqs(minfreqplotIndex:maxfreqplotIndex))
    size(pow)
    
    plot(freqs(minfreqplotIndex:maxfreqplotIndex), pow(minfreqplotIndex:maxfreqplotIndex));
   axis([min(freqs(minfreqplotIndex)) min(freqs(maxfreqplotIndex)) 0 50]);

    str = sprintf('time = %d s\n', round(mean(data.time{count})));
    title(str);    
    xlabel('frequency (Hz)');
    ylabel('power');
    hold on
    plot(freqs(targindex), pow(targindex), '*g')
    plot(freqs(distindex), pow(distindex), '*r')
    hold off

    % force Matlab to update the figure
    drawnow
    %pause(.3)
    pause
      if count ==1, powsum = pow; else powsum = powsum + pow; end% add it up across experiment to get sum of the total spectra

  else break,
  end % if enough new samples
end % while true

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% SUBFUNCTION
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [time] = offset2time(offset, fsample, nsamples)
offset   = double(offset);
nsamples = double(nsamples);
time = (offset + (0:(nsamples-1)))/fsample;