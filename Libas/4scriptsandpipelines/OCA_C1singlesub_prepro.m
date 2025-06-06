%% Script for analyzing all C1 OCA data
% Get a list of all files and folders in the current directory
temp99 = eeglab; 

cd ('/Volumes/G-RAID Thunderbolt 3/OCA_project/OCA_C1')

files = dir("C1*");

% Filter out the non-folder entries
dirFlags = [files.isdir];

% Extract the names of the folders
folderNames = {files(dirFlags).name};

% Remove the '.' and '..' folders
folderNames = folderNames(~ismember(folderNames, {'.', '..'}));

% Display the folder names
disp('Folders in the current working directory:');
disp(folderNames);

% loop over subjects
for subindex = 1:size(folderNames,2)

    eval(['cd ' folderNames{subindex}])

   delete *.at*

    datfile = getfilesindir(pwd, '*.dat');
    rawfile = getfilesindir(pwd, '*.RAW');

    % actual preprocessing
   prepro_scadsandspline_log(rawfile, datfile, 'getcon_COARD_C1', 11, {'1' '2'}, [-.4 .4], [.1  30], [3 9], 1, 'GSN-HydroCel-256.sfp', 'HC1-256.ecfg')
   % prepro_scadsandspline_log(datapath, logpath, convecfun, stringlength, conditions2select, timevec, filtercoeffHz, filtord, skiptrials, sfpfilename, ecfgfilename)
    cd ..

    pause(.5)
    fclose('all');

end
