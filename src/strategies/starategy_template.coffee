###
"use strict"
angular.module("audioMeta").factory "XXX", ["HexReader", "$q", (HexReader, $q) ->
	parse: (file, firstBytes) ->
		deferred = $q.defer()
		if HexReader.checksequenceAsString firstBytes, 0, "XXX"
			deferred.resolve
				type: "XXX"
		else deferred.resolve()
		deferred.promise
]
###