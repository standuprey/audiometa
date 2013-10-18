"use strict"
angular.module("audiometa").factory "MP3", ["$window", "$q", "HexReader", "ID3",
($window, $q, HexReader, ID3) ->

	# according to the table here: http://www.mp3-tech.org/programmer/frame_header.html
	bitRates = [{}, {
		v1l1: 32
		v1l2: 32
		v1l3: 32
		v2l1: 32
		v2l2: 8
		v2l3: 8
	}, {
		v1l1: 64
		v1l2: 48
		v1l3: 40
		v2l1: 48
		v2l2: 16
		v2l3: 16
	}, {
		v1l1: 96
		v1l2: 56
		v1l3: 48
		v2l1: 56
		v2l2: 24
		v2l3: 24
	}, {
		v1l1: 128
		v1l2: 64
		v1l3: 56
		v2l1: 64
		v2l2: 32
		v2l3: 32
	}, {
		v1l1: 160
		v1l2: 80
		v1l3: 64
		v2l1: 80
		v2l2: 40
		v2l3: 40
	}, {
		v1l1: 192
		v1l2: 96
		v1l3: 80
		v2l1: 96
		v2l2: 48
		v2l3: 48
	}, {
		v1l1: 224
		v1l2: 112
		v1l3: 96
		v2l1: 112
		v2l2: 56
		v2l3: 56
	}, {
		v1l1: 256
		v1l2: 128
		v1l3: 112
		v2l1: 128
		v2l2: 64
		v2l3: 64
	}, {
		v1l1: 288
		v1l2: 160
		v1l3: 128
		v2l1: 144
		v2l2: 80
		v2l3: 80
	}, {
		v1l1: 320
		v1l2: 192
		v1l3: 160
		v2l1: 160
		v2l2: 96
		v2l3: 96
	}, {
		v1l1: 352
		v1l2: 224
		v1l3: 192
		v2l1: 176
		v2l2: 112
		v2l3: 112
	}, {
		v1l1: 384
		v1l2: 256
		v1l3: 224
		v2l1: 192
		v2l2: 128
		v2l3: 128
	}, {
		v1l1: 416
		v1l2: 320
		v1l3: 256
		v2l1: 224
		v2l2: 144
		v2l3: 144
	}, {
		v1l1: 448
		v1l2: 384
		v1l3: 320
		v2l1: 256
		v2l2: 160
		v2l3: 160
	}]
	mpegVersion = [0, 0, 2, 1]
	mpegLayer = [0, 3, 2, 1]

	isMP3 = (hexString) -> HexReader.checksequenceAsHexString hexString, 0, "FFFF", 11

	addMP3Header = (hexString, fileInfo) ->
		bitRate = getBitRate(hexString)
		fileInfo["bitRate"] = bitRate if bitRate

	getBitRate = (hexString) ->
		specVersion = mpegVersion[HexReader.getBits hexString, 11, 2]
		specLayer = mpegLayer[HexReader.getBits hexString, 13, 2]
		specBitRate = HexReader.getBits hexString, 16, 4
		bitRates[specBitRate]?["v#{specVersion}l#{specLayer}"]

	_forUnitTests:
		isMP3: isMP3
		addMP3Header: addMP3Header
		getBitRate: getBitRate
	parse: (file, firstBytes) ->
		deferred = $q.defer()
		fileInfo = { type: "MP3" }

		readError = -> console.error "There was an error while reading the information for this file: #{file}"
		readFileEnd = (hexString) ->
			if ID3.isID3v1 hexString
				ID3.addID3v1 hexString, fileInfo
			deferred.resolve fileInfo

		if ID3.isID3v2 firstBytes
			ID3.getAndAddID3v2 firstBytes, fileInfo, file, deferred, addMP3Header
		else if ID3.isID3v1 firstBytes
			ID3.addID3v1 firstBytes, fileInfo
			addMP3Header firstBytes.substr(128), fileInfo
			deferred.resolve fileInfo
		else if isMP3 firstBytes
			addMP3Header firstBytes, fileInfo
			# read the end of the MP3 and read ID3v1 if it's there
			HexReader.getFileBytes(file, file.size - 128, file.size).then readFileEnd, readError
		else
			deferred.resolve()

		return deferred.promise
]