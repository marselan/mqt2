//
//  MQTTManager.swift
//  Movies
//
//  Created by MARIANO ARSELAN on 01-05-26.
//

import CocoaMQTT
import Foundation
import Combine

fileprivate class Continuations {
    var connectContinuation: CheckedContinuation<Void, any Error>?
    var subscribeContinuation: CheckedContinuation<Void, any Error>?
    var continuation: CheckedContinuation<String?, any Error>?
}

public enum MQTTError: Error {
    case unknown
    case cannotConnect
    case cannotSubscribe
}

public protocol MQT2AsyncProtocol {
    func connect(clientID: String, host: String, port: UInt16, keepAlive: UInt16) async throws
    func disconnect()
    func subscribe(to topic: String) async throws
    func sequence() -> AsyncThrowingStream<String?, any Error>
    func publishMessage(_ message: String)
}

public class MQT2Async: MQT2AsyncProtocol {
    
    private let delegate: MQTTManagerDelegateForAsync
    private var mqtt: CocoaMQTT?
    private let continuations: Continuations
    
    public init() {
        continuations = Continuations()
        delegate = MQTTManagerDelegateForAsync(continuations: continuations)
    }

    public func connect(clientID: String = UUID().uuidString, host: String = "localhost", port: UInt16 = 1883, keepAlive: UInt16 = 60) async throws {
        return try await withCheckedThrowingContinuation { [weak self] continuation in
            guard let self else { return }
            continuations.connectContinuation = continuation
            mqtt = CocoaMQTT(clientID: clientID, host: host, port: port)
            mqtt?.keepAlive = keepAlive
            mqtt?.delegate = delegate
            if mqtt?.connect() == false {
                continuations.connectContinuation?.resume(throwing: MQTTError.cannotConnect)
                continuations.connectContinuation = nil
            }
        }
    }
    
    public func disconnect() {
        mqtt?.disconnect()
        mqtt = nil
    }
    
    public func subscribe(to topic: String) async throws {
        return try await withCheckedThrowingContinuation { [weak self] continuation in
            self?.continuations.subscribeContinuation = continuation
            self?.mqtt?.subscribe(topic)
        }
    }
    
    public func sequence() -> AsyncThrowingStream<String?, any Error> {
        AsyncThrowingStream<String?, any Error> { continuation in
            Task.detached { [weak self] in
                do {
                    while true {
                        guard let self else {
                            continuation.finish()
                            return
                        }
                        if let s = try await self.listen() {
                            continuation.yield(s)
                        } else {
                            continuation.finish()
                            return
                        }
                    }
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    public func publishMessage(_ message: String) {
        mqtt?.publish("mariano/counter", withString: message)
    }
    
    private func listen() async throws -> String? {
        return try await withCheckedThrowingContinuation { [weak self] continuation in
            self?.continuations.continuation = continuation
        }
    }
}

extension MQT2Async: @unchecked Sendable {}

fileprivate class MQTTManagerDelegateForAsync: CocoaMQTTDelegate {
    
    private var continuations: Continuations
    
    init(continuations: Continuations) {
        self.continuations = continuations
    }
    
    deinit {
        continuations.connectContinuation?.resume(throwing: MQTTError.unknown)
        continuations.connectContinuation = nil
        continuations.subscribeContinuation?.resume(throwing: MQTTError.unknown)
        continuations.subscribeContinuation = nil
        continuations.continuation?.resume(returning: nil)
        continuations.continuation = nil
    }
   
    func mqtt(_ mqtt: CocoaMQTT, didConnectAck ack: CocoaMQTTConnAck) {
        print("MQTT Connected")
        continuations.connectContinuation?.resume()
    }

    ///
    func mqtt(_ mqtt: CocoaMQTT, didPublishMessage message: CocoaMQTTMessage, id: UInt16) {
        
    }

    ///
    func mqtt(_ mqtt: CocoaMQTT, didPublishAck id: UInt16) {
        
    }

    ///
    func mqtt(_ mqtt: CocoaMQTT, didReceiveMessage message: CocoaMQTTMessage, id: UInt16 ) {
        if let s = message.string {
            continuations.continuation?.resume(returning: s)
        }
    }

    ///
    func mqtt(_ mqtt: CocoaMQTT, didSubscribeTopics success: NSDictionary, failed: [String]) {
        if success.allValues.count > 0 {
            continuations.subscribeContinuation?.resume()
            print("MQTT Subscribed")
        } else {
            continuations.subscribeContinuation?.resume(throwing: MQTTError.cannotSubscribe)
        }
        continuations.subscribeContinuation = nil
    }

    ///
    func mqtt(_ mqtt: CocoaMQTT, didUnsubscribeTopics topics: [String]) {
         
    }

    ///
    func mqttDidPing(_ mqtt: CocoaMQTT) {
        
    }

    ///
    func mqttDidReceivePong(_ mqtt: CocoaMQTT) {
        
    }

    ///
    func mqttDidDisconnect(_ mqtt: CocoaMQTT, withError err: Error?)
    {
        if let err {
            continuations.continuation?.resume(throwing: err)
        } else {
            continuations.continuation?.resume(returning: nil)
        }
    }
}
