const 
  NETMSG_NULL* = 0          # the first thing sent by the client
                            # contains the version info for the client
  NETMSG_INFO* = 1          # sent by server
  NETMSG_MAP_CHANGE* = 2    # sent when client should switch map
  NETMSG_MAP_DATA* = 3      # map transfer, contains a chunk of the map file
  NETMSG_CON_READY* = 4     # connection is ready, client should send start info
  NETMSG_SNAP* = 5          # normal snapshot, multiple parts
  NETMSG_SNAPEMPTY* = 6     # empty snapshot
  NETMSG_SNAPSINGLE* = 7    # ?
  NETMSG_SNAPSMALL* = 8     #
  NETMSG_INPUTTIMING* = 9   # reports how off the input was
  NETMSG_RCON_AUTH_STATUS* = 10 # result of the authentication
  NETMSG_RCON_LINE* = 11    # line that should be printed to the remote console
  NETMSG_AUTH_CHALLANGE* = 12 #
  NETMSG_AUTH_RESULT* = 13  #
                            # sent by client
  NETMSG_READY* = 14        #
  NETMSG_ENTERGAME* = 15
  NETMSG_INPUT* = 16        # contains the inputdata from the client
  NETMSG_RCON_CMD* = 17     #
  NETMSG_RCON_AUTH* = 18    #
  NETMSG_REQUEST_MAP_DATA* = 19 #
  NETMSG_AUTH_START* = 20   #
  NETMSG_AUTH_RESPONSE* = 21 #
                             # sent by both
  NETMSG_PING* = 22
  NETMSG_PING_REPLY* = 23
  NETMSG_ERROR* = 24        # sent by server (todo: move it up)
  NETMSG_RCON_CMD_ADD* = 25
  NETMSG_RCON_CMD_REM* = 26
# this should be revised
const 
  SERVER_TICK_SPEED* = 50
  SERVER_FLAG_PASSWORD* = 0x00000001
  MAX_CLIENTS* = 64
  VANILLA_MAX_CLIENTS* = 16
  MAX_INPUT_SIZE* = 128
  MAX_SNAPSHOT_PACKSIZE* = 900
  MAX_NAME_LENGTH* = 16
  MAX_CLAN_LENGTH* = 12     # message packing
  MSGFLAG_VITAL* = 1
  MSGFLAG_FLUSH* = 2
  MSGFLAG_NORECORD* = 4
  MSGFLAG_RECORD* = 8
  MSGFLAG_NOSEND* = 16
const 
  VERSION_VANILLA* = 0
  VERSION_DDRACE* = 1
  VERSION_DDNET_OLD* = 2
  VERSION_DDNET_WHISPER* = 217
  VERSION_DDNET_GOODHOOK* = 221
  VERSION_DDNET_EXTRATUNES* = 302
  VERSION_DDNET_RCONPROTECT* = 408
  VERSION_DDNET_ANTIPING_PROJECTILE* = 604
  VERSION_DDNET_HOOKDURATION_TUNE* = 607
  VERSION_DDNET_FIREDELAY_TUNE* = 701



