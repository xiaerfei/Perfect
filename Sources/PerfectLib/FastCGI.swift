//
//  FastCGI.swift
//  PerfectLib
//
//  Created by Kyle Jessup on 7/6/15.
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

// values which are part of the FastCGI protocol but are unused in this implementation are commented out

#if os(Linux)
import SwiftGlibc
#endif

let fcgiVersion1: UInt8 =		1

let fcgiBeginRequest: UInt8 =		1
//let FCGI_ABORT_REQUEST: UInt8 =		2
let fcgiEndRequest: UInt8 =		3
let fcgiParams: UInt8 =			4
let fcgiStdin: UInt8 =				5
let fcgiStdout: UInt8 =			6
//let FCGI_STDERR: UInt8 =			7
let fcgiData: UInt8 =				8
//let FCGI_GET_VALUES: UInt8 =		9
//let FCGI_GET_VALUES_RESULT: UInt8 =	10
//let FCGI_UNKNOWN_TYPE: UInt8 =		11

let fcgiXStdin: UInt8 = 		50

//let FCGI_KEEP_CONN =	1

//let FCGI_RESPONDER =	1
//let FCGI_AUTHORIZE =	2
//let FCGI_FILTER =		3

let fcgiRequestComplete = 	0
//let FCGI_CANT_MPX_CONN =		1
//let FCGI_OVERLOADED =			2
//let FCGI_UNKNOWN_ROLE = 		3

//let FCGI_MAX_CONNS =	"FCGI_MAX_CONNS"
//let FCGI_MAX_REQS =		"FCGI_MAX_REQS"
//let FCGI_MPXS_CONNS =	"FCGI_MPXS_CONNS"

let fcgiTimeoutSeconds = 5.0
let fcgiBaseRecordSize = 8

let fcgiBodyChunkSize = 0xFFFF

class FastCGIRecord {
	
	var version: UInt8 = 0
	var recType: UInt8 = 0
	var requestId: UInt16 = 0
	var contentLength: UInt16 = 0
	var paddingLength: UInt8 = 0
	var reserved: UInt8 = 0
	
	var content: [UInt8]? = nil
	var padding: [UInt8]? = nil
	
}

class FastCGIRequest : WebConnection {
	
	var connection: NetTCP
	var requestId: UInt16 = 0
	var requestParams: Dictionary<String, String> = Dictionary<String, String>()
	var stdin: [UInt8]? = nil
	var mimes: MimeReader? = nil
	
	var statusCode: Int
	var statusMsg: String
	
	var header: String = ""
	var wroteHeader: Bool = false
	
	var lastRecordType: UInt8 = 0
	
	init(net: NetTCP) {
		self.connection = net
		self.statusCode = 200
		self.statusMsg = "OK"
	}
	
	func setStatus(code cod: Int, message msg: String) {
		self.statusCode = cod
		self.statusMsg = msg
	}
	
	func getStatus() -> (Int, String) {
		return (self.statusCode, self.statusMsg)
	}
	
	func putStdinData(_ b: [UInt8]) {
		if self.stdin == nil && self.mimes == nil {
			let contentType = requestParams["CONTENT_TYPE"]
			if contentType == nil || !contentType!.begins(with: "multipart/form-data") {
				self.stdin = b
			} else {
				self.mimes = MimeReader(contentType!)//, Int(requestParams["CONTENT_LENGTH"] ?? "0")!)
				self.mimes!.addToBuffer(bytes: b)
			}
		} else if self.stdin != nil {
			self.stdin!.append(contentsOf: b)
		} else {
			self.mimes!.addToBuffer(bytes: b)
		}
	}
	
	func writeHeader(line h: String) {
		self.header += h + "\r\n"
	}
	
	func writeHeader(bytes b: [UInt8], completion: (Bool) -> ()) {
		if !wroteHeader {
			wroteHeader = true
			
			let statusLine = "Status: \(statusCode) \(statusMsg)\r\n"
			let firstBytes = makeStdoutBody(requestId: Int(requestId), data: [UInt8](statusLine.utf8) + b)
			write(bytes: firstBytes, completion: completion)
			
		} else if b.count > 0 {
			let furtherBytes = makeStdoutBody(requestId: Int(requestId), data: b)
			write(bytes: furtherBytes, completion: completion)
		}
	}
	
	func writeBody(bytes b: [UInt8], completion: (Bool) -> ()) {
		if !wroteHeader {
			header += "\r\n" // final CRLF
			writeHeader(bytes: [UInt8](header.utf8)) {
				ok in
				
				guard ok else {
					return completion(false)
				}
				
				self.header = ""				
				let b = self.makeStdoutBody(requestId: Int(self.requestId), data: b)
				self.write(bytes: b, completion: completion)
			}
		} else {
			let b = makeStdoutBody(requestId: Int(requestId), data: b)
			write(bytes: b, completion: completion)
		}
	}
	
	func write(bytes byts: [UInt8], completion: (Bool) -> ()) {
		self.connection.writeFully(bytes: byts)
	}
	
	func makeEndRequestBody(requestId rid: Int, appStatus: Int, protocolStatus: Int) -> [UInt8] {
		
		let b = Bytes()
		b.import8Bits(from: fcgiVersion1)
			.import8Bits(from: fcgiEndRequest)
			.import16Bits(from: htons(UInt16(rid)))
			.import16Bits(from: htons(UInt16(8)))
			.import8Bits(from: 0)
			.import8Bits(from: 0)
			.import32Bits(from: htonl(UInt32(appStatus)))
			.import8Bits(from: UInt8(protocolStatus))
			.import8Bits(from: 0)
			.import8Bits(from: 0)
			.import8Bits(from: 0)
		
		return b.data
	}
	
	func makeStdoutBody(requestId rid: Int, data: [UInt8], firstPos: Int, count: Int) -> [UInt8] {
		let b = Bytes()
		
		if count > fcgiBodyChunkSize {
			b.importBytes(from: makeStdoutBody(requestId: rid, data: data, firstPos: firstPos, count: fcgiBodyChunkSize))
			b.importBytes(from: makeStdoutBody(requestId: rid, data: data, firstPos: fcgiBodyChunkSize + firstPos, count: count - fcgiBodyChunkSize))
		} else {
			
			let padBytes = count % 8
			b.import8Bits(from: fcgiVersion1)
				.import8Bits(from: fcgiStdout)
				.import16Bits(from: htons(UInt16(rid)))
				.import16Bits(from: htons(UInt16(count)))
				.import8Bits(from: UInt8(padBytes))
				.import8Bits(from: 0)
			if firstPos == 0 && count == data.count {
				b.importBytes(from: data)
			} else {
				b.importBytes(from: data[firstPos..<count])
			}
			if padBytes > 0 {
				for _ in 1...padBytes {
					b.import8Bits(from: 0)
				}
			}
		}
		return b.data
	}
	
	func makeStdoutBody(requestId rid: Int, data: [UInt8]) -> [UInt8] {
		return makeStdoutBody(requestId: rid, data: data, firstPos: 0, count: data.count)
	}
	
	func readRecord(continuation: (FastCGIRecord?) -> ()) {
		self.connection.readBytesFully(count: fcgiBaseRecordSize, timeoutSeconds: fcgiTimeoutSeconds) {
            [weak self] (b: [UInt8]?) -> () in
			
			guard let recBytes = b else {
				continuation(nil)
				return
			}
		
			let record = FastCGIRecord()
			record.version = recBytes[0]
			record.recType = recBytes[1]
			record.requestId = ntohs((UInt16(recBytes[3]) << 8) | UInt16(recBytes[2]))
			record.contentLength = ntohs((UInt16(recBytes[5]) << 8) | UInt16(recBytes[4]))
			record.paddingLength = recBytes[6];
			record.reserved = recBytes[7]
			
			self?.readRecordContent(record: record, continuation: continuation)
		}
	}
	
	func readRecordContent(record rec: FastCGIRecord, continuation: (FastCGIRecord?) -> ()) {
		if rec.contentLength > 0 {
			
			self.connection.readBytesFully(count: Int(rec.contentLength), timeoutSeconds: fcgiTimeoutSeconds, completion: {
				[weak self] (b:[UInt8]?) -> () in
				if let contentBytes = b {
					
					rec.content = contentBytes
					self?.readRecordPadding(record: rec, continuation: continuation)
					
				} else {
					continuation(nil)
				}
			})
			
		} else {
			self.readRecordPadding(record: rec, continuation: continuation)
		}
	}
	
	func readRecordPadding(record rec: FastCGIRecord, continuation: (FastCGIRecord?) -> ()) {
		if rec.paddingLength > 0 {
			
			self.connection.readBytesFully(count: Int(rec.paddingLength), timeoutSeconds: fcgiTimeoutSeconds, completion: {
				(b:[UInt8]?) -> () in
				if let paddingBytes = b {
					
					rec.padding = paddingBytes
					continuation(rec)
					
				} else {
					continuation(nil)
				}
			})
			
		} else {
			continuation(rec)
		}
	}
}





