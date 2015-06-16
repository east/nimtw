# (c) Magnus Auvinen. See licence.txt in the root of the distribution for more information. 
# If you are missing that file, acquire a complete release at teeworlds.com.                
#
#
#CURRENT:
# packet header: 3 bytes
#  unsigned char flags_ack; // 4bit flags, 4bit ack
#  unsigned char ack; // 8 bit ack
#  unsigned char num_chunks; // 8 bit chunks
#
#  (unsigned char padding[3])	// 24 bit extra incase it's a connection less packet
#         // this is to make sure that it's compatible with the
#         // old protocol
#
# chunk header: 2-3 bytes
#  unsigned char flags_size; // 2bit flags, 6 bit size
#  unsigned char size_seq; // 4bit size, 4bit seq
#  (unsigned char seq;) // 8bit seq, if vital flag is set
#

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

discard """
type 
  CNetChunk* = object         # -1 means that it's a stateless packet
                              # 0 on the client means the server
    m_ClientID*: cint
    m_Address*: NETADDR       # only used when client_id == -1
    m_Flags*: cint
    m_DataSize*: cint
    m_pData*: pointer

  CNetChunkHeader* = object 
    m_Flags*: cint
    m_Size*: cint
    m_Sequence*: cint
"""

type 
  CNetChunkResend* = object 
    m_Flags*: cint
    m_DataSize*: cint
    m_pData*: ptr cuchar
    m_Sequence*: cint
    m_LastSendTime*: int64
    m_FirstSendTime*: int64

  CNetPacketConstruct* = object 
    m_Flags*: cint
    m_Ack*: cint
    m_NumChunks*: cint
    m_DataSize*: cint
    m_aChunkData*: array[NET_MAX_PAYLOAD, cuchar]

discard """
  CNetConnection* = object # TODO: is this needed because this needs to be aware of
                           # the ack sequencing number and is also responible for updating
                           # that. this should be fixed.
    m_Sequence*: cushort
    m_Ack*: cushort
    m_State*: cuint
    m_Token*: cint
    #m_SecurityToken*: SECURITY_TOKEN
    m_RemoteClosed*: cint
    m_BlockCloseMsg*: bool
    #m_Buffer*: TStaticRingBuffer[CNetChunkResend, NET_CONN_BUFFERSIZE]
    m_LastUpdateTime*: int64
    m_LastRecvTime*: int64
    m_LastSendTime*: int64
    m_ErrorString*: array[256, char]
    m_Construct*: CNetPacketConstruct
    m_PeerAddr*: NETADDR
    m_Socket*: NETSOCKET
    m_Stats*: NETSTATS        #
    m_TimeoutProtected*: bool
    m_TimeoutSituation*: bool


type 
  CNetRecvUnpacker* = object 
    m_Valid*: bool
    m_Addr*: NETADDR
    m_pConnection*: ptr CNetConnection
    m_CurrentChunk*: cint
    m_ClientID*: cint
    m_Data*: CNetPacketConstruct
    m_aBuffer*: array[NET_MAX_PACKETSIZE, cuchar]


proc constructCNetRecvUnpacker*(): CNetRecvUnpacker {.constructor.}
proc Clear*(this: var CNetRecvUnpacker)
proc Start*(this: var CNetRecvUnpacker; pAddr: ptr NETADDR; 
            pConnection: ptr CNetConnection; ClientID: cint)
proc FetchChunk*(this: var CNetRecvUnpacker; pChunk: ptr CNetChunk): cint
# server side

type 
  CNetServer* = object 
    m_Socket*: NETSOCKET
    m_pNetBan*: ptr CNetBan
    m_aSlots*: array[NET_MAX_CLIENTS, CSlot]
    m_MaxClients*: cint
    m_MaxClientsPerIP*: cint
    m_pfnNewClient*: NETFUNC_NEWCLIENT
    m_pfnDelClient*: NETFUNC_DELCLIENT
    m_UserPtr*: pointer
    m_SecurityTokenSeed*: array[16, cuchar]
    m_RecvUnpacker*: CNetRecvUnpacker

  CNetConsole* = object 
    m_Socket*: NETSOCKET
    m_pNetBan*: ptr CNetBan
    m_aSlots*: array[NET_MAX_CONSOLE_CLIENTS, CSlot]
    m_pfnNewClient*: NETFUNC_NEWCLIENT
    m_pfnDelClient*: NETFUNC_DELCLIENT
    m_UserPtr*: pointer
    m_RecvUnpacker*: CNetRecvUnpacker


# client side

type 
  CNetClient* = object 
    m_Connection*: CNetConnection
    m_RecvUnpacker*: CNetRecvUnpacker
    m_Socket*: NETSOCKET      # openness
  


"""
