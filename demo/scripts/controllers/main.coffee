"use strict"
angular.module("audiometaDemo").controller "MainCtrl", ["AudioParser", "$scope", (AudioParser, $scope) ->

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
				worker = new Worker "/scripts/worker.js"
				worker.addEventListener "message", (e) ->
					$scope.$apply ->
						fileObj.info = e.data
				worker.postMessage
					file: files[i]			
					strategies: ["MP3", "WAV", "AIFF"]
			i++
]