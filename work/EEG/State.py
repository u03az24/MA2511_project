import numpy
from collections.abc 	import Iterable
from collections.abc 	import Iterator
from .Channel 			import Channel
from .Band				import SignalNames
from .Signal 			import Signal

class State:
    
    _stateName: 	str
    _sampleFreq:	float
    _dataDir: 		str
    _channelNames: 	tuple[str, ...]
    _channelCache: 	dict[str, Channel]
    
    def __init__(self, stateName: str, sampleFreq: float, dataDir: str, channelNames: Iterable[str]):          
        self._stateName 	= stateName
        self._sampleFreq 	= sampleFreq
        self._dataDir 		= dataDir
        self._channelNames 	= tuple(channelNames)
        self._channelCache 	= {}
        if not self._channelNames:
            raise ValueError("channelNames must not be empty")
        
    def __iter__(self) -> Iterator[Channel]:
        for channelName in self._channelNames:
            yield self[channelName]

    def __getitem__(self, channelName: str) -> Channel:
        if channelName not in self._channelNames:
            raise ValueError(f"Invalid channel: {channelName}")
        if channelName in self._channelCache:
            return self._channelCache[channelName]
        self._channelCache[channelName] = Channel(
            self._stateName,
            channelName,
            self._sampleFreq,
            self._dataDir
        )
        return self._channelCache[channelName]

    def CollectSignals(self, *,
            channelNames: tuple[str, ...] | None = None,
            signalNames:  tuple[str, ...] | None = None,
        ) -> list[Signal]:
            
            if signalNames is None:
                signalNames = tuple(SignalNames)
            if channelNames is None:
                channelNames = self._channelNames
        
            signals: list[Signal] = []
            for channelName in channelNames:
                signals.extend(self[channelName].CollectSignals(signalNames=signalNames))
                
            return signals

    @property
    def sampleFreq(self) -> float:
        return self._sampleFreq
    @property
    def stateName(self) -> str:
        return self._stateName
    
    def NotchNoise(self, freqCentre: float, freqWidth: float) -> None:
        for channel in self:
            channel.NotchNoise(freqCentre, freqWidth)