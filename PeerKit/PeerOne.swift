//
//  PeerOne.swift
//  PeerKit
//
//  Created by Jason Jobe on 1/5/17.
//  Copyright © 2017 Jason Jobe. All rights reserved.
//

import Foundation
import MultipeerConnectivity

extension NSObject {

    func trace (_ msg: String? = nil, method: String = #function) {
        Swift.print (method, msg ??  "")
    }
}

@objc
public protocol PeerOneDelegate {
    @objc optional func connecting (peerOne: PeerOne, to peer: MCPeerID)
    @objc optional func connected (peerOne: PeerOne, to peer: MCPeerID)
    @objc optional func disconnected(peerOne: PeerOne, from peer: MCPeerID)
    @objc optional func received (peerOne: PeerOne, data: Data, from peer: MCPeerID)
    @objc optional func received (peerOne: PeerOne, object: Any, from peer: MCPeerID)
    @objc optional func received (peerOne: PeerOne, resourceName: String, from peer: MCPeerID, at: URL)
}

public class PeerOne: NSObject, MCSessionDelegate {

    public enum State {
        case inactive, searching, connected, disconnected
    }
    
    public struct Mode: OptionSet {
        public let rawValue: Int
        
        public init(rawValue: Int) {
            self.rawValue = rawValue
        }
        public static let client  = Mode(rawValue: 1 << 0)
        public static let server  = Mode(rawValue: 1 << 1)
        public static let peer: Mode = [.client, .server]
        public static let all: Mode = [.client, .server]
    }
//    public enum Mode {
//        case client, server, peer
//    }

    public private(set) var myPeerID: MCPeerID
    var peers: [MCPeerID]?  // We maintain our own list to faciliate reconnects

    public var delegate: PeerOneDelegate?
    public private(set) var service: String
    
    
    var advertiser: MCNearbyServiceAdvertiser?
    var browser: MCNearbyServiceBrowser?
    
    // This insures we create a session on demand
    var _session: MCSession?
    var session: MCSession? {
        if _session == nil {
            _session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .optional)
            _session?.delegate = self
        }
        return _session
    }
    
    public init(displayName: String, service: String, mode: Mode, delegate: PeerOneDelegate? = nil)
    {
        myPeerID = MCPeerID(displayName: displayName)
        self.service = service
        self.delegate = delegate
        self.mode = mode
    }
    
    deinit {
        state = .inactive
    }
    
//    public var mode: Mode {
//        willSet {
//            state = .inactive
//        }
//        didSet {
//            state = .searching
//        }
//    }
    
    public private (set) var mode: Mode
    
    public var state: State = .inactive {
        
        didSet {
            switch state {
                
            case .searching:
                if mode.contains(.server) { startAdvertising(serviceType: service) }
                if mode.contains(.client) { startBrowsing(serviceType: service) }
                
            case .connected:
                self.stopAdvertising()
                
            case .disconnected:
                _session?.delegate = nil
                _session?.disconnect()
                _session = nil
                if mode.contains(.server) { startAdvertising(serviceType: service) }
                
            case .inactive:
                self.stopBrowsing()
                self.stopAdvertising()
                
                self.delegate = nil
                _session?.delegate = nil
                _session?.disconnect()
                _session = nil
            }
        }
    }
/*
    public func activate (mode: State = .both) {
        self.state = mode
        
        switch mode {

        case .advertise:
            startAdvertising(serviceType: service)
            
        case .browse:
            startBrowsing(serviceType: service)
            
        case .both:
            startAdvertising(serviceType: service)
            startBrowsing(serviceType: service)
            
        case .inactive:
            self.stopBrowsing()
            self.stopAdvertising()
            
            self.delegate = nil
            session.delegate = nil
            session.disconnect()
        }
    }
    
    public func deactivate ()
    {
        self.stopBrowsing()
        self.stopAdvertising()
        
        self.delegate = nil
        session.delegate = nil
        session.disconnect()
        state = .inactive
    }
    */
    public func send (event: String, mode: MCSessionSendDataMode = .reliable, object: AnyObject? = nil, to peers: [MCPeerID]? = nil) {
        
        guard let peers = peers ?? session?.connectedPeers else { return }
        guard !peers.isEmpty else { return }
        
        var rootObject: [String: AnyObject] = ["event": event as AnyObject]
        
        if let object: AnyObject = object {
            rootObject["object"] = object
        }
        
        let data = NSKeyedArchiver.archivedData(withRootObject: rootObject)
        try? session?.send(data, toPeers: peers, with: mode)
    }
    
    public func send (resource: URL,
                      named resourceName: String,
                      to peers: [MCPeerID]? = nil,
                      complete handler: ((Error?) -> Void)?) -> [Progress?]? {
        
        guard let peers = peers ?? session?.connectedPeers else { return nil }

        return peers.map { peerID in
            return session?.sendResource(at: resource, withName: resourceName, toPeer: peerID,
                                        withCompletionHandler: handler)
        }
    }

    // MARK: MCSessionDelegate
    
    public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        
        trace()
        
        switch state {
        case .connecting:
            delegate?.connecting?(peerOne: self, to: peerID)
        case .connected:
            delegate?.connected?(peerOne: self, to: peerID)
        case .notConnected:
            delegate?.disconnected?(peerOne: self, from: peerID)
            self._session = nil
        }
    }
    
    public func session(_ session: MCSession, didReceiveCertificate certificate: [Any]?, fromPeer peerID: MCPeerID, certificateHandler: @escaping (Bool) -> Swift.Void) {
        trace()
        certificateHandler(true)
    }

    public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        trace()
        delegate?.received?(peerOne: self, data: data, from: peerID)
        
//        if delegate?.responds
        if true {
            if let dict = NSKeyedUnarchiver.unarchiveObject(with: data) as? [String: AnyObject],
                let event = dict["event"] as? String,
                let object = dict["object"] {
                delegate?.received?(peerOne: self, object: object, from: peerID)

//                DispatchQueue.main.async {
//                    if let onEvent = self.onEvent {
//                        onEvent(peer, event, object)
//                    }
//                    if let eventBlock = self.eventBlocks[event] {
//                        eventBlock(peer, object)
//                    }
//                }
            }
        }
    }
    
    public func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        trace()
        // unused
    }
    
    public func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        trace()
        // unused
    }
    
    public func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL, withError error: Error?) {
        trace()
        if (error == nil) {
            delegate?.received?(peerOne: self, resourceName: resourceName, from: peerID, at: localURL)
        }
    }
}

extension PeerOne: MCNearbyServiceBrowserDelegate {

    func startBrowsing(serviceType: String) {
//        guard let session = session else { return }
        guard browser == nil else { return }

        trace()
        browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
    }
    
    func stopBrowsing() {
        trace()
        browser?.delegate = nil
        browser?.stopBrowsingForPeers()
    }
    
    public func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        trace()
        guard let session = session else { return }
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
    }
    
    public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        trace()
        // unused
    }
}

extension PeerOne: MCNearbyServiceAdvertiserDelegate {

    func startAdvertising(serviceType: String, discoveryInfo: [String: String]? = nil) {
//        guard let session = session else { return }
        guard advertiser == nil else { return }
        trace()

        advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: discoveryInfo, serviceType: serviceType)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
    }
    
    func stopAdvertising() {
        trace()
        advertiser?.delegate = nil
        advertiser?.stopAdvertisingPeer()
    }
    
    public func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        trace()
        guard let session = session else { return }
        let accept = session.myPeerID.hashValue > peerID.hashValue
        invitationHandler(accept, session)
        if accept {
            state = .connected
        }
    }
}
