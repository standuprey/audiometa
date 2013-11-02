"use strict"
angular.module("audiometaDemo").controller "MainCtrl", ["AudioParser", "AudioParserWorker", "$scope", (AudioParser, AudioParserWorker, $scope) ->

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
		while i < files.length
			fileObj = {file: files[i]}
			$scope.wwfiles.push fileObj
			do (fileObj) ->
				AudioParserWorker.getInfo(files[i]).then (fileInfo) ->
					fileObj.info = fileInfo
					console.log "Metadata Found: ", fileObj
			i++
]