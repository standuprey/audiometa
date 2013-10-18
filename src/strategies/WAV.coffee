"use strict"
angular.module("audioMeta").factory "WAV", ["HexReader", "$q", (HexReader, $q) ->
	parse: (file, firstBytes) ->
		deferred = $q.defer()
		fileInfo = { type: "WAV" }
		if HexReader.checksequenceAsString firstBytes, 0, "RIFF"
			sampleRate = HexReader.toLittleEndian firstBytes, 24, 4
			fileInfo.sampleRate = HexReader.getBits sampleRate
			bitsPerSample = HexReader.toLittleEndian firstBytes, 34, 2
			fileInfo.bits = HexReader.getBits bitsPerSample
			channelCount = HexReader.toLittleEndian firstBytes, 22, 2
			fileInfo.channels = HexReader.getBits channelCount
			deferred.resolve fileInfo
		else deferred.resolve()
		deferred.promise
]