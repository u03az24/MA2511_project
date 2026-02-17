import scipy.signal
from .Signal import Signal

Bands = {
    "delta": (0.5, 4.0),
    "theta": (4.0, 8.0),
    "alpha": (8.0, 12.0),
    "beta":  (12.0, 30.0),
    "gamma": (30.0, 100.0),
}
SignalNames = ["raw", *Bands.keys()]

class Band(Signal):
    
    def __init__(self, signal: Signal, bandName: str):
        if bandName not in Bands:
            raise ValueError(f"Invalid band: {bandName}")
        self._stateName 	= signal.stateName
        self._channelName 	= signal.channelName
        self._signalName 	= bandName
        self._sampleFreq 	= signal.sampleFreq
        self.data 			= signal.data.copy()
        self._ApplyBandpassFilter(order=8)

    @property
    def bandName(self) -> str:
        return self._signalName

    def _ApplyBandpassFilter(self, order: int) -> None:
        lowHz, highHz 	= Bands[self.bandName]
        nyqFreq       	= self._sampleFreq / 2
        sos = scipy.signal.butter(order, [lowHz/nyqFreq, highHz/nyqFreq], btype="bandpass", output="sos")
        self.data = scipy.signal.sosfiltfilt(sos, self.data)