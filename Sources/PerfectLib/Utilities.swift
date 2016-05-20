//
//  Utilities.swift
//  PerfectLib
//
//  Created by Kyle Jessup on 7/17/15.
//	Copyright (C) 2015 PerfectlySoft, Inc.
//
//===----------------------------------------------------------------------===//
//
// This source file is part of the Perfect.org open source project
//
// Copyright (c) 2015 - 2016 PerfectlySoft Inc. and the Perfect project authors
// Licensed under Apache License v2.0
//
// See http://perfect.org/licensing.html for license information
//
//===----------------------------------------------------------------------===//
//

#if os(Linux)
import LinuxBridge
#else
import Darwin
#endif

/// This class permits an UnsafeMutablePointer to be used as a GeneratorType
public struct GenerateFromPointer<T> : IteratorProtocol {
	
	public typealias Element = T
	
	var count = 0
	var pos = 0
	var from: UnsafeMutablePointer<T>
	
	/// Initialize given an UnsafeMutablePointer and the number of elements pointed to.
	public init(from: UnsafeMutablePointer<T>, count: Int) {
		self.from = from
		self.count = count
	}
	#if swift(>=3.0)
	#else
	public init(from: UnsafeMutablePointer<T>?, count: Int) {
		self.from = from!
		self.count = count
	}
	#endif
	
	/// Return the next element or nil if the sequence has been exhausted.
	mutating public func next() -> Element? {
		guard count > 0 else {
			return nil
		}
		self.count -= 1
		let result = self.from[self.pos]
		self.pos += 1
		return result
	}
}

/// A generalized wrapper around the Unicode codec operations.
public struct Encoding {
	
	/// Return a String given a character generator.
	public static func encode<D : UnicodeCodec, G : IteratorProtocol where G.Element == D.CodeUnit>(codec inCodec: D, generator: G) -> String {
		var encodedString = ""
		var finished: Bool = false
		var mutableDecoder = inCodec
		var mutableGenerator = generator
		repeat {
			let decodingResult = mutableDecoder.decode(&mutableGenerator)
			#if swift(>=3.0)
			switch decodingResult {
			case .scalarValue(let char):
				encodedString.append(char)
			case .emptyInput:
				finished = true
				/* ignore errors and unexpected values */
			case .error:
				finished = true
			}
			#else
			switch decodingResult {
				case .Result(let char):
					encodedString.append(char)
				case .EmptyInput:
					finished = true
					/* ignore errors and unexpected values */
				case .Error:
					finished = true
			}
			#endif
		} while !finished
		return encodedString
	}
}

/// Utility wrapper permitting a UTF-16 character generator to encode a String.
public struct UTF16Encoding {
	
	/// Use a UTF-16 character generator to create a String.
	public static func encode<G : IteratorProtocol where G.Element == UTF16.CodeUnit>(generator: G) -> String {
		return Encoding.encode(codec: UTF16(), generator: generator)
	}
}

/// Utility wrapper permitting a UTF-8 character generator to encode a String. Also permits a String to be converted into a UTF-8 byte array.
public struct UTF8Encoding {
	
	/// Use a character generator to create a String.
	public static func encode<G : IteratorProtocol where G.Element == UTF8.CodeUnit>(generator gen: G) -> String {
		return Encoding.encode(codec: UTF8(), generator: gen)
	}
	
	#if swift(>=3.0)
	/// Use a character sequence to create a String.
	public static func encode<S : Sequence where S.Iterator.Element == UTF8.CodeUnit>(bytes byts: S) -> String {
		return encode(generator: byts.makeIterator())
	}
	#else
	/// Use a character sequence to create a String.
	public static func encode<S : SequenceType where S.Generator.Element == UTF8.CodeUnit>(bytes bytes: S) -> String {
		return encode(generator: bytes.generate())
	}
	#endif
	
	/// Decode a String into an array of UInt8.
	public static func decode(string str: String) -> Array<UInt8> {
		return [UInt8](str.utf8)
	}
}

extension UInt8 {
	private var shouldURLEncode: Bool {
		let cc = self
		return ( ( cc >= 128 )
			|| ( cc < 33 )
			|| ( cc >= 34  && cc < 38 )
			|| ( ( cc > 59  && cc < 61) || cc == 62 || cc == 58)
			|| ( ( cc >= 91  && cc < 95 ) || cc == 96 )
			|| ( cc >= 123 && cc <= 126 )
			|| self == 43 )
	}
	private var hexString: String {
		var s = ""
		let b = self >> 4
		s.append(UnicodeScalar(b > 9 ? b - 10 + 65 : b + 48))
		let b2 = self & 0x0F
		s.append(UnicodeScalar(b2 > 9 ? b2 - 10 + 65 : b2 + 48))
		return s
	}
}

extension String {
	/// Returns the String with all special HTML characters encoded.
	public var stringByEncodingHTML: String {
		var ret = ""
		var g = self.unicodeScalars.makeIterator()
		while let c = g.next() {
			if c < UnicodeScalar(0x0009) {
				ret.append("&#x");
				ret.append(UnicodeScalar(0x0030 + UInt32(c)));
				ret.append(";");
			} else if c == UnicodeScalar(0x0022) {
				ret.append("&quot;")
			} else if c == UnicodeScalar(0x0026) {
				ret.append("&amp;")
			} else if c == UnicodeScalar(0x0027) {
				ret.append("&#39;")
			} else if c == UnicodeScalar(0x003C) {
				ret.append("&lt;")
			} else if c == UnicodeScalar(0x003E) {
				ret.append("&gt;")
			} else if c > UnicodeScalar(126) {
				ret.append("&#\(UInt32(c));")
			} else {
				ret.append(c)
			}
		}
		return ret
	}
	
	/// Returns the String with all special URL characters encoded.
	public var stringByEncodingURL: String {
		var ret = ""
		var g = self.utf8.makeIterator()
		while let c = g.next() {
			if c.shouldURLEncode {
				ret.append(UnicodeScalar(37))
				ret.append(c.hexString)
			} else {
				ret.append(UnicodeScalar(c))
			}
		}
		return ret
	}
	
	
	// Utility - not sure if it makes the most sense to have here or outside or elsewhere
	static func byteFromHexDigits(one c1v: UInt8, two c2v: UInt8) -> UInt8? {
		
		let capA: UInt8 = 65
		let capF: UInt8 = 70
		let lowA: UInt8 = 97
		let lowF: UInt8 = 102
		let zero: UInt8 = 48
		let nine: UInt8 = 57
		
		var newChar = UInt8(0)
		
		if c1v >= capA && c1v <= capF {
			newChar = c1v - capA + 10
		} else if c1v >= lowA && c1v <= lowF {
			newChar = c1v - lowA + 10
		} else if c1v >= zero && c1v <= nine {
			newChar = c1v - zero
		} else {
			return nil
		}
		
		newChar *= 16
		
		if c2v >= capA && c2v <= capF {
			newChar += c2v - capA + 10
		} else if c2v >= lowA && c2v <= lowF {
			newChar += c2v - lowA + 10
		} else if c2v >= zero && c2v <= nine {
			newChar += c2v - zero
		} else {
			return nil
		}
		return newChar
	}
	
	public var stringByDecodingURL: String? {
		
		let percent: UInt8 = 37
		let plus: UInt8 = 43
		let space: UInt8 = 32
		
		var bytesArray = [UInt8]()
		
		var g = self.utf8.makeIterator()
		while let c = g.next() {
			if c == percent {

				guard let c1v = g.next() else {
					return nil
				}
				guard let c2v = g.next() else {
					return nil
				}
				
				guard let newChar = String.byteFromHexDigits(one: c1v, two: c2v) else {
					return nil
				}
				
				bytesArray.append(newChar)
			} else if c == plus {
				bytesArray.append(space)
			} else {
				bytesArray.append(c)
			}
		}
		
		return UTF8Encoding.encode(bytes: bytesArray)
	}
	
	public var decodeHex: [UInt8]? {
		
		var bytesArray = [UInt8]()
		var g = self.utf8.makeIterator()
		while let c1v = g.next() {
			
			guard let c2v = g.next() else {
				return nil
			}
			
			guard let newChar = String.byteFromHexDigits(one: c1v, two: c2v) else {
				return nil
			}
			
			bytesArray.append(newChar)
		}
		return bytesArray
	}
}

extension String {
	/// Parse uuid string
	/// Results undefined if the string is not a valid UUID
	public func asUUID() -> uuid_t {
		let u = UnsafeMutablePointer<UInt8>.allocatingCapacity(sizeof(uuid_t))
		defer {
			u.deallocateCapacity(sizeof(uuid_t))
		}
		uuid_parse(self, u)
		return uuid_t(u[0], u[1], u[2], u[3], u[4], u[5], u[6], u[7], u[8], u[9], u[10], u[11], u[12], u[13], u[14], u[15])
	}
	
	public static func fromUUID(uuid: uuid_t) -> String {
		let u = UnsafeMutablePointer<UInt8>.allocatingCapacity(sizeof(uuid_t))
		let unu = UnsafeMutablePointer<Int8>.allocatingCapacity(37) // as per spec. 36 + null
		
		defer {
			u.deallocateCapacity(sizeof(uuid_t))
			unu.deallocateCapacity(37)
		}
		u[0] = uuid.0;u[1] = uuid.1;u[2] = uuid.2;u[3] = uuid.3;u[4] = uuid.4;u[5] = uuid.5;u[6] = uuid.6;u[7] = uuid.7
		u[8] = uuid.8;u[9] = uuid.9;u[10] = uuid.10;u[11] = uuid.11;u[12] = uuid.12;u[13] = uuid.13;u[14] = uuid.14;u[15] = uuid.15
		uuid_unparse_lower(u, unu)
		
		return String(validatingUTF8: unu)!
	}
}

public func empty_uuid() -> uuid_t {
	return uuid_t(0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
}

public func random_uuid() -> uuid_t {
	let u = UnsafeMutablePointer<UInt8>.allocatingCapacity(sizeof(uuid_t))
	defer {
		u.deallocateCapacity(sizeof(uuid_t))
	}
	uuid_generate_random(u)
	// is there a better way?
	return uuid_t(u[0], u[1], u[2], u[3], u[4], u[5], u[6], u[7], u[8], u[9], u[10], u[11], u[12], u[13], u[14], u[15])
}

extension String {
	
	/// Parse an HTTP Digest authentication header returning a Dictionary containing each part.
	public func parseAuthentication() -> [String:String] {
		var ret = [String:String]()
		if let _ = self.range(ofString: "Digest ") {
			ret["type"] = "Digest"
			let wantFields = ["username", "nonce", "nc", "cnonce", "response", "uri", "realm", "qop", "algorithm"]
			for field in wantFields {
				if let foundField = String.extractField(from: self, named: field) {
					ret[field] = foundField
				}
			}
		}
		return ret
	}
	
	private static func extractField(from frm: String, named: String) -> String? {
		guard let range = frm.range(ofString: named + "=") else {
			return nil
		}
		
		var currPos = range.upperBound
		var ret = ""
		let quoted = frm[currPos] == "\""
		if quoted {
			currPos = frm.index(after: currPos)
			let tooFar = frm.endIndex
			while currPos != tooFar {
				if frm[currPos] == "\"" {
					break
				}
				ret.append(frm[currPos])
				currPos = frm.index(after: currPos)
			}
		} else {
			let tooFar = frm.endIndex
			while currPos != tooFar {
				if frm[currPos] == "," {
					break
				}
				ret.append(frm[currPos])
				currPos = frm.index(after: currPos)
			}
		}
		return ret
	}
}

extension String {
	
	public func stringByReplacing(string strng: String, withString: String) -> String {
		
		guard !strng.isEmpty else {
			return self
		}
		guard !self.isEmpty else {
			return self
		}
		
		var ret = ""
		var idx = self.startIndex
		let endIdx = self.endIndex
		
		while idx != endIdx {
			if self[idx] == strng[strng.startIndex] {
				var newIdx = self.index(after: idx)
				var findIdx = strng.index(after: strng.startIndex)
				let findEndIdx = strng.endIndex
				
				while newIdx != endIndex && findIdx != findEndIdx && self[newIdx] == strng[findIdx] {
					newIdx = self.index(after: newIdx)
					findIdx = strng.index(after: findIdx)
				}
				
				if findIdx == findEndIdx { // match
					ret.append(withString)
					idx = newIdx
					continue
				}
			}
			ret.append(self[idx])
			idx = self.index(after: idx)
		}
		
		return ret
	}
	
	// For compatibility due to shifting swift
	public func contains(string strng: String) -> Bool {
		return nil != self.range(ofString: strng)
	}
}

extension String {
	
	var pathSeparator: UnicodeScalar {
		return UnicodeScalar(47)
	}
	
	var extensionSeparator: UnicodeScalar {
		return UnicodeScalar(46)
	}
	
	private var beginsWithSeparator: Bool {
		let unis = self.characters
		guard unis.count > 0 else {
			return false
		}
		return unis[unis.startIndex] == Character(pathSeparator)
	}
	
	private var endsWithSeparator: Bool {
		let unis = self.characters
		guard unis.count > 0 else {
			return false
		}
		return unis[unis.index(before: unis.endIndex)] == Character(pathSeparator)
	}
	
	private func pathComponents(addFirstLast addfl: Bool) -> [String] {
		var r = [String]()
		let unis = self.characters
		guard unis.count > 0 else {
			return r
		}
		
		if addfl && self.beginsWithSeparator {
			r.append(String(pathSeparator))
		}
		
		r.append(contentsOf: self.characters.split(separator: Character(pathSeparator)).map { String($0) })
		
		if addfl && self.endsWithSeparator {
			if !self.beginsWithSeparator || r.count > 1 {
				r.append(String(pathSeparator))
			}
		}
		return r
	}
	
	var pathComponents: [String] {
		return self.pathComponents(addFirstLast: true)
	}
	
	var lastPathComponent: String {
		let last = self.pathComponents(addFirstLast: false).last ?? ""
		if last.isEmpty && self.characters.first == Character(pathSeparator) {
			return String(pathSeparator)
		}
		return last
	}
	
	var stringByDeletingLastPathComponent: String {
		var comps = self.pathComponents(addFirstLast: false)
		guard comps.count > 1 else {
			if self.beginsWithSeparator {
				return String(pathSeparator)
			}
			return ""
		}
		comps.removeLast()
		let joined = comps.joined(separator: String(pathSeparator))
		if self.beginsWithSeparator {
			return String(pathSeparator) + joined
		}
		return joined
	}
	
	var stringByDeletingPathExtension: String {
		let unis = self.characters
		let startIndex = unis.startIndex
		var endIndex = unis.endIndex
		while endIndex != startIndex {
			if unis[unis.index(before: endIndex)] != Character(pathSeparator) {
				break
			}
			endIndex = unis.index(before: endIndex)
		}
		let noTrailsIndex = endIndex
		while endIndex != startIndex {
			endIndex = unis.index(before: endIndex)
			if unis[endIndex] == Character(extensionSeparator) {
				break
			}
		}
		guard endIndex != startIndex else {
			if noTrailsIndex == startIndex {
				return self
			}
			return self[startIndex..<noTrailsIndex]
		}
		return self[startIndex..<endIndex]
	}
	
	var pathExtension: String {
		let unis = self.characters
		let startIndex = unis.startIndex
		var endIndex = unis.endIndex
		while endIndex != startIndex {
			if unis[unis.index(before: endIndex)] != Character(pathSeparator) {
				break
			}
			endIndex = unis.index(before: endIndex)
		}
		let noTrailsIndex = endIndex
		while endIndex != startIndex {
			endIndex = unis.index(before: endIndex)
			if unis[endIndex] == Character(extensionSeparator) {
				break
			}
		}
		guard endIndex != startIndex else {
			return ""
		}
		return self[unis.index(after: endIndex)..<noTrailsIndex]
	}

	var stringByResolvingSymlinksInPath: String {
		return File(self).realPath()
		
//		let absolute = self.beginsWithSeparator
//		let components = self.pathComponents(false)
//		var s = absolute ? "/" : ""
//		for component in components {
//			if component == "." {
//				s.appendContentsOf(".")
//			} else if component == ".." {
//				s.appendContentsOf("..")
//			} else {
//				let file = File(s + "/" + component)
//				s = file.realPath()
//			}
//		}
//		let ary = s.pathComponents(false) // get rid of slash runs
//		return absolute ? "/" + ary.joinWithSeparator(String(pathSeparator)) : ary.joinWithSeparator(String(pathSeparator))
	}
}

extension String {
	func begins(with str: String) -> Bool {
	#if swift(>=3.0)
		return self.characters.starts(with: str.characters)
	#else
		return self.hasPrefix(str)
	#endif
	}
	
	func ends(with str: String) -> Bool {
		let mine = self.characters
		let theirs = str.characters
		
		guard mine.count >= theirs.count else {
			return false
		}
		
		return str.begins(with: self[self.index(self.endIndex, offsetBy: -theirs.count)..<mine.endIndex])
	}
}

/// Returns the current time according to ICU
/// ICU dates are the number of milliseconds since the reference date of Thu, 01-Jan-1970 00:00:00 GMT
public func getNow() -> Double {
	
	var posixTime = timeval()
	gettimeofday(&posixTime, nil)
	return Double((posixTime.tv_sec * 1000) + (Int(posixTime.tv_usec)/1000))
}
/// Converts the milliseconds based ICU date to seconds since the epoch
public func icuDateToSeconds(_ icuDate: Double) -> Int {
	return Int(icuDate / 1000)
}
/// Converts the seconds since the epoch into the milliseconds based ICU date
public func secondsToICUDate(_ seconds: Int) -> Double {
	return Double(seconds * 1000)
}

/// Format a date value according to the indicated format string and return a date string.
/// - parameter date: The date value
/// - parameter format: The format by which the date will be formatted
/// - parameter timezone: The optional timezone in which the date is expected to be based. Default is the local timezone.
/// - parameter locale: The optional locale which will be used when parsing the date. Default is the current global locale.
/// - returns: The resulting date string
/// - throws: `PerfectError.ICUError`
/// - Seealso [Date Time Format Syntax](http://userguide.icu-project.org/formatparse/datetime#TOC-Date-Time-Format-Syntax)
public func formatDate(_ date: Double, format: String, timezone inTimezone: String? = nil, locale inLocale: String? = nil) throws -> String {
	
	var t = tm()
	var time = time_t(date / 1000.0)
	gmtime_r(&time, &t)
	let maxResults = 1024
	let results = UnsafeMutablePointer<Int8>.allocatingCapacity(maxResults)
	defer {
		results.deallocateCapacity(maxResults)
	}
	let res = strftime(results, maxResults, format, &t)
	if res > 0 {
		let formatted = String(validatingUTF8: results)
		return formatted!
	}
	try ThrowSystemError()
}














