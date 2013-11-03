"use strict"

angular.module("audiometaWorker", []).factory "AudioParserWorker", ["$timeout", "$q", ($timeout, $q) ->
	worker = ->
		# WAV

		self.WAV = do ->
			parse: (file, firstBytes, callback) ->
				fileInfo = { type: "WAV" }
				if HexReader.checksequenceAsString firstBytes, 0, "RIFF"
					sampleRate = HexReader.toLittleEndian firstBytes, 24, 4
					fileInfo.sampleRate = HexReader.getBits sampleRate
					bitsPerSample = HexReader.toLittleEndian firstBytes, 34, 2
					fileInfo.bits = HexReader.getBits bitsPerSample
					channelCount = HexReader.toLittleEndian firstBytes, 22, 2
					fileInfo.channels = HexReader.getBits channelCount
					callback fileInfo
				else callback()

		# MP3

		self.MP3 = do ->
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
			parse: (file, firstBytes, callback) ->
				fileInfo = { type: "MP3" }

				readError = -> console.error "There was an error while reading the information for this file: #{file}"
				readFileEnd = (hexString) ->
					if ID3.isID3v1 hexString
						ID3.addID3v1 hexString, fileInfo
					callback fileInfo

				if ID3.isID3v2 firstBytes
					ID3.getAndAddID3v2 firstBytes, fileInfo, file, callback, addMP3Header
				else if ID3.isID3v1 firstBytes
					ID3.addID3v1 firstBytes, fileInfo
					addMP3Header firstBytes.substr(128), fileInfo
					callback fileInfo
				else if isMP3 firstBytes
					addMP3Header firstBytes, fileInfo
					# read the end of the MP3 and read ID3v1 if it's there
					HexReader.getFileBytes file, file.size - 128, file.size, readFileEnd, readError
				else
					callback()

		# AIFF

		self.AIFF = do ->
			findTag = (hexString, tag, offset) ->
				offset = offset || 0
				length = HexReader.getBits hexString, 32, 32
				if hexString.substr(0, tag.length) is tag
					return {content: hexString, length: length, offset: offset}
				else
					# 16 = 8 bytes from current header chunk + 8 bytes for next header chunk
					if length + 16 < hexString.length
						findTag hexString.substr(length + 8), tag, offset + length + 8
					else
						null
			parse: (file, firstBytes, callback) ->
				fileInfo = { type: "AIFF" }
				if HexReader.checksequenceAsString(firstBytes, 0, "FORM")\
				&& HexReader.checksequenceAsString(firstBytes, 8, "AIFF")
					commTag = findTag firstBytes.substr(12), "COMM"
					if commTag
						hexString = commTag.content
						fileInfo.channels = HexReader.getBits hexString, 64, 16
						fileInfo.bits = HexReader.getBits hexString, 14 * 8, 16
						fileInfo.sampleRate = HexReader.getBits hexString, 18 * 8, 16
					id3Tag = findTag firstBytes.substr(12), "ID3 "
					if id3Tag
						ID3.getAndAddID3v2(id3Tag.content, fileInfo, file, callback)
					else 
						ssndTag = findTag firstBytes.substr(12), "SSND"
						if ssndTag
							offset = ssndTag.offset + 8 + ssndTag.length
							HexReader.getFileBytes file, offset, file.size, (hexString) ->
								while (index = hexString.indexOf("ID3 ")) > 0
									hexString = hexString.substr index + 4 # skip "ID3 "
									length = HexReader.getBits hexString, 0, 32
									if hexString.length is length + 4
										hexString = hexString.substr 4 # skip length of the AIFF ID3 Header
										ID3.getAndAddID3v2 hexString, fileInfo
										break
								callback fileInfo
							, -> callback()
						else
							callback fileInfo
				else callback()


		# ID3

		ID3 = do ->
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
				decodeMP3Header(hexString.substr(id3v2Size), fileInfo) if decodeMP3Header

			# http://id3lib.sourceforge.net/id3/id3v2-00.txt
			addID3v2_2 = (hexString, fileInfo, id3v2Size) ->
				firstFrameOffset = 10
				id3v2Frames = getId3v2Frames hexString, firstFrameOffset, id3v2Size, 3, 6
				artist = id3v2Frames.TP1 || id3v2Frames.TP2  || id3v2Frames.TCM || id3v2Frames.TP3 || id3v2Frames.TP4
				fileInfo.artist = artist if artist
				title = id3v2Frames.TT2 || id3v2Frames.TT1  || id3v2Frames.TT3
				fileInfo.title = title if title
				album = id3v2Frames.TAL
				fileInfo.album = album if album
				null

			# http://id3lib.sourceforge.net/id3/id3v2.3.0.html#sec3.2
			addID3v2_3 = (hexString, fileInfo, id3v2Size) ->
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
				null

			getAndAddID3v2 = (hexString, fileInfo, file, callback, decodeMP3Header) ->
				mp3HeaderLength = if decodeMP3Header then 4 else 0
				getInfoAndResolve = ->
					addID3v2 hexString, fileInfo, totalSize, decodeMP3Header
					callback?(fileInfo)
				footerPresent = (HexReader.getBits hexString, 43, 1) is 1
				totalSize = (getSize hexString, 6)  + (if footerPresent then 20 else 10)
				if hexString.length < totalSize + mp3HeaderLength
					HexReader.getFileBytes file, 0, totalSize + mp3HeaderLength, (_hexString) ->
						hexString = _hexString
						getInfoAndResolve()
					, -> callback?(fileInfo)
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


		# HexReader

		HexReader = do ->
			getBitsRec = (hexString, offset, length) ->
				endOffset = offset + length
				byteOffset = Math.floor endOffset / 8
				bitOffset = endOffset % 8
				res = hexString.charCodeAt(byteOffset) >> (8 - bitOffset)
				if length > bitOffset
					res |= 255 & hexString.charCodeAt(byteOffset - 1) << bitOffset
				else
					res &= 255 >> (8 - length)
				res = [res]
				res = res.concat(getBitsRec(hexString, offset, length - 8)) if length > 8
				res

			getBits: (hexString, offset, length, significantBits = 8) ->
				offset = offset || 0
				length = length || (hexString.length - offset) * 8
				rad = Math.pow 2, significantBits
				ba = getBitsRec hexString, offset, length
				res = 0
				ba.forEach (byte, index) -> res += byte * Math.pow(rad, index)
				res

			checksequenceAsString: (hexString, byteOffset, sequence) -> hexString.substr(byteOffset, sequence.length) is sequence
			checksequenceAsHexString: (hexString, byteOffset, hexSequence, bitCount) ->
				len = hexSequence.length / 2
				bitIgnore = if bitCount? then len * 8 - bitCount
				hexStringCopy = hexString.substr byteOffset, len
				if bitIgnore
					cache = 0
					while bitIgnore
						bitIgnore--
						cache += Math.pow 2, bitIgnore
					ffPaddedChar = String.fromCharCode(hexStringCopy.charCodeAt(len - 1) | cache)
					hexStringCopy = hexStringCopy.substr(0, len - 1) + ffPaddedChar
				i = len
				while i--
					return false unless parseInt(hexSequence[i * 2], 16) * 16 + parseInt(hexSequence[(i * 2) + 1], 16) is hexStringCopy.charCodeAt(i)
				true

			toLittleEndian: (hexString, offset = 0, length) ->
				length = length || hexString.length - offset
				res = ""
				hexString.substr(offset, length).split("").forEach (char) -> res = char + res
				res

			getFileBytes: (file, offset, size, success, error) ->
				reader = new FileReader
				reader.onloadend = (evt) ->
					if evt.target.readyState is FileReader.DONE
						success evt.target.result
					else
						error?()
				blob = file.slice(offset, size)
				reader.readAsBinaryString blob

		# Main

		self.addEventListener "message", (e) ->
				strategies = e.data.strategies
				file = e.data.file

				fileInfo = {}
				strategiesLeft = strategies.length
				readError = -> console.error "There was an error while reading the information for this file: #{file}"
				readFileStart = (hexString) ->
					for strategy in strategies
						self[strategy].parse file, hexString, (strategyFileInfo) ->
							if strategyFileInfo and typeof strategyFileInfo is "object"
								fileInfo[key] = strategyFileInfo[key] for key of strategyFileInfo
							self.postMessage(fileInfo) unless --strategiesLeft
							null
					null

				# We actually need only for bytes for this part but we read more
				# so we don't have to read them again and can pass this as argument
				# to the specific parser
				HexReader.getFileBytes file, 0, 132, readFileStart, readError

				setTimeout ->
					if strategiesLeft
						fileInfo.error = "Timed out"
						self.postMessage fileInfo
				, 2000
		null

	blob = new Blob ["(#{worker.toString()})()"], {type: "text/javascript"}
	blobURL = window.URL.createObjectURL blob
	worker = new Worker blobURL

	getInfo: (file, strategies = ["MP3", "WAV", "AIFF"]) ->
		deferred = $q.defer()

		worker.addEventListener "message", (e) ->
			deferred.resolve e.data

		worker.postMessage
			file: file
			strategies: strategies

		deferred.promise
]