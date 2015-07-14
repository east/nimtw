import os, net, rawsockets, selectors, network, msgpacker, netmsg, netmsgdefs, strutils

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
  anyClient = Client(socket: nil, address: "0.0.0.0", port: Port(0))

proc getClient(clients: ClientSeq, address: string, port: Port): Client =
  result = nil

  for c in clients:
    if c.address == address and c.port == port:
      return c

var chunkList = newChunkList()
var unpacker = NetMsgUnpacker()


import os

proc handleGameMsg(msgType: NetMsgType) =
  if msgType == NetMsgType.ClSay:
    # unpack ClSay
    var msg = ClSay()

    if msg.unpack(unpacker):
      echo("ClSay: ", msg[])
    else:
      echo("failed to unpack")

  elif msgType == NetMsgType.SvChat:
    # unpack SvChat
    var msg = SvChat()

    if msg.unpack(unpacker):
      echo("ClChat: ", msg[])
    else:
      echo("failed to unpack")


proc handlePacket(packet: PacketConstruct, cl: Client) =
  if packet.isConnless(): return # ignore connless packets

  # msg from client
  var prefix = " -> "
  
  if cl == anyClient:
    # msg from server
    prefix = " <- "

  if packet.numChunks == 0:
    var ctrl = NetCtrlMsg(packet.data[0])
    echo(prefix, "ctr msg: ", ctrl)

  var res = chunkList.fetchChunks(packet, (address: cl.address, port: cl.port), -1)

  if res != ueSuccess:
    echo("fetchChunks error: ", res)
    return

  for i in 0 .. <chunkList.numChunks:
    var c = chunkList.chunks[i]

    # init unpacker
    unpacker.init(c.data, c.dataSize)
    # unpack msg
    var
      msgId = unpacker.getInt()
      sys = (msgId and 1) != 0

    msgId = msgId shr 1


    if unpacker.error:
      echo("unpack error")
    else:

    #  echo("msg ", msgId, " : ", NetMsgType(msgId))
      if sys:
        echo(prefix, "sys msg: ", NetSysMsg(msgId))

        case msgId.NetSysMsg:
        of NetSysMsg.Info:

          var
            version = ""
            password = ""
          

          unpacker.getString(version)
          unpacker.getString(password)

          echo("client version: '$1' pw '$2'".format(version, password))
        else:
          discard

      else:
        echo(prefix, "gam msg: ", NetMsgType(msgId))

    #var netMsgType = NetMsgType(msgId)
    #handleGameMsg(netMsgType)


proc mainLoop(srv: Socket) =
  var buf = newStringOfCap(BufSize)
  var packet = PacketConstruct()
  var clients: ClientSeq = @[]

  #
  networkInit()

  var
    fromAddr = ""
    fromPort: Port
    #twAddr = "95.172.92.151"
    twAddr = "127.0.0.1"
    #twPort = Port(8314)
    twPort = Port(8303)

  var sel = newSelector()
  sel.register(srv.getFD, {EvRead}, nil)
  var srvKey = sel[srv.getFD]

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
          sel.register(s.getFD, {EvRead}, nil)
          var selKey = sel[s.getFd]

          # add client to list
          cl = Client(socket:s, address:fromAddr, port:fromPort, sel: selKey)
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
