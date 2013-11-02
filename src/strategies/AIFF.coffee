"use strict"
angular.module("audiometa").factory "AIFF", ["HexReader", "$q", "ID3", (HexReader, $q, ID3) ->
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
	parse: (file, firstBytes) ->
		fileInfo = { type: "AIFF" }
		deferred = $q.defer()
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
				ID3.getAndAddID3v2(id3Tag.content, fileInfo, file, deferred)
			else
				ssndTag = findTag firstBytes.substr(12), "SSND"
				if ssndTag
					offset = ssndTag.offset + 8 + ssndTag.length
					HexReader.getFileBytes(file, offset, file.size).then (hexString) ->
						while (index = hexString.indexOf("ID3 ")) > 0
							hexString = hexString.substr index + 4 # skip "ID3 "
							length = HexReader.getBits hexString, 0, 32
							if hexString.length is length + 4
								hexString = hexString.substr 4 # skip length of the AIFF ID3 Header
								ID3.getAndAddID3v2 hexString, fileInfo
								break
						deferred.resolve fileInfo
				else
					deferred.resolve fileInfo
		else deferred.resolve()
		deferred.promise
]