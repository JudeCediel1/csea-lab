function [IBIvecClean, IBIvecClean1, correctedflag] = HR_artifact(IBIvecInSecs)
%gets IBI vector, in seconds, gets rid of artifacts

IBIvecClean1 = [];
correctedflag = 0; 

% missing R waves, too long IBIS
count = 1; 
for index = 1:length(IBIvecInSecs)
   if IBIvecInSecs(index) > 1.65
      IBIvecClean1(count)  = IBIvecInSecs(index)./2; 
       IBIvecClean1(count+1)  = IBIvecInSecs(index)./2;
      count = count+1;
      correctedflag(index) = 1;
   else
       IBIvecClean1(count)  = IBIvecInSecs(index);
      correctedflag(index) = 0;
   end
   count = count+1;
end

% too short IBIs, double peaks, noise etc
IBIvecClean = IBIvecClean1;
count1 = 1; 
count2 = 1;

for index = 1:length(IBIvecClean1)-1
   if IBIvecClean1(index) < .65
       IBIvecClean(count1) = IBIvecClean1(index) + IBIvecClean1(index+1); 
       IBIvecClean(count1+1) = nan;
       count1 = count1+2;
       correctedflag(index) = 1;
   else
    IBIvecClean(count1)  = IBIvecClean1(index);
   end
  count1 = count1+1;

end

% get rid of nans and 0s
IBIvecClean(isnan(IBIvecClean)) = []; 
IBIvecClean(IBIvecClean==0) = []; 
