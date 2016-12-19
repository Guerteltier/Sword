import Foundation
import WebSockets

class WS {

  let requester: Request
  let endpoint = Endpoint()
  var heartbeat: Heartbeat?

  var session: WebSocket?
  let eventer: Eventer

  init(_ eventer: Eventer, _ requester: Request) {
    self.requester = requester
    self.eventer = eventer
  }

  func getGateway(completion: @escaping (Error?, [String: Any]?) -> Void) {
    requester.request(endpoint.gateway, authorization: true) { error, data in
      if error != nil {
        completion(error, nil)
        return
      }

      guard let data = data as? [String: Any] else {
        completion(.unknown, nil)
        return
      }

      completion(nil, data)
    }
  }

  func startWS(_ gatewayUrl: String) {
    try? WebSocket.connect(to: gatewayUrl) { ws in
      self.session = ws

      ws.onText = { ws, text in
        self.event(text.decode() as! [String: Any])
      }

      ws.onClose = { ws, _, _, _ in
        print("WS Closed")
      }
    }
  }

  func identify() {
    let identity = ["op": OPCode.identify.rawValue, "d": ["token": self.requester.token, "properties": ["$os": "linux", "$browser": "Sword", "$device": "Sword", "$referrer": "", "$referring_domain": ""], "compress": true, "large_threshold": 50]].encode()

    try? self.session?.send(identity)
  }

  func event(_ packet: [String: Any]) {
    let data = packet["d"]

    if let sequenceNumber = packet["s"] as? Int {
      self.heartbeat?.sequence.append(sequenceNumber)
    }

    guard let eventName = packet["t"] as? String else {
      switch packet["op"] as! Int {
        case OPCode.hello.rawValue:
          self.heartbeat = Heartbeat(self.session!, interval: (data as! [String: Any])["heartbeat_interval"] as! Int)
          self.heartbeat?.send()
          self.identify()
          break
        case OPCode.heartbeatACK.rawValue:
          self.eventer.emit("heartbeat", "hello")
          break
        default:
          print("Some other opcode")
      }

      return
    }

    print(eventName)
  }

}
