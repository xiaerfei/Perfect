//
//  LogManager.swift
//  PerfectLib
//
//  Created by Kyle Jessup on 7/21/15.
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

/// Placeholder functions for logging system
public struct Log {
	
	static func info(message msg: String) {
		print(msg)
	}
	
	static func warning(message msg: String) {
		print(msg)
	}
	
	static func error(message msg: String) {
		print(msg)
	}
	
	static func critical(message msg: String) {
		print(msg)
	}
	@noreturn
	static func terminal(message msg: String) {
		fatalError(msg)		
	}
}