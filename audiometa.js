(function() {
  angular.module("audiometa", []).constant("Strategies", ["MP3", "WAV", "AIFF"]);

}).call(this);

(function() {
  "use strict";
  angular.module("audiometa").factory("AudioParser", [
    "$window", "$q", "HexReader", "Strategies", "$injector", function($window, $q, HexReader, Strategies, $injector) {
      return {
        getInfo: function(file) {
          var deferred, fileInfo, readError, readFileStart;
          if (!$window.FileReader) {
            return;
          }
          deferred = $q.defer();
          fileInfo = {};
          readError = function() {
            return console.error("There was an error while reading the information for this file: " + file);
          };
          readFileStart = function(hexString) {
            var promises, res, strategy, _i, _len;
            promises = [];
            for (_i = 0, _len = Strategies.length; _i < _len; _i++) {
              strategy = Strategies[_i];
              res = $injector.get(strategy).parse(file, hexString);
              promises.push(res);
              res.then(function(strategyFileInfo) {
                var key;
                if (strategyFileInfo && typeof strategyFileInfo === "object") {
                  for (key in strategyFileInfo) {
                    fileInfo[key] = strategyFileInfo[key];
                  }
                }
                return null;
              });
            }
            return $q.all(promises).then(function() {
              return deferred.resolve(fileInfo);
            });
          };
          HexReader.getFileBytes(file, 0, 132).then(readFileStart, readError);
          return deferred.promise;
        }
      };
    }
  ]);

}).call(this);

(function() {
  "use strict";
  angular.module("audiometa").factory("HexReader", [
    "$q", "$window", "$rootScope", function($q, $window, $rootScope) {
      var getBitsRec;
      getBitsRec = function(hexString, offset, length) {
        var bitOffset, byteOffset, endOffset, res;
        endOffset = offset + length;
        byteOffset = Math.floor(endOffset / 8);
        bitOffset = endOffset % 8;
        res = hexString.charCodeAt(byteOffset) >> (8 - bitOffset);
        if (length > bitOffset) {
          res |= 255 & hexString.charCodeAt(byteOffset - 1) << bitOffset;
        } else {
          res &= 255 >> (8 - length);
        }
        res = [res];
        if (length > 8) {
          res = res.concat(getBitsRec(hexString, offset, length - 8));
        }
        return res;
      };
      return {
        getBits: function(hexString, offset, length, significantBits) {
          var ba, rad, res;
          if (significantBits == null) {
            significantBits = 8;
          }
          offset = offset || 0;
          length = length || (hexString.length - offset) * 8;
          rad = Math.pow(2, significantBits);
          ba = getBitsRec(hexString, offset, length);
          res = 0;
          ba.forEach(function(byte, index) {
            return res += byte * Math.pow(rad, index);
          });
          return res;
        },
        checksequenceAsString: function(hexString, byteOffset, sequence) {
          return hexString.substr(byteOffset, sequence.length) === sequence;
        },
        checksequenceAsHexString: function(hexString, byteOffset, hexSequence, bitCount) {
          var bitIgnore, cache, ffPaddedChar, hexStringCopy, i, len;
          len = hexSequence.length / 2;
          bitIgnore = bitCount != null ? len * 8 - bitCount : void 0;
          hexStringCopy = hexString.substr(byteOffset, len);
          if (bitIgnore) {
            cache = 0;
            while (bitIgnore) {
              bitIgnore--;
              cache += Math.pow(2, bitIgnore);
            }
            ffPaddedChar = String.fromCharCode(hexStringCopy.charCodeAt(len - 1) | cache);
            hexStringCopy = hexStringCopy.substr(0, len - 1) + ffPaddedChar;
          }
          i = len;
          while (i--) {
            if (parseInt(hexSequence[i * 2], 16) * 16 + parseInt(hexSequence[(i * 2) + 1], 16) !== hexStringCopy.charCodeAt(i)) {
              return false;
            }
          }
          return true;
        },
        toLittleEndian: function(hexString, offset, length) {
          var res;
          if (offset == null) {
            offset = 0;
          }
          length = length || hexString.length - offset;
          res = "";
          hexString.substr(offset, length).split("").forEach(function(char) {
            return res = char + res;
          });
          return res;
        },
        getFileBytes: function(file, offset, size) {
          var blob, deferred, reader;
          deferred = $q.defer();
          reader = new $window.FileReader;
          reader.onloadend = function(evt) {
            return $rootScope.$apply(function() {
              if (evt.target.readyState === FileReader.DONE) {
                return deferred.resolve(evt.target.result);
              } else {
                return deferred.reject();
              }
            });
          };
          blob = file.slice(offset, size);
          reader.readAsBinaryString(blob);
          return deferred.promise;
        }
      };
    }
  ]);

}).call(this);

(function() {
  "use strict";
  angular.module("audiometa").factory("ID3", [
    "HexReader", function(HexReader) {
      var addID3v1, addID3v2, addID3v2_2, addID3v2_3, getAndAddID3v2, getId3v2Frames, getSize, isID3v1, isID3v2, trimSubStr;
      trimSubStr = function(string, offset, length) {
        return string.substr(offset, length).replace(/\x00/g, '');
      };
      getSize = function(hexString, byteOffset, length) {
        if (length == null) {
          length = 4;
        }
        return HexReader.getBits(hexString, byteOffset * 8, length * 8, 7);
      };
      getId3v2Frames = function(hexString, offset, id3v2Size, tagLength, frameHeaderLength) {
        var frames, getFramesRec;
        getFramesRec = function() {
          var frameName, size;
          if (offset < id3v2Size) {
            size = getSize(hexString, offset + tagLength, tagLength);
            frameName = hexString.substr(offset, tagLength);
            if (parseInt(frameName.charCodeAt(0)) !== 0) {
              frames[frameName] = trimSubStr(hexString, offset + frameHeaderLength, size);
              offset += frameHeaderLength + size;
              return getFramesRec();
            }
          }
        };
        frames = {};
        getFramesRec();
        return frames;
      };
      addID3v2 = function(hexString, fileInfo, id3v2Size, decodeMP3Header) {
        var id3minorVersion;
        id3minorVersion = hexString.charCodeAt(3);
        if (id3minorVersion === 2) {
          addID3v2_2(hexString, fileInfo, id3v2Size, decodeMP3Header);
        } else if (id3minorVersion === 3) {
          addID3v2_3(hexString, fileInfo, id3v2Size, decodeMP3Header);
        }
        if (decodeMP3Header) {
          return decodeMP3Header(hexString.substr(id3v2Size), fileInfo);
        }
      };
      addID3v2_2 = function(hexString, fileInfo, id3v2Size) {
        var album, artist, firstFrameOffset, id3v2Frames, title;
        firstFrameOffset = 10;
        id3v2Frames = getId3v2Frames(hexString, firstFrameOffset, id3v2Size, 3, 6);
        artist = id3v2Frames.TP1 || id3v2Frames.TP2 || id3v2Frames.TCM || id3v2Frames.TP3 || id3v2Frames.TP4;
        if (artist) {
          fileInfo.artist = artist;
        }
        title = id3v2Frames.TT2 || id3v2Frames.TT1 || id3v2Frames.TT3;
        if (title) {
          fileInfo.title = title;
        }
        album = id3v2Frames.TAL;
        if (album) {
          fileInfo.album = album;
        }
        return null;
      };
      addID3v2_3 = function(hexString, fileInfo, id3v2Size) {
        var album, artist, extHeaderPresent, extHeaderSize, firstFrameOffset, id3v2Frames, title;
        extHeaderPresent = (HexReader.getBits(hexString, 41, 1)) === 1;
        firstFrameOffset = 10;
        if (extHeaderPresent) {
          extHeaderSize = getSize(hexString, 10);
          firstFrameOffset += extHeaderSize;
        }
        id3v2Frames = getId3v2Frames(hexString, firstFrameOffset, id3v2Size, 4, 10);
        artist = id3v2Frames.TPE1 || id3v2Frames.TPE2 || id3v2Frames.TCOM || id3v2Frames.TPE3 || id3v2Frames.TPE4;
        if (artist) {
          fileInfo.artist = artist;
        }
        title = id3v2Frames.TIT2 || id3v2Frames.TIT1 || id3v2Frames.TIT3;
        if (title) {
          fileInfo.title = title;
        }
        album = id3v2Frames.TALB;
        if (album) {
          fileInfo.album = album;
        }
        return null;
      };
      getAndAddID3v2 = function(hexString, fileInfo, file, deferred, decodeMP3Header) {
        var footerPresent, getInfoAndResolve, mp3HeaderLength, totalSize;
        mp3HeaderLength = decodeMP3Header ? 4 : 0;
        getInfoAndResolve = function() {
          addID3v2(hexString, fileInfo, totalSize, decodeMP3Header);
          if (deferred) {
            return deferred.resolve(fileInfo);
          }
        };
        footerPresent = (HexReader.getBits(hexString, 43, 1)) === 1;
        totalSize = (getSize(hexString, 6)) + (footerPresent ? 20 : 10);
        if (hexString.length < totalSize + mp3HeaderLength) {
          HexReader.getFileBytes(file, 0, totalSize + mp3HeaderLength).then(function(_hexString) {
            hexString = _hexString;
            return getInfoAndResolve();
          });
        } else {
          getInfoAndResolve();
        }
        return null;
      };
      isID3v1 = function(hexString) {
        return HexReader.checksequenceAsString(hexString, 0, "TAG");
      };
      isID3v2 = function(hexString) {
        return HexReader.checksequenceAsString(hexString, 0, "ID3");
      };
      addID3v1 = function(hexString, fileInfo) {
        var album, artist, title;
        title = trimSubStr(hexString, 3, 30);
        if (title) {
          fileInfo.title = title;
        }
        artist = trimSubStr(hexString, 33, 30);
        if (artist) {
          fileInfo.artist = artist;
        }
        album = trimSubStr(hexString, 63, 30);
        if (album) {
          return fileInfo.album = album;
        }
      };
      return {
        addID3v1: addID3v1,
        addID3v2: addID3v2,
        getAndAddID3v2: getAndAddID3v2,
        isID3v1: isID3v1,
        isID3v2: isID3v2
      };
    }
  ]);

}).call(this);

(function() {
  "use strict";
  angular.module("audiometa").factory("AIFF", [
    "HexReader", "$q", "ID3", function(HexReader, $q, ID3) {
      var findTag;
      findTag = function(hexString, tag, offset) {
        var length;
        offset = offset || 0;
        length = HexReader.getBits(hexString, 32, 32);
        if (hexString.substr(0, tag.length) === tag) {
          return {
            content: hexString,
            length: length,
            offset: offset
          };
        } else {
          if (length + 16 < hexString.length) {
            return findTag(hexString.substr(length + 8), tag, offset + length + 8);
          } else {
            return null;
          }
        }
      };
      return {
        parse: function(file, firstBytes) {
          var commTag, deferred, fileInfo, hexString, id3Tag, offset, ssndTag;
          fileInfo = {
            type: "AIFF"
          };
          deferred = $q.defer();
          if (HexReader.checksequenceAsString(firstBytes, 0, "FORM") && HexReader.checksequenceAsString(firstBytes, 8, "AIFF")) {
            commTag = findTag(firstBytes.substr(12), "COMM");
            if (commTag) {
              hexString = commTag.content;
              fileInfo.channels = HexReader.getBits(hexString, 64, 16);
              fileInfo.bits = HexReader.getBits(hexString, 14 * 8, 16);
              fileInfo.sampleRate = HexReader.getBits(hexString, 18 * 8, 16);
            }
            id3Tag = findTag(firstBytes.substr(12), "ID3 ");
            if (id3Tag) {
              ID3.getAndAddID3v2(id3Tag.content, fileInfo, file, deferred);
            } else {
              ssndTag = findTag(firstBytes.substr(12), "SSND");
              if (ssndTag) {
                offset = ssndTag.offset + 8 + ssndTag.length;
                HexReader.getFileBytes(file, offset, file.size).then(function(hexString) {
                  var index, length;
                  while ((index = hexString.indexOf("ID3 ")) > 0) {
                    hexString = hexString.substr(index + 4);
                    length = HexReader.getBits(hexString, 0, 32);
                    if (hexString.length === length + 4) {
                      hexString = hexString.substr(4);
                      ID3.getAndAddID3v2(hexString, fileInfo);
                      break;
                    }
                  }
                  return deferred.resolve(fileInfo);
                });
              } else {
                deferred.resolve(fileInfo);
              }
            }
          } else {
            deferred.resolve();
          }
          return deferred.promise;
        }
      };
    }
  ]);

}).call(this);

(function() {
  "use strict";
  angular.module("audiometa").factory("MP3", [
    "$window", "$q", "HexReader", "ID3", function($window, $q, HexReader, ID3) {
      var addMP3Header, bitRates, getBitRate, isMP3, mpegLayer, mpegVersion;
      bitRates = [
        {}, {
          v1l1: 32,
          v1l2: 32,
          v1l3: 32,
          v2l1: 32,
          v2l2: 8,
          v2l3: 8
        }, {
          v1l1: 64,
          v1l2: 48,
          v1l3: 40,
          v2l1: 48,
          v2l2: 16,
          v2l3: 16
        }, {
          v1l1: 96,
          v1l2: 56,
          v1l3: 48,
          v2l1: 56,
          v2l2: 24,
          v2l3: 24
        }, {
          v1l1: 128,
          v1l2: 64,
          v1l3: 56,
          v2l1: 64,
          v2l2: 32,
          v2l3: 32
        }, {
          v1l1: 160,
          v1l2: 80,
          v1l3: 64,
          v2l1: 80,
          v2l2: 40,
          v2l3: 40
        }, {
          v1l1: 192,
          v1l2: 96,
          v1l3: 80,
          v2l1: 96,
          v2l2: 48,
          v2l3: 48
        }, {
          v1l1: 224,
          v1l2: 112,
          v1l3: 96,
          v2l1: 112,
          v2l2: 56,
          v2l3: 56
        }, {
          v1l1: 256,
          v1l2: 128,
          v1l3: 112,
          v2l1: 128,
          v2l2: 64,
          v2l3: 64
        }, {
          v1l1: 288,
          v1l2: 160,
          v1l3: 128,
          v2l1: 144,
          v2l2: 80,
          v2l3: 80
        }, {
          v1l1: 320,
          v1l2: 192,
          v1l3: 160,
          v2l1: 160,
          v2l2: 96,
          v2l3: 96
        }, {
          v1l1: 352,
          v1l2: 224,
          v1l3: 192,
          v2l1: 176,
          v2l2: 112,
          v2l3: 112
        }, {
          v1l1: 384,
          v1l2: 256,
          v1l3: 224,
          v2l1: 192,
          v2l2: 128,
          v2l3: 128
        }, {
          v1l1: 416,
          v1l2: 320,
          v1l3: 256,
          v2l1: 224,
          v2l2: 144,
          v2l3: 144
        }, {
          v1l1: 448,
          v1l2: 384,
          v1l3: 320,
          v2l1: 256,
          v2l2: 160,
          v2l3: 160
        }
      ];
      mpegVersion = [0, 0, 2, 1];
      mpegLayer = [0, 3, 2, 1];
      isMP3 = function(hexString) {
        return HexReader.checksequenceAsHexString(hexString, 0, "FFFF", 11);
      };
      addMP3Header = function(hexString, fileInfo) {
        var bitRate;
        bitRate = getBitRate(hexString);
        if (bitRate) {
          return fileInfo["bitRate"] = bitRate;
        }
      };
      getBitRate = function(hexString) {
        var specBitRate, specLayer, specVersion, _ref;
        specVersion = mpegVersion[HexReader.getBits(hexString, 11, 2)];
        specLayer = mpegLayer[HexReader.getBits(hexString, 13, 2)];
        specBitRate = HexReader.getBits(hexString, 16, 4);
        return (_ref = bitRates[specBitRate]) != null ? _ref["v" + specVersion + "l" + specLayer] : void 0;
      };
      return {
        _forUnitTests: {
          isMP3: isMP3,
          addMP3Header: addMP3Header,
          getBitRate: getBitRate
        },
        parse: function(file, firstBytes) {
          var deferred, fileInfo, readError, readFileEnd;
          deferred = $q.defer();
          fileInfo = {
            type: "MP3"
          };
          readError = function() {
            return console.error("There was an error while reading the information for this file: " + file);
          };
          readFileEnd = function(hexString) {
            if (ID3.isID3v1(hexString)) {
              ID3.addID3v1(hexString, fileInfo);
            }
            return deferred.resolve(fileInfo);
          };
          if (ID3.isID3v2(firstBytes)) {
            ID3.getAndAddID3v2(firstBytes, fileInfo, file, deferred, addMP3Header);
          } else if (ID3.isID3v1(firstBytes)) {
            ID3.addID3v1(firstBytes, fileInfo);
            addMP3Header(firstBytes.substr(128), fileInfo);
            deferred.resolve(fileInfo);
          } else if (isMP3(firstBytes)) {
            addMP3Header(firstBytes, fileInfo);
            HexReader.getFileBytes(file, file.size - 128, file.size).then(readFileEnd, readError);
          } else {
            deferred.resolve();
          }
          return deferred.promise;
        }
      };
    }
  ]);

}).call(this);

(function() {
  "use strict";
  angular.module("audiometa").factory("WAV", [
    "HexReader", "$q", function(HexReader, $q) {
      return {
        parse: function(file, firstBytes) {
          var bitsPerSample, channelCount, deferred, fileInfo, sampleRate;
          deferred = $q.defer();
          fileInfo = {
            type: "WAV"
          };
          if (HexReader.checksequenceAsString(firstBytes, 0, "RIFF")) {
            sampleRate = HexReader.toLittleEndian(firstBytes, 24, 4);
            fileInfo.sampleRate = HexReader.getBits(sampleRate);
            bitsPerSample = HexReader.toLittleEndian(firstBytes, 34, 2);
            fileInfo.bits = HexReader.getBits(bitsPerSample);
            channelCount = HexReader.toLittleEndian(firstBytes, 22, 2);
            fileInfo.channels = HexReader.getBits(channelCount);
            deferred.resolve(fileInfo);
          } else {
            deferred.resolve();
          }
          return deferred.promise;
        }
      };
    }
  ]);

}).call(this);

/*
"use strict"
angular.module("audiometa").factory "XXX", ["HexReader", "$q", (HexReader, $q) ->
	parse: (file, firstBytes) ->
		deferred = $q.defer()
		if HexReader.checksequenceAsString firstBytes, 0, "XXX"
			deferred.resolve
				type: "XXX"
		else deferred.resolve()
		deferred.promise
]
*/


(function() {


}).call(this);
