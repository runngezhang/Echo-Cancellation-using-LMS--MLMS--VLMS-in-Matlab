function LVxLMSAdaptFiltEcho(k,Mu,DHorSH,MuteNrEnd,DblTkUpD,SampsVOX,VOXThresh)
% function LVxLMSAdaptFiltEcho(k,Mu,DHorSH,MuteNrEnd,DblTkUpD,SampsVOX,VOXThresh)
% k is the amount of noise to add to the interference signal ('drwatsonSR8K.wav')
% Mu is the usual LMS update term weight;
% DHorSH yields a Dual-H system if passed as 1, or a Single-H system if passed as 0; 
% MuteNrEnd mutes the desired signal ('drwatsonSR8K.wav') at its very beginning if passed as 1, a
% bout one-third of the way through if passed as 2, or no muting at all if passed as 0.
% When in Single-H mode, DblTkUpD, if passed as 0, allows coefficient updating any time, but if
% passed as 1 prevents coefficient update when the most recent SampsVOX samples of
% the desired (Near End) signal level are above VOXThresh.
% In Dual-H mode, the input arguments DblTkUpD,SampsVOX,VOXThresh are ignored.
% The Far End signal is the audio file 'whoknowsSR8K.wav', limited to the length of 'drwatsonSR8K/wav'
% The adaptive FIR is ten samples long and the echo is simulated as a single delay of 6 samples, for 
% example.
% A figure having four subplots is created. The first subplot shows the values of all ten FIR coefficients 
% over the entire course of computation; the second subplot shows the filtered output signal; the third 
% subplot shows as a binary plot whether or not coefficient update was allowed at any given stage of the 
% computation based on the detection of Near End speech; the fourth subplot shows the figure of merit 
% (ERLE, as defined in the text) over the course of the computation.
% The adaptive FIR is ten samples long and the echo is simulated as a single delay of 6 samples, for 
% example. The filtered output audio signal may be played using the call sound(EchoErr,8000) after 
% making the call global EchoErr in the Command window. The Near End plus
% echoed Far End signal (the signal entering the error junction) can be
% played with the call sound(NrEndPlusFarEnd,8000) after making the call
% global NrEndPlusFarEnd.
% Test calls:
% LVxLMSAdaptFiltEcho(0.02,0.2,1,0,[],[],[]) % D-H,  no Mute
% LVxLMSAdaptFiltEcho(0.02,0.2,1,1,[],[],[]) % D-H,  Mute Imm
% LVxLMSAdaptFiltEcho(0.02,0.2,1,2,[],[],[]) % D-H,  del Mute
% LVxLMSAdaptFiltEcho(0.02,0.2,0,0,0,50,0.05) % S-H, doubletalk update, no Mute
% LVxLMSAdaptFiltEcho(0.02,0.2,0,1,1,50,0.05) % S-H, no doubletalk update, Mute Imm
%
% Author: F. W. Isen
% Copyright 2009 by Morgan & Claypool

global EchoErr
global NrEndPlusFarEnd
NrEndPlusFarEnd = [];
EchoErr = [];
LenScale = 1.0;

VOXThresh = abs(real(VOXThresh));
SampsVOX = abs(real(SampsVOX));
if SampsVOX > 1000
   SampsVOX = 1000;
end
DHorSH = abs(real(DHorSH));
if ~(DHorSH==1|DHorSH==0)
   DHorSH=1;
end
k = real(k);
Mu = abs(real(Mu));

MuteNrEnd = real(MuteNrEnd);

if ~(MuteNrEnd==0|MuteNrEnd==1|MuteNrEnd==2)
   MuteNrEnd = 1;
end

if ~(DblTkUpD==1|DblTkUpD==0)
DblTkUpD = 1;
end

NrEndAmp = 1;

[NrEndSpeech,Fs,bits] = wavread('drwatsonSR8K.wav');
NrEndSpeech = NrEndSpeech';
lenFile = length(NrEndSpeech);
NrEndSpeech = NrEndSpeech/(max(abs(NrEndSpeech)));
LenNES = length(NrEndSpeech);

if MuteNrEnd==1 % mutes immediately
NrEndSpeech(1,1:fix(0.05*LenNES)) = 0.001*randn(1,fix(0.05*LenNES));
elseif MuteNrEnd==2 % waits before muting
   lenMute = fix(0.25*LenNES) - fix(0.2*LenNES);
   NrEndSpeech(1,fix(0.32*LenNES):fix(0.37*LenNES)) = 0.001*randn(1,lenMute+1);
end
lenNearEnd = LenNES;

[FarEnd,Fs2,bits2] = wavread('whoknowsSR8K.wav');
FarEnd = FarEnd'; 
FarEnd = FarEnd(1,1:lenNearEnd);
lenFarEnd = lenNearEnd;

FarEnd = FarEnd(1,1:fix(LenScale*lenFarEnd));
lenFarEnd = length(FarEnd);

FarEnd  = FarEnd  + k*randn(1,lenFarEnd);
FarEnd = (0.99*FarEnd/(max(abs(FarEnd))));


lenNearEnd = length(NrEndSpeech);
NrEndSpeech = NrEndSpeech(1,1:fix(LenScale*lenFarEnd));
lenNearEnd = length(NrEndSpeech);
LenNES = lenNearEnd;

%==========================================================

Litn = 1:1:10;
TapNo = 6;
FiltOut = zeros(1,lenFarEnd);
EchoErr = zeros(1,lenFarEnd);
n = 1:1:10; 
BestTapWt = zeros(lenFarEnd,10);
TapToPlot = zeros(1,lenFarEnd);
NewTestTapWt = zeros(1,10);
ActualErr = zeros(1,lenFarEnd);
TestErr = zeros(1,lenFarEnd);
TestErr = ones(1,11+TapNo+Litn(length(Litn)));
NewCoeff = zeros(1,lenFarEnd);
CurBestMSE = zeros(1,lenFarEnd);
CurBestMSE(1,1:11+TapNo+Litn(length(Litn))) = ones(1,11+TapNo+Litn(length(Litn)));
TestERLE = 0.001;
NoSampsVec = 1:1:SampsVOX;

dtaPtr = TapNo:1:lenFarEnd;
NrEndPlusFarEnd = FarEnd(1,dtaPtr-TapNo+1) + NrEndSpeech(1,dtaPtr);

lenNrEndPlusFarEnd = length(NrEndPlusFarEnd);

for CurDtaPtr = 11+TapNo+Litn(length(Litn))+1:1:lenNrEndPlusFarEnd-10; 
     
if DHorSH==0  % Single-H 
bbb = BestTapWt(CurDtaPtr,1:10);
ccc = (FarEnd(1,CurDtaPtr+1-n));
aaa = sum(bbb.*ccc);
ddd = NrEndPlusFarEnd(1,CurDtaPtr) - aaa;  
EchoErr(1,CurDtaPtr) = ddd;
FiltOut(1,CurDtaPtr) = aaa;

 if DblTkUpD==1
      if CurDtaPtr > SampsVOX    
        if sqrt((1/SampsVOX)*sum(NrEndSpeech(1,CurDtaPtr+1-NoSampsVec).^2))< VOXThresh  
           BestTapWt(CurDtaPtr+1,1:10) = bbb + 2*Mu*ddd*ccc/sum(ccc.^2); 
            NewCoeff(1,CurDtaPtr) = 1;
         else
           BestTapWt(CurDtaPtr+1,1:10) = bbb;
         end
      else
     BestTapWt(CurDtaPtr+1,1:10) = bbb + 2*Mu*ddd*ccc/sum(ccc.^2); 
      NewCoeff(1,CurDtaPtr) = 1;
      end
 else % Update all the time even if doubletalk
BestTapWt(CurDtaPtr+1,1:10) = bbb + 2*Mu*ddd*(ccc/sum(ccc.^2));
NewCoeff(1,CurDtaPtr) = 1;
end

CurBestMSE(1,CurDtaPtr) = sum(FarEnd(1,CurDtaPtr-Litn+1).^2)/(sum(ddd.^2)+10^(-6));  

else % =======================Dual-H code here=============================================
if (CurDtaPtr <= 10)
     BestTapWt(CurDtaPtr,1:10) = NewTestTapWt;
     CurBestMSE(1,CurDtaPtr) = TestERLE;          
else     
if TestERLE > CurBestMSE(1,CurDtaPtr-1)
     BestTapWt(CurDtaPtr,1:10) = NewTestTapWt;
     CurBestMSE(1,CurDtaPtr) = TestERLE;
else
     CurBestMSE(1,CurDtaPtr) = CurBestMSE(1,CurDtaPtr-1);
     BestTapWt(CurDtaPtr,1:10) = BestTapWt(CurDtaPtr-1,1:10);
end
      end   
      
%TapToPlot(1,CurDtaPtr) = BestTapWt(TapNo);           
ActualFiltOut =  sum(BestTapWt(CurDtaPtr,1:10).*FarEnd(1,CurDtaPtr-n+1));
TestFiltOut =  sum(NewTestTapWt.*FarEnd(1,CurDtaPtr-n+1));
EchoErr(1,CurDtaPtr) = NrEndPlusFarEnd(1,CurDtaPtr) - ActualFiltOut;          
TestErr(1,CurDtaPtr) = NrEndPlusFarEnd(1,CurDtaPtr) - TestFiltOut;  
TestERLE = sum(FarEnd(1,CurDtaPtr-Litn+1).^2)/(sum(TestErr(1,CurDtaPtr-Litn+1).^2)+10^-6);  
   
NewTestTapWt = NewTestTapWt + 2*Mu*TestErr(1,CurDtaPtr)*(FarEnd(1,CurDtaPtr+1-n))/sum((FarEnd(1,CurDtaPtr+1-n)).^2);
NewCoeff(1,CurDtaPtr) = 1;

end
end

figure(37)
clf
plotlim = 1.2*max(max(BestTapWt));
plotlim = max([plotlim,1.1]);

subplot(411)
line([0 lenFarEnd],[1, 1]);
hold on
line([0 lenFarEnd],[0, 0]);

for ctr = 1:1:10
plot(BestTapWt(:,ctr))   
end 
hold off
xlabel(['(a) Iteration'])
ylabel(['Amplitude'])
axis([0, length(BestTapWt), -1.2,  plotlim])

subplot(412)
plot(EchoErr(1,1:lenFarEnd))
plotlim1 = max(abs(EchoErr));
ylabel(['Amplitude'])
xlabel(['(b) Sample, Error/Output'])
axis([0, lenFarEnd, -1.2*plotlim1, 1.2*plotlim1])

EchoErr = (0.99/max(abs(EchoErr)))*EchoErr;
FinalSampleRate = Fs2; %/DecRate;

subplot(413)
plot(20*log10(CurBestMSE(1,1:length(CurBestMSE)) + eps  ))
plotmin = min([1.2*min(20*log10(CurBestMSE(1,1:length(CurBestMSE)) + eps))  1]);
plotmax = max([1.2*max(20*log10(CurBestMSE(1,1:length(CurBestMSE)) + eps))  1]);
ylabel(['Mag, dB'])

if DHorSH==1
xlabel(['(c) Iteration, CurBestERLE'])
else
xlabel(['(c) Iteration, ERLE'])   
end
axis([0 length(CurBestMSE) -20 140])

subplot(414)
plot(NewCoeff(1,:)); 
ylabel(['Binary'])
xlabel(['(d) Iteration, Fcn Coefficient Update Permitted?'])
axis([0 length(NewCoeff) -0.2  1.2])   

sound(NrEndPlusFarEnd,Fs)

pause(5)

sound(EchoErr,Fs)
Comment = ['global sound variable names are EchoErr and NrEndPlusFarEnd, and sample rate is ',num2str(Fs)]




  





