import unsigned, ptrmath

type
  NetMsgUnpacker* = ref object
    data*: ptr uint8
    size*: int
    offs*: int
    error*: bool # error state prevents
                # further unpacking

  NetMsgPacker* = ref object
    data*: ptr uint8
    size*: int
    offs*: int
    error*: bool # error state prevents
                # further unpacking

proc init*(t: NetMsgUnpacker|NetMsgPacker, data: ptr uint8, size: int) =
  t.data = data
  t.size = size
  t.offs = 0

proc addRaw*(t: NetMsgPacker, data: pointer, size: int) =
  if t.error: return # ignore silently 

  # check for enough space
  if t.offs + size > t.size:
    t.error = true
    return

  # copy data
  copyMem(addr t.data[t.offs], data, size)
  t.offs += size

proc getRaw*(t: NetMsgUnpacker, dst: pointer, size: int) =
  if t.error: return # ignore silently

  # check for enough data
  if t.size-t.offs < size:
    t.error = true
    return

  # copy data
  copyMem(dst, addr t.data[t.offs], size)
  t.offs += size

proc addString*(t: NetMsgPacker, str: var string, limit: int=0) =
  if t.error: return # ignore silently

  var length = limit
  
  if length == 0 or length > str.len:
    length = str.len 

  # cstring raw length
  let cLength = length+1

  # check for enough space
  if t.offs+cLength > t.size:
    t.error = true
    return

  # copy string
  copyMem(addr t.data[t.offs], addr str[0], length)
  # add null terminator
  t.data[t.offs+length] = 0

  t.offs += cLength

proc getString*(t: NetMsgUnpacker, dst: var string) =
  if t.error: return # ignore silently

  # get length of cstring
  var
    length = 0
    nullFound = false

  for offs in t.offs .. <t.size:
    if t.data[offs] == 0:
      nullFound = true
      break
    length.inc

  # cstring raw length
  let cLength = length+1

  if not nullFound:
    # null terminator not found
    t.error = true
    return
  
  # copy string
  dst.setLen(length)
  copyMem(addr dst[0], addr t.data[t.offs], length)

  t.offs += cLength

proc getInt*(t: NetMsgUnpacker) : int =
  if t.error: return 0 # ignore silently

  # tmp offset
  var offs = t.offs

  # decompress integer
  var sign = (t.data[offs].int shr 6) and 1
  result = t.data[offs] and 0x3f
    
  block:
    if (t.data[offs] and 0x80) == 0:
      break
    offs.inc
    result = result or ((t.data[offs] and 0x7f) shl 6)
    
    if (t.data[offs] and 0x80) == 0:
      break
    offs.inc
    result = result or ((t.data[offs] and 0x7f) shl (6+7))

    if (t.data[offs] and 0x80) == 0:
      break
    offs.inc
    result = result or ((t.data[offs] and 0x7f) shl (6+7+7))

    if (t.data[offs] and 0x80) == 0:
      break
    offs.inc
    result = result or ((t.data[offs] and 0x7f) shl (6+7+7+7))

  offs.inc
  result = result xor (-sign)
 
  # overflow check
  if offs > t.size:
    t.error = true
  else:
    t.offs = offs

proc addInt*(t: NetMsgPacker, val: int) =
  if t.error: return # ignore silently

  # make sure that we have space enough
  if t.size - t.offs < 6:
    t.error = true
    return

  var
    # tmp offset
    offs = t.offs
    i = val

  # compress int
  t.data[offs] = ((i shr 25) and 0x40).uint8 # set sign bit if i<0
  i = i xor (i shr 31) # if(i<0) i = ~i

  t.data[offs] = t.data[offs] or (i and 0x3f) # pack 6bit into dst
  i = i shr 6 # discard 6 bits

  if i != 0:
    t.data[offs] = t.data[offs] or 0x80 # set extend bit
    while true:
      offs.inc
      t.data[offs] = i and 0x7f # pack 7bit
      i = i shr 7 # discard 7 bits

      if i != 0:
        t.data[offs] = t.data[offs] or (1'u8 shl 7) # set extend bit (may branch)
      else:
        break

  offs.inc

  # overflow check
  if offs > t.size:
    t.error = true
  else:
    t.offs = offs

when isMainModule:
  import strutils

  var
    buf: array[256, uint8]
    packer = NetMsgPacker()
    unpacker = NetMsgUnpacker()

  packer.init(addr buf[0], 15)
  unpacker.init(addr buf[0], sizeof buf)

  # test integer packing
  when false:
    for num in 0 .. 1_000_000_000:
      packer.init(addr buf[0], sizeof buf)
      unpacker.init(addr buf[0], sizeof buf)
    
      packer.addInt(num)
      var res = unpacker.getInt()

      if num == res:
        if (num mod 1000000) == 0:
          echo("right size ", packer.offs, " ", num)
      else:
        echo("wrong: ", num, " -> ", res)
        break

  # test string packing
  when false:
    # pack string
    var testStr = "this is a test"
    packer.addString(testStr)

    if (packer.error):
      echo("pack error")
    else:
      for i in 0 .. <packer.offs:
        echo(packer.data[i])

    # unpack string
    var str = ""
    unpacker.getString(str)

    if unpacker.error:
      echo("unpack error")
    else:
      echo("str: ", str)

  # test both
  var
    testStr = "hello"
    i = 5

  packer.addInt(100)
  packer.addRaw(addr i, 4)
  packer.addString(testStr)
  packer.addInt(1000)

  
  var
    i1, i2: int
    str = ""
  
  i1 = unpacker.getInt()
  unpacker.getRaw(addr i, 4)
  unpacker.getString(str)
  i2 = unpacker.getInt()

  echo(i1, " ", i, " ", str, " ", i2)
