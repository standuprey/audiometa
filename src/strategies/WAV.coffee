"use strict"
angular.module("audioMeta").factory "WAV", ["HexReader", "$q", (HexReader, $q) ->
	parse: (file, firstBytes) ->
		deferred = $q.defer()
		if HexReader.checksequenceAsString firstBytes, 0, "RIFF"
			deferred.resolve
				type: "WAV"
		else deferred.resolve()
		deferred.promise
]