//
//  mqt2Publisher.swift
//  mqt2
//
//  Created by MARIANO ARSELAN on 05-05-26.
//

import Foundation
import Combine
import CocoaMQTT


public enum MQT2PublisherState {
    case connected
    case disconnected
    case subscribedToTopic(String)
    case received(String)
}

public enum MQT2PublisherError: Error {
    case cannotConnect(String, String, UInt16)
    case cannotSubscribeToTopic(String)
    case disconnected(Error?)
}

protocol MQT2PublisherProtocol {
    func connect(clientID: String, host: String, port: UInt16, keepAlive: UInt16)
    func disconnect()
    func publisher() -> AnyPublisher<MQT2PublisherState, MQT2PublisherError>
    func subscribe(to topic: String)
}

public class MQT2Publisher: MQT2PublisherProtocol {
    
    private let delegate: MQT2PublisherDelegate
    private var mqtt: CocoaMQTT?
    private var subject: PassthroughSubject<MQT2PublisherState, MQT2PublisherError>
    
    public init() {
        subject = PassthroughSubject()
        delegate = MQT2PublisherDelegate(subject: subject)
    }
    
    public func connect(clientID: String = UUID().uuidString, host: String = "localhost", port: UInt16 = 1883, keepAlive: UInt16 = 60) {
        mqtt = CocoaMQTT(clientID: clientID, host: host, port: port)
        mqtt?.keepAlive = keepAlive
        mqtt?.delegate = delegate
        if mqtt?.connect() == false {
            subject.send(completion: .failure(.cannotConnect(clientID, host, port)))
        }
    }
    
    public func disconnect() {
        mqtt?.disconnect()
        mqtt = nil
    }
    
    public func publisher() -> AnyPublisher<MQT2PublisherState, MQT2PublisherError> {
        subject.eraseToAnyPublisher()
    }
    
    public func subscribe(to topic: String) {
        mqtt?.subscribe(topic)
    }
    
}

fileprivate class MQT2PublisherDelegate: CocoaMQTTDelegate {
    
    private var subject: PassthroughSubject<MQT2PublisherState, MQT2PublisherError>
    
    init(subject: PassthroughSubject<MQT2PublisherState, MQT2PublisherError>) {
        self.subject = subject
    }
   
    func mqtt(_ mqtt: CocoaMQTT, didConnectAck ack: CocoaMQTTConnAck) {
        subject.send(.connected)
    }

    func mqtt(_ mqtt: CocoaMQTT, didPublishMessage message: CocoaMQTTMessage, id: UInt16) {
        
    }

    func mqtt(_ mqtt: CocoaMQTT, didPublishAck id: UInt16) {
        
    }

    func mqtt(_ mqtt: CocoaMQTT, didReceiveMessage message: CocoaMQTTMessage, id: UInt16 ) {
        if let s = message.string {
            subject.send(.received(s))
        }
    }

    func mqtt(_ mqtt: CocoaMQTT, didSubscribeTopics success: NSDictionary, failed: [String]) {
        for topic in success.allKeys {
            guard let topic = topic as? String else { continue }
            subject.send(.subscribedToTopic(topic))
        }
        for topic in failed {
            subject.send(completion: .failure(.cannotSubscribeToTopic(topic)))
        }
    }

    func mqtt(_ mqtt: CocoaMQTT, didUnsubscribeTopics topics: [String]) {
         
    }

    func mqttDidPing(_ mqtt: CocoaMQTT) {
        
    }

    func mqttDidReceivePong(_ mqtt: CocoaMQTT) {
        
    }

    func mqttDidDisconnect(_ mqtt: CocoaMQTT, withError err: Error?)
    {
        if let err {
            subject.send(completion: .failure(.disconnected(err)))
        } else {
            subject.send(completion: .finished)
        }
    }
}

