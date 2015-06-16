# network unpackers / parser
# (contains unsafe operations e.g. pointer arithmetics)

import ptrmath, unsigned, twnetheaders

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
  errSucess,
  errSmall,
  errOversized,
  errStrangeConnlessFlags,
  errHuffman,

proc unpackPacket*(t: PacketConstruct, data: var string) : UnpackError =
  
  result = errSucess

  if data.len < NET_PACKETHEADERSIZE:
    return errSmall
  if data.len > NET_MAX_PACKETSIZE:
    return errOversized

  # parsing using c like array
  var p : ptr uint8 = cast[ptr uint8](addr data[0])

  t.flags = (p[0] shr 4).int
  t.ack = ((p[0].int and 0xf) shl 8) or p[1].int
  t.numChunks = p[2].int;
  t.dataSize = data.len - NET_PACKETHEADERSIZE

  if (t.flags and NET_PACKETFLAG_CONNLESS) != 0:
    # packet is connless
    #if (t.flags and (not NET_PACKETFLAG_CONNLESS)) != 0:
    if t.flags != 0b1111:
      # connless packet contains strange flags
      return errStrangeConnlessFlags

    t.flags = NET_PACKETFLAG_CONNLESS
  else:
    # normal client packet
    if (t.flags and NET_PACKETFLAG_COMPRESSION) != 0:
      # huffman compressed packet
      #TODO: getting pretty unsafe here (should huffman get a safe implementation?)
      var res = huffman.decompress(addr p[3], t.dataSize, addr t.data[0], sizeof(t.data))
      if res == -1:
        return errHuffman
      echo("[huffman] ", t.dataSize, " -> ", res)
      # new datasize
      t.dataSize = res
    else:
      # raw packet
      copyMem(addr t.data[0], addr p[3], t.dataSize)

  #done
