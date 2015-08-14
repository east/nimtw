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

proc seqTokenInfo(packet: PacketConstruct, extra: string): string =
  if extra.len == 0:
    return "no seq token"

  var
    seqOffs = 0
    validSize = false

  # ctrl
  if packet.isCtrl:
    if packet.data[0].int notin 0 .. 4:
      return "oops"
    var ctrl = NetCtrlMsg(packet.data[0])
    if (ctrl == NetCtrlMsg.ConnectAccept or
        ctrl == NetCtrlMsg.Connect) and extra.len == 8:
      seqOffs = 4
      validSize = true
    elif extra.len == 4:
      validSize = true
  # chunks
  elif extra.len == 4:
    validSize = true

  if not validSize:
    return "invalid extra size $1".format(extra.len)


  # parse seq token
  var info = newStringOfCap(32)
  info &= "seq token: "

  for i in 0 .. 3:
    info &= BiggestInt(extra[i+seqOffs].int).toHex(2)
  
  return info

proc handlePacket(packet: PacketConstruct, cl: Client) =
  if packet.isConnless(): return # ignore connless packets

  # msg from client
  var prefix = " -> "
  
  if cl == anyClient:
    # msg from server
    prefix = " <- "

  var
    extra = newString(4)

  var res = chunkList.fetchChunks(packet, (address: cl.address, port: cl.port), -1, extra)

  if res != ueSuccess:
    echo("fetchChunks error: ", res)
    return

  #var addInfo = " : " & seqTokenInfo(packet, extra)

  echo(prefix, "packet ack ", packet.ack, " flags: ", packet.flagsInfo)

  if packet.isCtrl:
    try:
      var ctrl = $NetCtrlMsg(packet.data[0])
      #echo(prefix, "ctr msg: ", ctrl, addInfo)
      echo(prefix, "  ctrl msg: ", ctrl)
    except:
      echo(prefix, "  ctrl msg: invalid : ", packet.data[0].int)

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

      echo(prefix, "  ", c.chunkInfo)

    #  echo("msg ", msgId, " : ", NetMsgType(msgId))
      # if sys:
      #   #echo(prefix, " sys msg: ", NetSysMsg(msgId), " seq: ", c.sequence, " f: ", c.flags, addInfo)
      #   echo(prefix, " sys msg: ", NetSysMsg(msgId), " seq: ", c.sequence, " f: ", c.flagsInfo)

      #   case msgId.NetSysMsg:
      #   of NetSysMsg.Info:

      #     var
      #       version = ""
      #       password = ""
      #     

      #     unpacker.getString(version)
      #     unpacker.getString(password)

      #     echo("client version: '$1' pw '$2'".format(version, password))
      #   else:
      #     discard

      # else:
      #   #echo(prefix, " gam msg: ", NetMsgType(msgId), addInfo)
      #   echo(prefix, " gam msg: ", NetMsgType(msgId), " seq: ", c.sequence, " f: ", c.flagsInfo)

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

  srv.bindAddr(Port(8304), "0.0.0.0")

  mainLoop(srv)


when isMainModule:
  quit(main())
