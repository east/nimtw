# network unpackers / parser
# (contains unsafe operations e.g. pointer arithmetics)

import strutils
import ptrmath, unsigned, twnetheaders, msgpacker, netmsg

from rawsockets import Port

# don't include huffman into our namespace
from huffman import nil

# unpacker

type
  PacketConstructObj = object
    flags*: int
    ack*: int
    numChunks*: int
    dataSize*: int
    data*: array[NET_MAX_PAYLOAD, uint8]

  PacketConstruct* = ref PacketConstructObj

# global network init
proc networkInit*() =
  huffman.initTeeworlds()

type UnpackError* = enum
  # unpackPacket
  ueSuccess,
  ueSmall,
  ueOversized,
  ueStrangeConnlessFlags,
  ueHuffman,
  ueOverflow,

proc flagsInfo*(t: PacketConstruct): string =
  var parts: seq[string] = @[]

  if (t.flags and NET_PACKETFLAG_CONTROL) != 0:
    parts.add("ctrl")
  
  if (t.flags and NET_PACKETFLAG_CONNLESS) != 0:
    parts.add("connless")
  
  if (t.flags and NET_PACKETFLAG_RESEND) != 0:
    parts.add("resend")

  if (t.flags and NET_PACKETFLAG_COMPRESSION) != 0:
    parts.add("compress")

  if parts.len > 0:
    result = parts.join("|")
  else:
    result = "<none>"


proc isConnless*(t: PacketConstruct): bool =
  (t.flags and NET_PACKETFLAG_CONNLESS) != 0

proc isCtrl*(t: PacketConstruct): bool =
  (t.flags and NET_PACKETFLAG_CONTROL) != 0

proc unpackPacket*(t: PacketConstruct, data: var string): UnpackError =

  result = ueSuccess

  if data.len < NET_PACKETHEADERSIZE:
    return ueSmall
  if data.len > NET_MAX_PACKETSIZE:
    return ueOversized

  # parsing using c like array
  var p: ptr uint8 = cast[ptr uint8](addr data[0])

  t.flags = (p[0] shr 4).int
  t.ack = ((p[0].int and 0xf) shl 8) or p[1].int
  t.numChunks = p[2].int;
  t.dataSize = data.len - NET_PACKETHEADERSIZE

  if (t.flags and NET_PACKETFLAG_CONNLESS) != 0:
    # packet is connless
    #if (t.flags and (not NET_PACKETFLAG_CONNLESS)) != 0:
    if t.flags != 0b1111:
      # connless packet contains strange flags
      return ueStrangeConnlessFlags

    t.flags = NET_PACKETFLAG_CONNLESS
  else:
    # normal client packet
    if (t.flags and NET_PACKETFLAG_COMPRESSION) != 0:
      # huffman compressed packet
      #TODO: getting pretty unsafe here (should huffman get a safe implementation?)
      var res = huffman.decompress(addr p[3], t.dataSize, addr t.data[0], sizeof(t.data))
      if res == -1:
        return ueHuffman

      # new datasize
      t.dataSize = res
    else:
      # raw packet
      copyMem(addr t.data[0], addr p[3], t.dataSize)

  #done

# chunks
const MAX_CHUNKS = 0xff

type
  Address* = tuple[address: string, port: Port]

  NetChunk* = ref object
    clientId*: int
    address*: Address
    flags*: int
    dataSize*: int
    data*: ptr uint8
    sequence*: int

  NetChunkList* = ref object
    numChunks*: int
    chunks*: seq[NetChunk]

proc isVital*(t: NetChunk): bool =
  (t.flags and NET_CHUNKFLAG_VITAL) != 0

proc seqInfo*(t: NetChunk): string =
  if t.isVital:
    $t.sequence
  else:
    "-"

proc flagsInfo*(t: NetChunk): string =
  var parts: seq[string] = @[]

  if (t.flags and NET_CHUNKFLAG_VITAL) != 0:
    parts.add("vital")
  
  if (t.flags and NET_PACKETFLAG_RESEND) != 0:
    parts.add("resend")
  
  if parts.len > 0:
    result = parts.join("|")
  else:
    result = "<none>"



var unpacker = NetMsgUnpacker()
proc chunkInfo*(c: NetChunk): string =
  # init unpacker
  unpacker.init(c.data, c.dataSize)
  # unpack msg
  var
    msgId = unpacker.getInt()
    sys = (msgId and 1) != 0

  msgId = msgId shr 1

  var infoParts: seq[string] = @[]

  if sys:
    infoParts.add("sys msg: " & $NetSysMsg(msgId))
  else:
    infoParts.add("gam msg: " & $NetSysMsg(msgId))

  if c.isVital:
    infoParts.add("seq: " & c.seqInfo)

  if c.flags != 0:
    infoParts.add("flags: " & c.flagsInfo)

  result = infoParts.join(" ")

proc newChunkList*(): NetChunkList =
  result.new

  result.numChunks = 0

  # prealloc chunk objects
  result.chunks = @[]
  for i in 0 .. <MAX_CHUNKS:
    result.chunks.add(NetChunk())

proc fetchChunks*(t: NetChunkList, packet: PacketConstruct, address: Address, clientId: int, extraData: var string): UnpackError =

  result = ueSuccess

  # reset chunks
  t.numChunks = 0

  # parse all chunks
  var p  = addr packet.data[0]

  var
    flags, size, sequence, headerSize: int
    offs = 0

  for i in 0 .. <packet.numChunks:

    # check whether current chunk starts
    # out of buffer
    if offs+3 >= packet.dataSize:
      return ueOverflow

    # unpack chunk header
    flags = (p[offs+0].int shr 6) and 3
    size = ((p[offs+0].int and 0x3f) shl 4) or (p[offs+1].int and 0xf)
    sequence = -1
    headerSize = 2

    if (flags and NET_CHUNKFLAG_VITAL) != 0:
      sequence = ((p[offs+1].int and 0xf0) shl 2) or p[offs+2].int
      headerSize = 3

    # check whether current chunk exceeds boundaries
    if offs+headerSize+size > packet.dataSize:
      return ueOverflow

    # step over header
    offs += headerSize

    # set chunk
    t.numChunks.inc

    var chunk = t.chunks[i]

    chunk.clientId = clientId
    chunk.address = address
    chunk.flags = flags
    chunk.dataSize = size
    chunk.data = addr p[offs]
    chunk.sequence = sequence

    # step over chunk data
    offs += size


  # fetch extra data
  # var vanillaSize = 0

  # if packet.numChunks == 0:
  #   # should be ctrl msg
  #   vanillaSize = 1
  # else:
  #   # ends behind boundaries of last chunk
  #   vanillaSize = offs

  # var extraDataLen = packet.dataSize - vanillaSize
  # # copy extradata
  # extraData.setLen(extraDataLen)
  # copyMem(addr extraData[0], addr p[vanillaSize], extraDataLen)
  
  #TODO:
  extraData.setLen(0)

proc fetchChunks*(t: NetChunkList, packet: PacketConstruct, address: Address, clientId: int): UnpackError =
  var extraData = ""
  fetchChunks(t, packet, address, clientId, extraData)

