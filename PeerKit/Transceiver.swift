//
//  Transceiver.swift
//  CardsAgainst
//
//  Created by JP Simard on 11/3/14.
//  Copyright (c) 2014 JP Simard. All rights reserved.
//

import Foundation
import MultipeerConnectivity

enum TransceiverMode {
    case Browse, Advertise, Both
}

public class Transceiver: SessionDelegate {

    public var onConnecting: PeerBlock?
    public var onConnect: PeerBlock?
    public var onDisconnect: PeerBlock?
    public var onEvent: EventBlock?
    public var onEventObject: ObjectBlock?
    public var onFinishReceivingResource: ResourceBlock?
    public var eventBlocks = [String: ObjectBlock]()

    var transceiverMode = TransceiverMode.Both
    let session: Session
    let advertiser: Advertiser
    let browser: Browser

    public init(displayName: String!) {
        session = Session(displayName: displayName, delegate: nil)
        advertiser = Advertiser(mcSession: session.mcSession)
        browser = Browser(mcSession: session.mcSession)
        session.delegate = self
    }

    func startTransceiving(serviceType: String, discoveryInfo: [String: String]? = nil) {
        advertiser.startAdvertising(serviceType: serviceType, discoveryInfo: discoveryInfo)
        browser.startBrowsing(serviceType: serviceType)
        transceiverMode = .Both
    }

    func stopTransceiving() {
        session.delegate = nil
        advertiser.stopAdvertising()
        browser.stopBrowsing()
        session.disconnect()
    }

    func startAdvertising(serviceType: String, discoveryInfo: [String: String]? = nil) {
        advertiser.startAdvertising(serviceType: serviceType, discoveryInfo: discoveryInfo)
        transceiverMode = .Advertise
    }

    func startBrowsing(serviceType: String) {
        browser.startBrowsing(serviceType: serviceType)
        transceiverMode = .Browse
    }

    public func connecting(myPeerID: MCPeerID, toPeer peer: MCPeerID) {
        onConnecting?(myPeerID, peer)
    }

    public func connected(myPeerID: MCPeerID, toPeer peer: MCPeerID) {
        onConnect?(myPeerID, peer)
    }

    public func disconnected(myPeerID: MCPeerID, fromPeer peer: MCPeerID) {
        onDisconnect?(myPeerID, peer)
    }

    public func sendEvent(_ event: String, object: AnyObject? = nil, toPeers peers: [MCPeerID]? = nil) {
        
        let peers = peers ?? session.mcSession.connectedPeers
        guard !peers.isEmpty else { return }
        
        var rootObject: [String: AnyObject] = ["event": event as AnyObject]
        
        if let object: AnyObject = object {
            rootObject["object"] = object
        }
        
        let data = NSKeyedArchiver.archivedData(withRootObject: rootObject)
        
        do {
            try session.mcSession.send(data, toPeers: peers, with: .reliable)
        } catch _ {
        }
    }
    
    public func sendResourceAtURL(_ resourceURL: URL,
                                  withName resourceName: String,
                                  toPeers peers: [MCPeerID]? = nil,
                                  withCompletionHandler completionHandler: ((Error?) -> Void)?) -> [Progress?]? {
        
        let peers = peers ?? session.mcSession.connectedPeers
//        if let session = session {
            return peers.map { peerID in
                return session.mcSession.sendResource(at: resourceURL, withName: resourceName, toPeer: peerID, withCompletionHandler: completionHandler)
//            }
        }
        return nil
    }

    public func receivedData(myPeerID: MCPeerID, data: Data, fromPeer peer: MCPeerID) {
//        onEventObject?(data, peer)
    }

    public func finishReceivingResource(myPeerID: MCPeerID, resourceName: String, fromPeer peer: MCPeerID, atURL localURL: URL) {
        onFinishReceivingResource?(myPeerID, resourceName, peer, localURL)
    }
}


