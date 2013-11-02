"use strict"
angular.module("audiometaDemo").controller "MainCtrl", ["AudioParser", "AudioParserWorker", "$scope", "$q", (AudioParser, AudioParserWorker, $scope, $q) ->

	$scope.setFiles = (element) ->
		files = element.files
		$scope.fileInputState = ""
		$scope.files = []
		i = 0
		console.log "got #{files.length} files"
		while i < files.length
			fileObj = {file: files[i]}
			$scope.files.push fileObj
			do (fileObj) ->
				AudioParser.getInfo(files[i]).then (fileInfo) ->
					fileObj.info = fileInfo
					console.log "Metadata Found: ", fileObj
			i++

	$scope.setWwFiles = (element) ->
		files = element.files
		$scope.fileInputState = ""
		$scope.wwfiles = []
		i = 0
		console.log "got #{files.length} files"
		getfileInfoByBatch(0, files)

	getfileInfoByBatch = (i, files) ->
		limit = Math.min files.length, i + 10
		deferred = $q.defer()
		while i < limit
			fileObj = {file: files[i]}
			do (fileObj, i) ->
				AudioParserWorker.getInfo(files[i]).then (fileInfo) ->
					fileObj.info = fileInfo
					$scope.wwfiles.push fileObj
					console.log "Metadata Found: ", fileObj
					deferred.resolve() if i + 1 is limit
			i++
		deferred.promise.then ->
			getfileInfoByBatch(limit, files) if limit < files.length
]