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
]