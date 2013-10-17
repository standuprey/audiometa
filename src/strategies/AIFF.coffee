"use strict"
angular.module("audioMeta").factory "AIFF", ["HexReader", "$q", (HexReader, $q) ->
	parse: (file, firstBytes) ->
		deferred = $q.defer()
		if HexReader.checksequenceAsString firstBytes, 0, "FORM"
			deferred.resolve
				type: "AIFF"
		else deferred.resolve()
		deferred.promise
]