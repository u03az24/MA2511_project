import os
import numpy
import scipy.io
from .Signal 	import Signal
from .Band 		import Band, Bands

class Channel(Signal):
    
    _bandCache: dict[str, Band]
    
    def __init__(self, stateName: str, channelName: str, sampleFreq: float, dataDir: str):
        self._stateName		= stateName
        self._channelName	= channelName
        self._signalName 	= "raw"
        self._sampleFreq 	= sampleFreq
        self._bandCache 	= {}
        self._LoadData(dataDir)

    def __getitem__(self, signalName: str) -> Signal:
        if signalName == "raw":
            return self
        else:
            if signalName not in Bands:
                raise ValueError(f"Invalid band: {signalName}")
            if signalName in self._bandCache:
                return self._bandCache[signalName]
            self._bandCache[signalName] = Band(self, signalName)
            return self._bandCache[signalName]

    def _OnDataChange(self) -> None:
        self._bandCache.clear()

    def CollectSignals(self, *,
        signalNames: tuple[str, ...],
    ) -> list[Signal]:
        return [self[signalName] for signalName in signalNames]

    def _LoadData(self, dataDir: str) -> None:
        filePath = os.path.join(dataDir, self._stateName, f"{self._channelName}_{self._stateName}.mat")
        if not os.path.exists(filePath):
            raise FileNotFoundError(f"File not found: {filePath}")
        matData = scipy.io.loadmat(filePath)
        if self._stateName not in matData:
            raise ValueError(f"State not found: '{self._stateName}' in {filePath}.")
        self.data = numpy.squeeze(matData[self._stateName])