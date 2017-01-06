//
//  PeerOne.swift
//  PeerKit
//
//  Created by Jason Jobe on 1/5/17.
//  Copyright © 2017 Jason Jobe. All rights reserved.
//

import Foundation
import MultipeerConnectivity

public class PeerOne: NSObject, MCSessionDelegate {

    public enum Mode {
        case inactive, browse, advertise, both
    }

    let session: MCSession
    public private(set) var myPeerID: MCPeerID
    var delegate: SessionDelegate?
    public private(set) var service: String
    
    var mode: Mode = .inactive
    
    var advertiser: MCNearbyServiceAdvertiser?
    var browser: MCNearbyServiceBrowser?
    
    public init(displayName: String, service: String, delegate: SessionDelegate? = nil)
    {
        myPeerID = MCPeerID(displayName: displayName)
        self.service = service
        self.delegate = delegate
        session = MCSession(peer: myPeerID)
        super.init()
        session.delegate = self
    }
    
    public func activate (mode: Mode = .both) {
        self.mode = mode
    }
    
    public func deactivate ()
    {
        self.stopBrowsing()
        self.stopAdvertising()
        
        self.delegate = nil
        session.delegate = nil
        session.disconnect()
        mode = .inactive
    }
    
    public func send (event: String, mode: MCSessionSendDataMode = .reliable, object: AnyObject? = nil, to peers: [MCPeerID]? = nil) {
        
        let peers = peers ?? session.connectedPeers
        guard !peers.isEmpty else { return }
        
        var rootObject: [String: AnyObject] = ["event": event as AnyObject]
        
        if let object: AnyObject = object {
            rootObject["object"] = object
        }
        
        let data = NSKeyedArchiver.archivedData(withRootObject: rootObject)
        try? session.send(data, toPeers: peers, with: mode)
    }
    
    public func send (resource: URL,
                      named resourceName: String,
                      to peers: [MCPeerID]? = nil,
                      complete handler: ((Error?) -> Void)?) -> [Progress?]? {
        
        let peers = peers ?? session.connectedPeers

        return peers.map { peerID in
            return session.sendResource(at: resource, withName: resourceName, toPeer: peerID,
                                        withCompletionHandler: handler)
        }
    }

    // MARK: MCSessionDelegate
    
    public func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        switch state {
        case .connecting:
            delegate?.connecting(myPeerID: myPeerID, toPeer: peerID)
        case .connected:
            delegate?.connected(myPeerID: myPeerID, toPeer: peerID)
        case .notConnected:
            delegate?.disconnected(myPeerID: myPeerID, fromPeer: peerID)
        }
    }
    
    public func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        delegate?.receivedData(myPeerID: myPeerID, data: data, fromPeer: peerID)
    }
    
    public func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        // unused
    }
    
    public func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        // unused
    }
    
    public func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL, withError error: Error?) {
        if (error == nil) {
            delegate?.finishReceivingResource(myPeerID: myPeerID, resourceName: resourceName, fromPeer: peerID, atURL: localURL)
        }
    }
}

extension PeerOne: MCNearbyServiceBrowserDelegate {

    func startBrowsing(serviceType: String) {
        browser = MCNearbyServiceBrowser(peer: session.myPeerID, serviceType: serviceType)
        browser?.delegate = self
        browser?.startBrowsingForPeers()
    }
    
    func stopBrowsing() {
        browser?.delegate = nil
        browser?.stopBrowsingForPeers()
    }
    
    public func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        browser.invitePeer(peerID, to: session, withContext: nil, timeout: 30)
    }
    
    public func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        // unused
    }
}

extension PeerOne: MCNearbyServiceAdvertiserDelegate {

    func startAdvertising(serviceType: String, discoveryInfo: [String: String]? = nil) {
        advertiser = MCNearbyServiceAdvertiser(peer: session.myPeerID, discoveryInfo: discoveryInfo, serviceType: serviceType)
        advertiser?.delegate = self
        advertiser?.startAdvertisingPeer()
    }
    
    func stopAdvertising() {
        advertiser?.delegate = nil
        advertiser?.stopAdvertisingPeer()
    }
    
    public func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        let accept = session.myPeerID.hashValue > peerID.hashValue
        invitationHandler(accept, session)
        if accept {
            stopAdvertising()
        }
    }
}
