import unsigned, ptrmath

const
    eofSymbol = 256
    maxSymbols = eofSymbol+1
    maxNodes = maxSymbols*2-1
    lutBits = 10
    lutSize = 1 shl lutBits
    lutMask = lutSize-1
    twFreqTable = [1u32 shl 30u32,4545,2657,431,1950,919,444,482,2244,617,838,542,715,1814,304,240,754,212,647,186,283,131,146,166,543,164,167,136,179,859,363,113,157,154,204,108,137,180,202,176,872,404,168,134,151,111,113,109,120,126,129,100,41,20,16,22,18,18,17,19,16,37,13,21,362,166,99,78,95,88,81,70,83,284,91,187,77,68,52,68,59,66,61,638,71,157,50,46,69,43,11,24,13,19,10,12,12,20,14,9,20,20,10,10,15,15,12,12,7,19,15,14,13,18,35,19,17,14,8,5,15,17,9,15,14,18,8,10,2173,134,157,68,188,60,170,60,194,62,175,71,148,67,167,78,211,67,156,69,1674,90,174,53,147,89,181,51,174,63,163,80,167,94,128,122,223,153,218,77,200,110,190,73,174,69,145,66,277,143,141,60,136,53,180,57,142,57,158,61,166,112,152,92,26,22,21,28,20,26,30,21,32,27,20,17,23,21,30,22,22,21,27,25,17,27,23,18,39,26,15,21,12,18,18,27,20,18,15,19,11,17,33,12,18,15,19,18,16,26,17,18,9,10,25,22,22,17,20,16,6,16,15,20,14,18,24,335,1517]

type
    TNode = object
        bits: uint32
        numBits: uint32
        leafs: array[2, uint16]
        symbol: uint8

type
    THuffmanConstructNode = object
        nodeId: uint16
        freq: uint32
    PHuffmanConstructNode = ref THuffmanConstructNode
    PNode = ref TNode

var
    nodes: array[maxNodes, PNode]
    decLuts: array[lutSize, PNode]
    startNode: PNode
    numNodes: int

proc freqSort(list : var array[maxSymbols, PHuffmanConstructNode], length) =
    var changed = true
    while changed:
        changed = false
        for i in 0 .. <length-1:
            if list[i].freq < list[i+1].freq:
                swap(list[i], list[i+1])
                changed = true
    return

proc setBitsR(node : PNode, bits : uint32, depth : uint32) =
    if node.leafs[1] != 0xffff:
        setBitsR(nodes[node.leafs[1]], bits or (1u32 shl depth), depth+1)
    if node.leafs[0] != 0xffff:
        setBitsR(nodes[node.leafs[0]], bits, depth+1)

    if node.numBits != 0:
        node.bits = bits
        node.numBits = depth

proc constructTree(freqs: array[maxSymbols, uint32]) =
   
    # array of references for efficient sorting
    var nodesLeft : array[maxSymbols, PHuffmanConstructNode]

    var numNodesLeft = maxSymbols

    # add nodes
    for i in 0 .. <maxNodes:
        new(nodes[i])

    # add the symbols
    for i in 0 .. <maxSymbols:
        nodes[i].numBits = 0xffffffff
        nodes[i].symbol = i and 0xff
        nodes[i].leafs[0] = 0xffff
        nodes[i].leafs[1] = 0xffff
 
        new(nodesLeft[i])
        
        if i == eofSymbol:
            nodesLeft[i].freq = 1
        else:
            nodesLeft[i].freq = freqs[i]

        nodesLeft[i].nodeId = i and 0xffff

    numNodes = maxSymbols

    while numNodesLeft > 1:
        freqSort(nodesLeft, numNodesLeft)

        nodes[numNodes].numBits = 0
        nodes[numNodes].leafs[0] = nodesLeft[numNodesLeft-1].nodeId
        nodes[numNodes].leafs[1] = nodesLeft[numNodesLeft-2].nodeId
        nodesLeft[numNodesLeft-2].nodeId = numNodes and 0xffff
        nodesLeft[numNodesLeft-2].freq = nodesLeft[numNodesLeft-1].freq + nodesLeft[numNodesLeft-2].freq
        numNodes.inc()
        numNodesLeft.dec()

    # set start node
    startNode = nodes[numNodes-1]

    # build symbol bits
    setBitsR(startNode, 0, 0)

proc buildDecodeLUT() =
    for i in 0 .. <lutSize:
        var bits : uint32 = uint32(i)

        var node = startNode
        var reachedEnd = true
        for k in 0 .. <lutBits:
            var leaf = node.leafs[int(bits and 1)]

            node = nodes[leaf]

            bits = bits shr 1

            if node.numBits != 0:
                # reached root node
                reachedEnd = false
                decLuts[i] = node
                break
        
        if reachedEnd:
            decLuts[i] = node


proc compress*(input : ptr uint8, inLen: int, dst : ptr uint8, dstLen: int) : int =

    # buffer indices
    var srcIndex : int = 0
    var dstIndex : int = 0

    # symbol variables
    var bits : uint32 = 0
    var bitCount : uint32 = 0

    # make sure that we have data that we want to compress
        
    while srcIndex <= inLen:
        # load the symbol
        var node : PNode
        
        if srcIndex < inLen:
            node = nodes[input[srcIndex]]
        else:
            # last symbol has to be eof
            node = nodes[eofSymbol]
        
        bits = bits or (node.bits shl bitCount)
        bitCount += node.numBits

        # write the symbol to sequence
        while bitCount >= 8u32:
            if dstIndex == dstLen:
                # reached length of dst buffer
                result = -1 # failed
                return
            dst[dstIndex] = bits and 0xff
            dstIndex.inc()
            bits = bits shr 8
            bitCount -= 8
        
        if srcIndex == inLen and bitCount > 0u32:
            # write end
            if dstIndex == dstLen:
                # reached length of dst buffer
                result = -1 # failed
                return
            dst[dstIndex] = bits and 0xff
            dstIndex.inc()

        srcIndex.inc()
   
    # done
    result = dstIndex

proc decompress*(input: ptr uint8, inLen: int, dst: ptr uint8, dstLen: int) : int =
    
    # buffer indices
    var srcIndex : int = 0
    var dstIndex : int = 0
    
    var bits : uint32 = 0
    var bitCount : uint32 = 0

    var eof = nodes[eofSymbol]
    var node : PNode

    while true:
        node = nil

        # fill with new bits
        while bitCount < 24 and srcIndex != inLen:
            bits = bits or (uint32(input[srcIndex]) shl bitCount)
            srcIndex += 1
            bitCount += 8

        node = decLuts[int(bits and lutMask)]

        if node == nil:
            result = -1
            return

        # check if we hit a symbol
        if node.numBits != 0:
            # remove the bits for that symbol
            bits = bits shr node.numBits
            bitCount -= node.numBits
        else:
            # remove bits
            bits = bits shr lutBits
            bitCount -= lutBits

            # walk the three bit by bit
            while true:
                # traverse tree
                node = nodes[node.leafs[int(bits and 1)]]

                # remove bit
                bits = bits shr 1
                bitCount -= 1

                # check if we hit a symbol
                if node.numBits != 0:
                    break

                # no more bits, decoding error
                if bitCount == 0:
                    result = -1
                    return


        # check for eof
        if node == eof:
            break;

        if dstIndex == dstLen:
            result = -1
            return

        dst[dstIndex] = node.symbol
        dstIndex += 1

    # done
    result = dstIndex # return size

proc initTeeworlds*() =
  constructTree(twFreqTable)
  buildDecodeLUT()


#TESTING
when isMainModule:
  constructTree(twFreqTable)
  buildDecodeLUT()

  var data = [5u8, 70, 61, 22, 33]
  var dstBuf : array[1024, uint8]
  var decBuf : array[1024, uint8]

  var length = compress(addr data[0], data.len, addr dstBuf[0], dstBuf.len)
  length = decompress(addr dstBuf[0], length, addr decBuf[0], decBuf.len)

  echo("done len ", length," : ", $(@decBuf))
