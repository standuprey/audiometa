"use strict"
angular.module("audioMeta").factory "MP3", ["$window", "$q", "HexReader",
($window, $q, HexReader) ->

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

	isID3v1 = (hexString) -> HexReader.checksequenceAsString hexString, 0, "TAG"
	isID3v2 = (hexString) -> HexReader.checksequenceAsString hexString, 0, "ID3"
	isMP3 = (hexString) -> HexReader.checksequenceAsHexString hexString, 0, "FFFF", 11

	trimSubStr = (string, offset, length) -> string.substr(offset, length).replace(/\x00/g, '')

	addID3v1 = (hexString, fileInfo) ->
		title = trimSubStr hexString, 3, 30
		fileInfo.title = title if title
		artist = trimSubStr hexString, 33, 30
		fileInfo.artist = artist if artist
		album = trimSubStr hexString, 63, 30
		fileInfo.album = album if album

	getAndAddID3v2 = (hexString, fileInfo, file, deferred) ->
		getInfoAndResolve = ->
			addID3v2 hexString, fileInfo, totalSize
			deferred.resolve fileInfo
		footerPresent = (HexReader.getBits hexString, 43, 1) is 1
		totalSize = (getSize hexString, 6) + (if footerPresent then 20 else 10)
		if hexString.length < totalSize + 4 # +4 for mp3 header
			HexReader.getFileBytes(file, 0, totalSize).then (_hexString) ->
				hexString = _hexString
				getInfoAndResolve()
		else
			getInfoAndResolve()
		null

	addID3v2 = (hexString, fileInfo, id3v2Size) ->
		extHeaderPresent = (HexReader.getBits hexString, 41, 1) is 1
		firstFrameOffset = 10
		if extHeaderPresent
			extHeaderSize = getSize hexString, 10
			firstFrameOffset += extHeaderSize
		id3v2Frames = getId3v2Frames hexString, firstFrameOffset, id3v2Size
		artist = id3v2Frames.TPE1 || id3v2Frames.TPE2  || id3v2Frames.TCOM || id3v2Frames.TPE3 || id3v2Frames.TPE4
		fileInfo.artist = artist if artist
		title = id3v2Frames.TIT2 || id3v2Frames.TIT1  || id3v2Frames.TIT3
		fileInfo.title = title if title
		album = id3v2Frames.TALB
		fileInfo.album = album if album
		addMP3Header hexString.substr(id3v2Size), fileInfo
	
	getId3v2Frames = (hexString, offset, id3v2Size) ->
		frames = {}
		getId3v2FramesRec hexString, offset, id3v2Size, frames
		frames

	getId3v2FramesRec = (hexString, offset, id3v2Size, frames) ->
		if offset < id3v2Size
			size = getSize hexString, offset + 4
			frameName = hexString.substr(offset, 4)
			if parseInt(frameName.charCodeAt(0)) isnt 0 # skip padding
				frames[frameName] = trimSubStr(hexString, offset + 10, size)
				getId3v2FramesRec(hexString, offset + 10 + size, id3v2Size, frames)

	getSize = (hexString, byteOffset) -> HexReader.getBits hexString, byteOffset * 8, 32, 7

	addMP3Header = (hexString, fileInfo) ->
		bitRate = getBitRate(hexString)
		fileInfo["bitRate"] = bitRate if bitRate

	getBitRate = (hexString) ->
		specVersion = mpegVersion[HexReader.getBits hexString, 11, 2]
		specLayer = mpegLayer[HexReader.getBits hexString, 13, 2]
		specBitRate = HexReader.getBits hexString, 16, 4
		bitRates[specBitRate]?["v#{specVersion}l#{specLayer}"]

	_forUnitTests:
		isID3v1: isID3v1
		isID3v2: isID3v2
		isMP3: isMP3
		addID3v1: addID3v1
		getAndAddID3v2: getAndAddID3v2
		addMP3Header: addMP3Header
		getBitRate: getBitRate
	parse: (file, firstBytes) ->
		deferred = $q.defer()
		fileInfo = { type: "MP3" }

		if isID3v2 firstBytes
			getAndAddID3v2 firstBytes, fileInfo, file, deferred
		else if isID3v1 firstBytes
			addID3v1 firstBytes, fileInfo
			addMP3Header firstBytes.substr(128), fileInfo
			deferred.resolve fileInfo
		else if isMP3 firstBytes
			addMP3Header firstBytes, 0, fileInfo
			# read the end of the MP3 and read ID3v1 if it's there
			HexReader.getFileBytes(file, file.size - 128, file.size).then readFileEnd, readError
		else
			deferred.resolve()

		readError = -> console.error "There was an error while reading the information for this file: #{file}"
		readFileEnd = (hexString) ->
			if isID3v1 hexString
				addID3v1 hexString, 0, fileInfo
			deferred.resolve fileInfo

		return deferred.promise
]