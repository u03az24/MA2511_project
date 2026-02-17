import numpy
import scipy.signal
import scipy.stats
from abc import ABC

class Signal(ABC):

    _stateName:     str
    _channelName:   str
    _signalName:	str
    _sampleFreq: 	float
    _data:       	numpy.ndarray

    @property
    def stateName(self) -> str:
        return self._stateName
    @property
    def channelName(self) -> str:
        return self._channelName
    @property
    def signalName(self) -> str:
        return self._signalName
    @property
    def sampleFreq(self) -> float:
        return self._sampleFreq
    @property
    def data(self) -> numpy.ndarray:
        return self._data
    @data.setter
    def data(self, x) -> None:
        arr = numpy.asarray(x, dtype=numpy.float64)
        if arr.ndim != 1:
            raise ValueError("Signal data must be 1D")
        self._data = arr
        self._OnDataChange()

    def _OnDataChange(self) -> None:
        pass

    def NotchNoise(self, freqCentre: float, freqWidth: float) -> None:
        Q 			= freqCentre / freqWidth
        b, a 		= scipy.signal.iirnotch(freqCentre, Q, self.sampleFreq)
        self.data 	= scipy.signal.filtfilt(b, a, self.data)
        
    def CalculateWelchPSD(self, segmentLength: float, overlap: float=0.0) -> tuple[numpy.ndarray, numpy.ndarray]:
        
        nSamplesPerSeg  = min(len(self.data), int(segmentLength * self.sampleFreq))
        nOverlapSamples = int(nSamplesPerSeg * overlap)
        
        freqs, psd = scipy.signal.welch(
            self.data,
            self.sampleFreq,
            window="hann",
            nperseg=nSamplesPerSeg,
            noverlap=nOverlapSamples,
            detrend=False,
            scaling="density",
            average="median"
        )
        return freqs, psd
    
    def CalculateEntropy(self, binEdges: numpy.ndarray, windowLength: float) -> tuple[numpy.ndarray, numpy.ndarray]:
    
        segmentLength = int(round(windowLength * self.sampleFreq))
        
        H = []
        t = []
        segmentIndex = 0
        while segmentIndex + segmentLength <= len(self.data):
            counts, _ 	= numpy.histogram(self.data[segmentIndex:segmentIndex + segmentLength], bins=binEdges)
            p 			= counts / counts.sum()
            
            H.append(scipy.stats.entropy(p, base=2))
            t.append((segmentIndex + segmentLength / 2) / self.sampleFreq)
            
            segmentIndex += segmentLength
            
        return numpy.array(t), numpy.array(H)