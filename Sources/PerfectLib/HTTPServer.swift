//
//  HTTPServer.swift
//  PerfectLib
//
//  Created by Kyle Jessup on 2015-10-23.
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

internal let httpReadSize = 1024
internal let httpReadTimeout = 5.0
internal let httpLF = UInt8(10)
internal let httpCR = UInt8(13)
internal let httpColon = UInt8(58)
internal let httpSpace = UnicodeScalar(32)
internal let httpQuestion = UnicodeScalar(63)

/// Stand-alone HTTP server. Provides the same WebConnection based interface as the FastCGI server.
public class HTTPServer {
	
	private var net: NetTCP?
	
	/// The directory in which web documents are sought.
	public let documentRoot: String
	/// The port on which the server is listening.
	public var serverPort: UInt16 = 0
	/// The local address on which the server is listening. The default of 0.0.0.0 indicates any local address.
	public var serverAddress = "0.0.0.0"
	
	/// The canonical server name.
	/// This is important if utilizing the `WebRequest.serverName` "SERVER_NAME" variable.
	public var serverName = ""
	
	/// Initialize the server with a document root.
	/// - parameter documentRoot: The document root for the server.
	public init(documentRoot: String) {
		self.documentRoot = documentRoot
	}
	
	/// Start the server on the indicated TCP port and optional address.
	/// - parameter port: The port on which to bind.
	/// - parameter bindAddress: The local address on which to bind.
	public func start(port prt: UInt16, bindAddress: String = "0.0.0.0") throws {
		
		self.serverPort = prt
		self.serverAddress = bindAddress
		
		let socket = NetTCP()
		socket.initSocket()
		try socket.bind(port: prt, address: bindAddress)
		
		print("Starting HTTP server on \(bindAddress):\(prt) with document root \(self.documentRoot)")
		
		try self.startInner(socket: socket)
	}
	
	/// Start the server on the indicated TCP port and optional address.
	/// - parameter port: The port on which to bind.
	/// - parameter sslCert: The server SSL certificate file.
	/// - parameter sslKey: The server SSL key file.
	/// - parameter bindAddress: The local address on which to bind.
	public func start(port prt: UInt16, sslCert: String, sslKey: String, dhParams: String? = nil, bindAddress: String = "0.0.0.0") throws {
		
		self.serverPort = prt
		self.serverAddress = bindAddress
		
		let socket = NetTCPSSL()
		socket.initSocket()
		
		let cipherList = [
			"ECDHE-ECDSA-AES256-GCM-SHA384",
			"ECDHE-ECDSA-AES128-GCM-SHA256",
			"ECDHE-ECDSA-AES256-CBC-SHA384",
			"ECDHE-ECDSA-AES256-CBC-SHA",
			"ECDHE-ECDSA-AES128-CBC-SHA256",
			"ECDHE-ECDSA-AES128-CBC-SHA",
			"ECDHE-RSA-AES256-GCM-SHA384",
			"ECDHE-RSA-AES128-GCM-SHA256",
			"ECDHE-RSA-AES256-CBC-SHA384",
			"ECDHE-RSA-AES128-CBC-SHA256",
			"ECDHE-RSA-AES128-CBC-SHA",
			
			"ECDHE-RSA-AES256-SHA384",
			"ECDHE-ECDSA-AES256-SHA384",
			"ECDHE-RSA-AES256-SHA",
			"ECDHE-ECDSA-AES256-SHA"
			/*,
			"SRP-DSS-AES-256-CBC-SHA",
			"SRP-RSA-AES-256-CBC-SHA",
			"SRP-AES-256-CBC-SHA",
			"DH-DSS-AES256-GCM-SHA384",
			"DHE-DSS-AES256-GCM-SHA384",
			"DH-RSA-AES256-GCM-SHA384",
			"DHE-RSA-AES256-GCM-SHA384",
			"DHE-RSA-AES256-SHA256",
			"DHE-DSS-AES256-SHA256",
			"DH-RSA-AES256-SHA256",
			"DH-DSS-AES256-SHA256",
			"DHE-RSA-AES256-SHA",
			"DHE-DSS-AES256-SHA",
			"DH-RSA-AES256-SHA",
			"DH-DSS-AES256-SHA",
			"DHE-RSA-CAMELLIA256-SHA",
			"DHE-DSS-CAMELLIA256-SHA",
			"DH-RSA-CAMELLIA256-SHA",
			"DH-DSS-CAMELLIA256-SHA",
			"ECDH-RSA-AES256-GCM-SHA384",
			"ECDH-ECDSA-AES256-GCM-SHA384",
			"ECDH-RSA-AES256-SHA384",
			"ECDH-ECDSA-AES256-SHA384",
			"ECDH-RSA-AES256-SHA",
			"ECDH-ECDSA-AES256-SHA",
			"AES256-GCM-SHA384",
			"AES256-SHA256",
			"AES256-SHA",
			"CAMELLIA256-SHA",
			"PSK-AES256-CBC-SHA",
			"ECDHE-RSA-AES128-SHA256",
			"ECDHE-ECDSA-AES128-SHA256",
			"ECDHE-RSA-AES128-SHA",
			"ECDHE-ECDSA-AES128-SHA",
			"SRP-DSS-AES-128-CBC-SHA",
			"SRP-RSA-AES-128-CBC-SHA",
			"SRP-AES-128-CBC-SHA",
			"DH-DSS-AES128-GCM-SHA256",
			"DHE-DSS-AES128-GCM-SHA256",
			"DH-RSA-AES128-GCM-SHA256",
			"DHE-RSA-AES128-GCM-SHA256",
			"DHE-RSA-AES128-SHA256",
			"DHE-DSS-AES128-SHA256",
			"DH-RSA-AES128-SHA256",
			"DH-DSS-AES128-SHA256",
			"DHE-RSA-AES128-SHA",
			"DHE-DSS-AES128-SHA",
			"DH-RSA-AES128-SHA",
			"DH-DSS-AES128-SHA",
			"DHE-RSA-SEED-SHA",
			"DHE-DSS-SEED-SHA",
			"DH-RSA-SEED-SHA",
			"DH-DSS-SEED-SHA",
			"DHE-RSA-CAMELLIA128-SHA",
			"DHE-DSS-CAMELLIA128-SHA",
			"DH-RSA-CAMELLIA128-SHA",
			"DH-DSS-CAMELLIA128-SHA",
			"ECDH-RSA-AES128-GCM-SHA256",
			"ECDH-ECDSA-AES128-GCM-SHA256",
			"ECDH-RSA-AES128-SHA256",
			"ECDH-ECDSA-AES128-SHA256",
			"ECDH-RSA-AES128-SHA",
			"ECDH-ECDSA-AES128-SHA",
			"AES128-GCM-SHA256",
			"AES128-SHA256",
			"AES128-SHA",
			"SEED-SHA",
			"CAMELLIA128-SHA",
			"IDEA-CBC-SHA",
			"PSK-AES128-CBC-SHA",
			"ECDHE-RSA-RC4-SHA",
			"ECDHE-ECDSA-RC4-SHA",
			"ECDH-RSA-RC4-SHA",
			"ECDH-ECDSA-RC4-SHA",
			"RC4-SHA",
			"RC4-MD5",
			"PSK-RC4-SHA",
			"ECDHE-RSA-DES-CBC3-SHA",
			"ECDHE-ECDSA-DES-CBC3-SHA",
			"SRP-DSS-3DES-EDE-CBC-SHA",
			"SRP-RSA-3DES-EDE-CBC-SHA",
			"SRP-3DES-EDE-CBC-SHA",
			"EDH-RSA-DES-CBC3-SHA",
			"EDH-DSS-DES-CBC3-SHA",
			"DH-RSA-DES-CBC3-SHA",
			"DH-DSS-DES-CBC3-SHA",
			"ECDH-RSA-DES-CBC3-SHA",
			"ECDH-ECDSA-DES-CBC3-SHA",
			"DES-CBC3-SHA",
			"PSK-3DES-EDE-CBC-SHA",
			"EDH-RSA-DES-CBC-SHA",
			"EDH-DSS-DES-CBC-SHA",
			"DH-RSA-DES-CBC-SHA",
			"DH-DSS-DES-CBC-SHA",
			"DES-CBC-SHA"
			*/
		]
		
		socket.cipherList = cipherList
		
		guard socket.useCertificateChainFile(cert: sslCert) else {
			let code = Int32(socket.errorCode())
			throw PerfectError.NetworkError(code, "Error setting certificate chain file: \(socket.errorStr(forCode: code))")
		}
		
		guard socket.usePrivateKeyFile(cert: sslKey) else {
			let code = Int32(socket.errorCode())
			throw PerfectError.NetworkError(code, "Error setting private key file: \(socket.errorStr(forCode: code))")
		}
		
		guard socket.checkPrivateKey() else {
			let code = Int32(socket.errorCode())
			throw PerfectError.NetworkError(code, "Error validating private key file: \(socket.errorStr(forCode: code))")
		}
		
		try socket.bind(port: prt, address: bindAddress)

		print("Starting HTTPS server on \(bindAddress):\(prt) with document root \(self.documentRoot)")
		
		try self.startInner(socket: socket)
	}
	
	private func startInner(socket sock: NetTCP) throws {
		sock.listen()
		self.net = sock
		defer { sock.close() }
		self.start()
	}
	
	func start() {
		
		if let n = self.net {
			
			self.serverAddress = n.sockName().0
			
			n.forEachAccept {
				[weak self] (net: NetTCP?) -> () in
				
				if let n = net {
					Threading.dispatch {
						self?.handleConnection(net: n)
					}
				}
			}
		}
	}
	
	/// Stop the server by closing the accepting TCP socket. Calling this will cause the server to break out of the otherwise blocking `start` function.
	public func stop() {
		if let n = self.net {
			self.net = nil
			n.close()
		}
	}
	
	func handleConnection(net nt: NetTCP) {
		let req = HTTPWebConnection(net: nt, server: self)
		req.readRequest { requestOk in
			if requestOk {
				self.runRequest(req)
			} else {
				req.connection.close()
			}
		}
	}
	
	// returns true if the request pointed to a file which existed
	// and the request was properly handled
	func run(request req: HTTPWebConnection, withPathInfo: String, completion: (Bool) -> ()) {
		
		req.requestParams["PATH_INFO"] = withPathInfo
			
		let request = WebRequest(req)
		let response = WebResponse(req, request: request)
		return response.respond() {
			return completion(true)
		}
	}
	
	func runRequest(_ req: HTTPWebConnection) {
		guard let pathInfo = req.requestParams["PATH_INFO"] else {
			
			req.setStatus(code: 500, message: "INVALID")
			return req.pushHeaderBytes {
				_ in
				
				req.connection.close()
			}
		}
		
		req.requestParams["PERFECTSERVER_DOCUMENT_ROOT"] = self.documentRoot
		
		self.run(request: req, withPathInfo: pathInfo) {
			b in
			if !b {
				req.setStatus(code: 404, message: "NOT FOUND")
				let msg = "The file \"\(pathInfo)\" was not found.".utf8
				req.writeHeader(line: "Content-length: \(msg.count)")
				req.writeBody(bytes: [UInt8](msg)) {
					ok in
					
					guard ok else {
						req.connection.close()
						return
					}
					
					self.keepAliveOrClose(request: req)
				}
			} else {
				self.keepAliveOrClose(request: req)
			}
		}
	}
	
	func keepAliveOrClose(request req: HTTPWebConnection) {
		if req.httpKeepAlive {
			self.handleConnection(net: req.connection)
		} else {
			req.connection.close()
		}
	}
	
	final class HTTPWebConnection : WebConnection {
		
		typealias OkCallback = (Bool) -> ()
		
		var connection: NetTCP
		var requestParams = [String:String]()
		var stdin: [UInt8]? = nil
		var mimes: MimeReader? = nil
		
		var statusCode: Int
		var statusMsg: String
		
		var header: String = ""
		var wroteHeader: Bool = false
		
		var workingBuffer = [UInt8]()
		var workingBufferOffset = 0
		var lastHeaderKey = "" // for handling continuations
		
		let serverName: String
		let serverAddr: String
		let serverPort: UInt16
		
		var contentType: String? {
			return self.requestParams["CONTENT_TYPE"]
		}
		
		var httpOneOne: Bool {
			return (self.requestParams["SERVER_PROTOCOL"] ?? "").contains(string: "1.1")
		}
		
		var httpVersion: String {
			return self.requestParams["SERVER_PROTOCOL"] ?? "HTTP/1.0"
		}
		
		var httpKeepAlive: Bool {
			return (self.requestParams["HTTP_CONNECTION"] ?? "").lowercased().contains(string: "keep-alive")
		}
		
		init(net: NetTCP, server: HTTPServer) {
			self.connection = net
			self.statusCode = 200
			self.statusMsg = "OK"
			self.serverName = server.serverName
			self.serverAddr = server.serverAddress
			self.serverPort = server.serverPort
		}
		
		func setStatus(code cod: Int, message msg: String) {
			self.statusCode = cod
			self.statusMsg = msg
		}
		
		func getStatus() -> (Int, String) {
			return (self.statusCode, self.statusMsg)
		}
		
		func transformHeaderName(_ name: String) -> String {
			switch name {
			case "Host":
				return "HTTP_HOST"
			case "Connection":
				return "HTTP_CONNECTION"
			case "Keep-Alive":
				return "HTTP_KEEP_ALIVE"
			case "User-Agent":
				return "HTTP_USER_AGENT"
			case "Referer", "Referrer":
				return "HTTP_REFERER"
			case "Accept":
				return "HTTP_ACCEPT"
			case "Content-Length":
				return "CONTENT_LENGTH"
			case "Content-Type":
				return "CONTENT_TYPE"
			case "Cookie":
				return "HTTP_COOKIE"
			case "Accept-Language":
				return "HTTP_ACCEPT_LANGUAGE"
			case "Accept-Encoding":
				return "HTTP_ACCEPT_ENCODING"
			case "Accept-Charset":
				return "HTTP_ACCEPT_CHARSET"
			case "Authorization":
				return "HTTP_AUTHORIZATION"
			default:
				return "HTTP_" + name.uppercased().stringByReplacing(string: "-", withString: "_")
			}
		}
		
		func readRequest(callback: OkCallback) {
			
			self.readHeaders { requestOk in
				if requestOk {
					
					self.readBody(callback: callback)
					
				} else {
					callback(false)
				}
			}
		}
		
		func readHeaders(_ callback: OkCallback) {
			self.connection.readSomeBytes(count: httpReadSize) {
				(b:[UInt8]?) in
				self.didReadHeaderData(b, callback: callback)
			}
		}
		
		func readBody(callback callbck: OkCallback) {
			guard let cl = self.requestParams["CONTENT_LENGTH"] where Int(cl) > 0 else {
				callbck(true)
				return
			}
			
			let workingDiff = self.workingBuffer.count - self.workingBufferOffset
			if workingDiff > 0 {
				// data remaining in working buffer
				self.putStdinData(Array(self.workingBuffer.suffix(workingDiff)))
			}
			self.workingBuffer.removeAll()
			self.workingBufferOffset = 0
			self.readBody(count: (Int(cl) ?? 0) - workingDiff, callback: callbck)
		}
		
		func readBody(count size: Int, callback: OkCallback) {
			guard size > 0 else {
				callback(true)
				return
			}
			self.connection.readSomeBytes(count: size) {
				[weak self] (b:[UInt8]?) in
				
				if b == nil || b!.count == 0 {
					self?.connection.readBytesFully(count: 1, timeoutSeconds: httpReadTimeout) {
						(b:[UInt8]?) in
						
						guard b != nil else {
							callback(false)
							return
						}
						
						self?.putStdinData(b!)
						self?.readBody(count: size - 1, callback: callback)
					}
				} else {
					self?.putStdinData(b!)
					self?.readBody(count: size - b!.count, callback: callback)
				}
			}
		}
		
		func processRequestLine(_ h: ArraySlice<UInt8>) -> Bool {
			let lineStr = UTF8Encoding.encode(bytes: h)
			var method = "", uri = "", pathInfo = "", queryString = "", hvers = ""
			
			var gen = lineStr.unicodeScalars.makeIterator()
			
			// METHOD PATH_INFO[?QUERY] HVERS
			while let c = gen.next() {
				if httpSpace == c {
					break
				}
				method.append(c)
			}
			var gotQuest = false
			while let c = gen.next() {
				if httpSpace == c {
					break
				}
				if gotQuest {
					queryString.append(c)
				} else if httpQuestion == c {
					gotQuest = true
				} else {
					pathInfo.append(c)
				}
				uri.append(c)
			}
			while let c = gen.next() {
				hvers.append(c)
			}
			
			self.requestParams["REQUEST_METHOD"] = method
			self.requestParams["REQUEST_URI"] = uri
			self.requestParams["PATH_INFO"] = pathInfo
			self.requestParams["QUERY_STRING"] = queryString
			self.requestParams["SERVER_PROTOCOL"] = hvers
			self.requestParams["GATEWAY_INTERFACE"] = "PerfectHTTPD"
			
			let (remoteHost, remotePort) = self.connection.peerName()
			
			self.requestParams["REMOTE_ADDR"] = remoteHost
			self.requestParams["REMOTE_PORT"] = "\(remotePort)"
			
			self.requestParams["SERVER_NAME"] = self.serverName
			self.requestParams["SERVER_ADDR"] = self.serverAddr
			self.requestParams["SERVER_PORT"] = "\(self.serverPort)"
			return true
		}
		
		func processHeaderLine(_ h: ArraySlice<UInt8>) -> Bool {
			for i in h.startIndex..<h.endIndex {
				if httpColon == h[i] {
					let headerKey = transformHeaderName(UTF8Encoding.encode(bytes: h[h.startIndex..<i]))
					var i2 = i + 1
					while i2 < h.endIndex {
						if !UnicodeScalar(h[i2]).isWhiteSpace() {
							break
						}
						i2 += 1
					}
					let headerValue = UTF8Encoding.encode(bytes: h[i2..<h.endIndex])
					self.requestParams[headerKey] = headerValue
					self.lastHeaderKey = headerKey
					return true
				}
			}
			return false
		}
		
		func processHeaderContinuation(_ h: ArraySlice<UInt8>) -> Bool {
			guard !self.lastHeaderKey.isEmpty else {
				return false
			}
			guard let found = self.requestParams[self.lastHeaderKey] else {
				return false
			}
			for i in 0..<h.count {
				if !UnicodeScalar(h[i]).isWhiteSpace() {
					let extens = UTF8Encoding.encode(bytes: h[i..<h.count])
					self.requestParams[self.lastHeaderKey] = found + " " + extens
					return true
				}
			}
			return false
		}
		
		func scanWorkingBuffer(_ callback: OkCallback) {
			// data was just added to workingBuffer
			// look for header end or possible end of headers
			// handle case of buffer break in between CR-LF pair. first new byte will be LF. skip it
			if self.workingBuffer[self.workingBufferOffset] == httpLF {
				self.workingBufferOffset += 1
			}
			var lastWasCr = false
			var startingOffset = self.workingBufferOffset
			for i in startingOffset..<self.workingBuffer.count {
				
				let c = self.workingBuffer[i]
				
				guard false == lastWasCr || httpLF == c else { // malformed header
					callback(false)
					return
				}
				
				if lastWasCr { // and c is LF
					lastWasCr = false
					// got a header or possibly end of headers
					let segment = self.workingBuffer[startingOffset ..< (i-1)]
					// if segment is empty then it's the end of headers
					// if segment begins with a space then it's a continuation of the previous header
					// otherwise it's a new header
					
					let first = self.workingBufferOffset == 0
					
					startingOffset = i + 1
					self.workingBufferOffset = startingOffset
					
					if segment.count == 0 {
						callback(true)
						return
					} else if UnicodeScalar(segment.first!).isWhiteSpace() {
						if !self.processHeaderContinuation(segment) {
							callback(false)
							return
						}
					} else if first {
						if !self.processRequestLine(segment) {
							callback(false)
							return
						}
					} else {
						if !self.processHeaderLine(segment) {
							callback(false)
							return
						}
					}
				} else {
					lastWasCr = c == httpCR
				}
			}
			// not done yet
			self.readHeaders(callback)
		}
		
		func didReadHeaderData(_ b:[UInt8]?, callback: OkCallback) {
			guard b != nil else {
				callback(false)
				return
			}
			if b!.count == 0 { // no data was available for immediate consumption. try reading with timeout
				self.connection.readBytesFully(count: 1, timeoutSeconds: httpReadTimeout) {
					(b2:[UInt8]?) in
					
					if b2 == nil { // timeout. request dead
						callback(false)
					} else {
						self.didReadHeaderData(b2, callback: callback)
					}
				}
			} else {
				self.workingBuffer.append(contentsOf: b!)
				self.scanWorkingBuffer(callback)
			}
		}
		
		func putStdinData(_ b: [UInt8]) {
			if self.stdin == nil && self.mimes == nil {
				let contentType = self.contentType
				if contentType == nil || !contentType!.begins(with: "multipart/form-data") {
					self.stdin = b
				} else {
					self.mimes = MimeReader(contentType!)
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
		
		func writeHeader(bytes b: [UInt8], completion: OkCallback) {
			if !wroteHeader {
				wroteHeader = true
				
				let statusLine = "\(self.httpVersion) \(statusCode) \(statusMsg)\r\n"
				let firstBytes = [UInt8](statusLine.utf8)
				
//				print("header \(UTF8Encoding.encode(bytes: firstBytes))")
				
				write(bytes: firstBytes) {
					ok in
					
					guard ok else {
						return completion(false)
					}
					
//					print("header \(UTF8Encoding.encode(bytes: b))")
					
					self.write(bytes: b, completion: completion)
				}
			} else {
				completion(true)
			}
		}
		
		func pushHeaderBytes(completion: OkCallback) {
			if !wroteHeader {
				if self.httpKeepAlive {
					header += "Connection: keep-alive\r\nKeep-Alive: timeout=\(Int(httpReadTimeout)), max=100\r\n\r\n" // final CRLF
				} else {
					header += "\r\n" // final CRLF
				}
				writeHeader(bytes: [UInt8](header.utf8)) {
					ok in
					
					self.header = ""
					completion(ok)
				}
			} else {
				completion(true)
			}
		}
		
		func writeBody(bytes b: [UInt8], completion: OkCallback) {
			pushHeaderBytes {
				ok in
				
				guard ok else {
					return completion(false)
				}
				
				self.write(bytes: b, completion: completion)
			}
		}
		
		func write(bytes b: [UInt8], completion: OkCallback) {
		
			self.connection.write(bytes: b) {
				writeCount in
				
				completion(writeCount == b.count)
			}
		}
		
	}
}

