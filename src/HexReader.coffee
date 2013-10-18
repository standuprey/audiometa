"use strict"
angular.module("audiometa").factory "HexReader", ["$q", "$window", "$rootScope", ($q, $window, $rootScope) ->

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
				cache += Math.pow 2, bitIgnore
				bitIgnore--
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

	getFileBytes: (file, offset, size) ->
		deferred = $q.defer()
		reader = new $window.FileReader
		reader.onloadend = (evt) ->
			$rootScope.$apply ->
				if evt.target.readyState is FileReader.DONE
					deferred.resolve evt.target.result
				else
					deferred.reject()
		blob = file.slice(offset, size)
		reader.readAsBinaryString blob
		deferred.promise
]