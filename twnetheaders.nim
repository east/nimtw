const 
  NETFLAG_ALLOWSTATELESS* = 1
  NETSENDFLAG_VITAL* = 1
  NETSENDFLAG_CONNLESS* = 2
  NETSENDFLAG_FLUSH* = 4
  NETSTATE_OFFLINE* = 0
  NETSTATE_CONNECTING* = 1
  NETSTATE_ONLINE* = 2
  NETBANTYPE_SOFT* = 1
  NETBANTYPE_DROP* = 2   

const 
  NET_VERSION* = 2
  NET_MAX_PACKETSIZE* = 1400
  NET_MAX_PAYLOAD* = NET_MAX_PACKETSIZE - 6
  NET_MAX_CHUNKHEADERSIZE* = 5
  NET_PACKETHEADERSIZE* = 3
  NET_MAX_CLIENTS* = 64
  NET_MAX_CONSOLE_CLIENTS* = 4
  NET_MAX_SEQUENCE* = 1 shl 10
  NET_SEQUENCE_MASK* = NET_MAX_SEQUENCE - 1
  NET_CONNSTATE_OFFLINE* = 0
  NET_CONNSTATE_CONNECT* = 1
  NET_CONNSTATE_PENDING* = 2
  NET_CONNSTATE_ONLINE* = 3
  NET_CONNSTATE_ERROR* = 4
  NET_PACKETFLAG_CONTROL* = 1
  NET_PACKETFLAG_CONNLESS* = 2
  NET_PACKETFLAG_RESEND* = 4
  NET_PACKETFLAG_COMPRESSION* = 8
  NET_CHUNKFLAG_VITAL* = 1
  NET_CHUNKFLAG_RESEND* = 2
  NET_CTRLMSG_KEEPALIVE* = 0
  NET_CTRLMSG_CONNECT* = 1
  NET_CTRLMSG_CONNECTACCEPT* = 2
  NET_CTRLMSG_ACCEPT* = 3
  NET_CTRLMSG_CLOSE* = 4
  NET_CONN_BUFFERSIZE* = 1024 * 32

const 
  NET_SECURITY_TOKEN_UNKNOWN* = - 1
  NET_SECURITY_TOKEN_UNSUPPORTED* = 0

