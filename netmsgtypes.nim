import macros, strutils

type
  #TESING
  # sanitized string types
  StringHalfStrict* = string
  StringStrict* = string

# NetMsg base type
type NetMsg* = ref object of RootObj
  discard

# macro for generating netmsgs
macro netmsg*(body: stmt): stmt {.immediate.} =
  result = newStmtList()

  # collect netmsgs
  type
    NetMsgVar = ref object
      n: NimNode
      t: NimNode
  
    NetMsg = ref object
      n: NimNode
      vars: seq[NetMsgVar]

  var msgList : seq[NetMsg] = @[]


  for i in 0 .. body.len-1:
    
    var
      msgName = body[i][0]
      vars = body[i][1]
      msg = NetMsg(n: msgName, vars: @[])

    if body[i][1][0].kind == nnkDiscardStmt:
      # empty msg class
      discard
    else:

      # add vars
      for v in 0 .. vars.len-1:
        var
          varName = body[i][1][v][0]
          varType = body[i][1][v][1][0]

        msg.vars.add(NetMsgVar(n: varName, t: varType))

    # add msg
    msgList.add(msg)

  # create enums of netmsgs
  var netMsgIdent = !"NetMsgType"
  var enumDef =
    quote do:
      type
        `netMsgIdent`* {.pure.} = enum
          dummy
  
  var enumList = enumDef[0][0][2]
  enumList.del(1) # delete dummy

  for e in 0 .. msgList.len-1:
    var msg = msgList[e]
    enumList.insert(enumList.len, msg.n)

  result.insert(0, enumDef)

  # create classes / types
  for e in 0 .. msgList.len-1:
    var msg = msgList[e]
    var typeName = msg.n
    var baseType = !"NetMsg"

    var typeDef = quote do:
      type `typeName`* = ref object of `baseType`

    var recList = newNimNode(nnkRecList)
    typeDef[0][0][2][0][2] = recList

    # build ident defs
    for v in 0 .. msg.vars.len-1:
      #recList.insert(0, msg.vars[v].identDefs)
      var identDef = newNimNode(nnkIdentDefs)

      identDef.insert(0, msg.vars[v].n)
      identDef.insert(1, msg.vars[v].t)
      identDef.insert(2, newEmptyNode())

      recList.insert(0, identDef)

    result.insert(2, typeDef)

  # generate unpack / pack functions
  var funcIdent = !"unpack"

  for i in 0 .. msgList.len-1:
    var
      msg = msgList[i]
      typeName = msg.n
      tIdent = !"t"
      unpackerIdent = !"unpacker"

    var prot =
      quote do:
        proc `funcIdent`*(`tIdent`: `typeName`, `unpackerIdent`: NetMsgUnpacker): bool = discard

    var body = prot[0][6]

    # unpack vars
    for v in 0 .. msg.vars.len-1:
      var
        varName = msg.vars[v].n
        varType = msg.vars[v].t

      #echo(repr varType)
      #echo(treeRepr varType)

      if varType.kind == nnkBracketExpr:
        # range[x..y] types won't be converted
        body.insert(v, quote do:
          # unpack integer
          t.`varName` = unpacker.getInt()
        )
      elif varType.kind == nnkIdent and not ($varType).toLower().contains("string"):
        # all other types except strings are converted integers
        body.insert(v, quote do:
          # unpack integer + convert
          t.`varName` = `varType`(unpacker.getInt())
        )
      else:
        # strings
        body.insert(v, quote do:
          # create string
          t.`varName` = ""
          # unpack string
          unpacker.getString(t.`varName`)
        )

    var resIdent = !"result"
    body.insert(body.len, quote do:
      `resIdent` = not unpacker.error
    )

    #echo repr prot


    result.insert(result.len, prot)

  #echo treeRepr(result)
  #echo repr(result)
