//
//  MessageHandler.swift
//
//  Copyright © 2024 Wang Lun.
//

/// An abstract message handler, such as a language server or client.
public protocol MessageHandler: AnyObject, Sendable {}
