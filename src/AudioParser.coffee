"use strict"
angular.module("audioMeta").factory "AudioParser", ["$window", "$q", "HexReader", "Strategies", "$injector"
($window, $q, HexReader, Strategies, $injector) ->

	getInfo: (file) ->
		return unless $window.FileReader
		deferred = $q.defer()
		fileInfo = {}

		readError = -> console.error "There was an error while reading the information for this file: #{file}"
		readFileStart = (hexString) ->
			# I use promises here, so that if I need
			# to read more bytes during the parsing
			# it is easy to defer the response.
			promises = []
			for strategy in Strategies
				res = $injector.get(strategy).parse file, hexString
				promises.push res
				res.then (strategyFileInfo) ->
					if strategyFileInfo and typeof strategyFileInfo is "object"
						fileInfo[key] = strategyFileInfo[key] for key of strategyFileInfo
			$q.all(promises).then ->
				deferred.resolve fileInfo


		# We actually need only for bytes for this part but we read more
		# so we don't have to read them again and can pass this as argument
		# to the specific parser
		HexReader.getFileBytes(file, 0, 132).then readFileStart, readError

		return deferred.promise
]