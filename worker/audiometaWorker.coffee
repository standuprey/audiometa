"use strict"
angular.module("audiometaWorker", []).factory "AudioParser", ["$timeout", ($timeout) ->

	(file, strategies = ["MP3", "WAV", "AIFF"]) ->
		deferred = $q.defer()

		# it should not take more than 5 second to find the info
		timer = $timeout.setTimeout ->
			deferred.reject()
		, 5000

		worker = new Worker "/scripts/worker.js"
		worker.addEventListener "message", (e) ->
			deferred.resolve e.data
			$timeout.cancel timer

		worker.postMessage
			file: file
			strategies: strategies

		deferred.promise
]