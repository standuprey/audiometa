"use strict"
describe "Factory: HexReader", ->
	
	# load the controller's module
	beforeEach module "audioMeta"

	# globals
	toHex = (hexArray) -> hexArray.map((hex)-> String.fromCharCode(parseInt(hex, 16))).join ""

	hexString = toHex ["01", "FF", "00", "F1"]

	# Initialize the factory
	hexReaderFactory = undefined
	beforeEach inject ($injector) ->
		hexReaderFactory = $injector.get "HexReader"

	it "calls getBits and returns the right bits", ->
		res = hexReaderFactory.getBits hexString, 0, 8
		expect(res).toBe 1
		res = hexReaderFactory.getBits hexString, 14, 8
		expect(res).toBe 192
		res = hexReaderFactory.getBits hexString, 20, 4
		expect(res).toBe 0
		res = hexReaderFactory.getBits hexString, 4, 4
		expect(res).toBe 1
		res = hexReaderFactory.getBits hexString, 20, 8
		expect(res).toBe 15
		res = hexReaderFactory.getBits hexString, 25, 6
		expect(res).toBe 56
		res = hexReaderFactory.getBits hexString, 4, 12
		expect(res).toBe 511
		res = hexReaderFactory.getBits hexString, 4, 28
		expect(res).toBe 33489137

	it "calls checksequenceAsString and returns false if not equivalent", ->
		checksequenceAsString = hexReaderFactory.checksequenceAsString
		expect(checksequenceAsString("test", 1, "test")).toBe false
		expect(checksequenceAsString("test", 1, "esty")).toBe false

	it "calls checksequenceAsString and returns true if not equivalent", ->
		checksequenceAsString = hexReaderFactory.checksequenceAsString
		expect(checksequenceAsString("test", 0, "test")).toBe true
		expect(checksequenceAsString("test", 1, "est")).toBe true

	it "calls checksequenceAsHexString and returns false if not equivalent", ->
		checksequenceAsHexString = hexReaderFactory.checksequenceAsHexString
		expect(checksequenceAsHexString(hexString, 1, "FF01")).toBe false
		expect(checksequenceAsHexString(hexString, 2, "00", 4)).toBe false
		expect(checksequenceAsHexString(hexString, 3, "F0", 4)).toBe false

	it "calls checksequenceAsHexString and returns true if not equivalent", ->
		checksequenceAsHexString = hexReaderFactory.checksequenceAsHexString
		expect(checksequenceAsHexString(hexString, 1, "FF00")).toBe true
		expect(checksequenceAsHexString(hexString, 2, "00F1")).toBe true
		expect(checksequenceAsHexString(hexString, 3, "FF", 4)).toBe true

	it "retrieves bytes from a file with getFileBytes", inject ($rootScope) ->
		spyOn(FileReader.prototype, "readAsBinaryString").andCallFake (file) ->
			this.onloadend
				target:
					readyState: FileReader.DONE
					result: file

		result = ""
		runs ->
			hexReaderFactory.getFileBytes("toto", 0, 4).then (res) -> result = res
			$rootScope.$apply()
		waitsFor (-> result is "toto"), "reading the string 'toto'", 500
