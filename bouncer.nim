import os, net, rawsockets, selectors, network, basetypes

const
  BufSize = 2048

type
  Client = ref object
    socket: Socket
    address: string
    port: Port
    sel: SelectorKey

  ClientSeq = seq[Client]

let
  anyClient = Client(socket: nil, address: "0.0.0.0", port: Port(0), sel: nil)

proc getClient(clients: ClientSeq, address: string, port: Port): Client =
  result = nil

  for c in clients:
    if c.address == address and c.port == port:
      return c

var chunkList = newChunkList()

proc handlePacket(packet: PacketConstruct, cl: Client) =
  var res = chunkList.fetchChunks(packet, (address: cl.address, port: cl.port), -1)

  for i in 0 .. chunkList.numChunks:
    var c = chunkList.chunks[i]
    echo("chunk: ", repr c)

proc mainLoop(srv: Socket) =
  var buf = newStringOfCap(BufSize)
  var packet = PacketConstruct()
  var clients: ClientSeq = @[]

  #
  networkInit()

  var
    fromAddr = ""
    fromPort: Port
    twAddr = "95.172.92.151"
    #twAddr = "127.0.0.1"
    twPort = Port(8314)
    #twPort = Port(8303)

  var sel = newSelector()
  var srvKey = sel.register(srv.getFD, {EvRead}, nil)

  while true:
   
    var fdseq = sel.select(-1)

    while fdseq.len > 0:
      var curE = fdseq.pop


      if curE.key == srvKey:
        var cl: Client
        # packet on server socket
        var res = srv.recvFrom(buf, BufSize, fromAddr, fromPort)
        #echo("[srv] received ", res, " bytes")
       
        cl = clients.getClient(fromAddr, fromPort)
        if cl == nil:
          echo("add new client: ", fromAddr, ":", fromPort)

          var s = newSocket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)

          # register fd in selector
          var sel = sel.register(s.getFD, {EvRead}, nil)

          # add client to list
          cl = Client(socket:s, address:fromAddr, port:fromPort, sel: sel)
          clients.add(cl)

        var pRes = packet.unpackPacket(buf)
        if pRes == ueSuccess:
          handlePacket(packet, cl)
        else:
          echo("unpacker res: ", pRes)

        # forward packet to server
        discard cl.socket.sendTo(twAddr, twPort, buf)

      else:
        # check client sockets
        for c in clients:
          if curE.key == c.sel:
            # receive packet from server
            var res = c.socket.recvFrom(buf, BufSize, fromAddr, fromPort)
            #echo("[tw] received ", res, " bytes")


            var pRes = packet.unpackPacket(buf)
            if pRes == ueSuccess:
              handlePacket(packet, anyClient)
            else:
              echo("unpacker res: ", pRes)

            # forward to client
            discard srv.sendTo(c.address, c.port, buf)



proc main(): int =
  var srv = newSocket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)

  srv.bindAddr(Port(8304), "127.0.0.1")

  mainLoop(srv)


when isMainModule:
  quit(main())
