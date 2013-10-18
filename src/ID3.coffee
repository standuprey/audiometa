"use strict"
angular.module("audiometa").factory "ID3", ["HexReader", (HexReader) ->
	trimSubStr = (string, offset, length) -> string.substr(offset, length).replace(/\x00/g, '')
	getSize = (hexString, byteOffset, length = 4) -> HexReader.getBits hexString, byteOffset * 8, length * 8, 7

	getId3v2Frames = (hexString, offset, id3v2Size, tagLength, frameHeaderLength) ->
		getFramesRec = ->
			if offset < id3v2Size
				size = getSize hexString, offset + tagLength, tagLength
				frameName = hexString.substr(offset, tagLength)
				if parseInt(frameName.charCodeAt(0)) isnt 0 # skip padding
					frames[frameName] = trimSubStr(hexString, offset + frameHeaderLength, size)
					offset += frameHeaderLength + size
					getFramesRec()
		frames = {}
		getFramesRec()
		frames

	addID3v2 = (hexString, fileInfo, id3v2Size, decodeMP3Header) ->
		id3minorVersion = hexString.charCodeAt 3
		if id3minorVersion is 2
			addID3v2_2 hexString, fileInfo, id3v2Size, decodeMP3Header
		else if id3minorVersion is 3
			addID3v2_3 hexString, fileInfo, id3v2Size, decodeMP3Header

	# http://id3lib.sourceforge.net/id3/id3v2-00.txt
	addID3v2_2 = (hexString, fileInfo, id3v2Size, decodeMP3Header) ->
		firstFrameOffset = 10
		id3v2Frames = getId3v2Frames hexString, firstFrameOffset, id3v2Size, 3, 6
		artist = id3v2Frames.TP1 || id3v2Frames.TP2  || id3v2Frames.TCM || id3v2Frames.TP3 || id3v2Frames.TP4
		fileInfo.artist = artist if artist
		title = id3v2Frames.TT2 || id3v2Frames.TT1  || id3v2Frames.TT3
		fileInfo.title = title if title
		album = id3v2Frames.TAL
		fileInfo.album = album if album
		addMP3Header(hexString.substr(id3v2Size), fileInfo) if decodeMP3Header
		null

	# http://id3lib.sourceforge.net/id3/id3v2.3.0.html#sec3.2
	addID3v2_3 = (hexString, fileInfo, id3v2Size, decodeMP3Header) ->
		extHeaderPresent = (HexReader.getBits hexString, 41, 1) is 1
		firstFrameOffset = 10
		if extHeaderPresent
			extHeaderSize = getSize hexString, 10
			firstFrameOffset += extHeaderSize
		id3v2Frames = getId3v2Frames hexString, firstFrameOffset, id3v2Size, 4, 10
		artist = id3v2Frames.TPE1 || id3v2Frames.TPE2  || id3v2Frames.TCOM || id3v2Frames.TPE3 || id3v2Frames.TPE4
		fileInfo.artist = artist if artist
		title = id3v2Frames.TIT2 || id3v2Frames.TIT1  || id3v2Frames.TIT3
		fileInfo.title = title if title
		album = id3v2Frames.TALB
		fileInfo.album = album if album
		addMP3Header(hexString.substr(id3v2Size), fileInfo) if decodeMP3Header
		null

	getAndAddID3v2 = (hexString, fileInfo, file, deferred, decodeMP3Header) ->
		mp3HeaderLength = if decodeMP3Header then 4 else 0
		getInfoAndResolve = ->
			addID3v2 hexString, fileInfo, totalSize, decodeMP3Header
			deferred.resolve(fileInfo) if deferred
		footerPresent = (HexReader.getBits hexString, 43, 1) is 1
		totalSize = (getSize hexString, 6)  + (if footerPresent then 20 else 10)
		if hexString.length < totalSize + mp3HeaderLength
			HexReader.getFileBytes(file, 0, totalSize).then (_hexString) ->
				hexString = _hexString
				getInfoAndResolve()
		else
			getInfoAndResolve()
		null
	isID3v1 = (hexString) -> HexReader.checksequenceAsString hexString, 0, "TAG"

	isID3v2 = (hexString) -> HexReader.checksequenceAsString hexString, 0, "ID3"

	addID3v1 = (hexString, fileInfo) ->
		title = trimSubStr hexString, 3, 30
		fileInfo.title = title if title
		artist = trimSubStr hexString, 33, 30
		fileInfo.artist = artist if artist
		album = trimSubStr hexString, 63, 30
		fileInfo.album = album if album

	addID3v1: addID3v1
	addID3v2: addID3v2
	getAndAddID3v2: getAndAddID3v2
	isID3v1: isID3v1
	isID3v2: isID3v2
]