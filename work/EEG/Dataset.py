import numpy
from collections.abc 	import Iterable
from collections.abc 	import Iterator
from .State				import State
from .Band				import SignalNames
from .Signal 			import Signal
    
class Dataset:
    
    _sampleFreq: 	float
    _dataDir: 		str
    _stateNames: 	tuple[str, ...]
    _channelNames: 	tuple[str, ...]
    _stateCache: 	dict[str, State]
    
    def __init__(self, sampleFreq: float, dataDir: str, stateNames: Iterable[str], channelNames: Iterable[str]):
        self._sampleFreq 	= sampleFreq
        self._dataDir 		= dataDir
        self._stateNames 	= tuple(stateNames)
        self._channelNames 	= tuple(channelNames)
        self._stateCache 	= {}
        if not self._stateNames:
            raise ValueError("stateNames must not be empty")
        if not self._channelNames:
            raise ValueError("channelNames must not be empty")
        
    def __iter__(self) -> Iterator[State]:
        for stateName in self._stateNames:
            yield self[stateName]

    def __getitem__(self, stateName: str) -> State:
        if stateName not in self._stateNames:
            raise ValueError(f"Invalid state: {stateName}")
        if stateName in self._stateCache:
            return self._stateCache[stateName]
        self._stateCache[stateName] = State(
            stateName,
            self._sampleFreq,
            self._dataDir,
            self._channelNames
        )
        return self._stateCache[stateName]

    @property
    def sampleFreq(self) -> float:
        return self._sampleFreq

    def CollectSignals(self, *,
        stateNames:   tuple[str, ...] | None = None,
        channelNames: tuple[str, ...] | None = None,
        signalNames:  tuple[str, ...] | None = None,
    ) -> list[Signal]:
    
        if signalNames is None:
            signalNames = tuple(SignalNames)
        if stateNames is None:
            stateNames = self._stateNames
    
        signals: list[Signal] = []
        for stateName in stateNames:
            signals.extend(self[stateName].CollectSignals(channelNames=channelNames, signalNames=signalNames))
            
        return signals
    
    def NotchNoise(self, freqCentre: float, freqWidth: float) -> None:
        for state in self:
            state.NotchNoise(freqCentre, freqWidth)
    
    def TrimToShortestState(self) -> None:
        nSamples = []
        for state in self:
            channel = state[self._channelNames[0]]
            nSamples.append(len(channel.data))
        nSamplesMinimum = min(nSamples)
        for state in self:
            for channel in state:
                channel.data = channel.data[:nSamplesMinimum]