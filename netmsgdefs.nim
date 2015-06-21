const
  MaxClients = 16

type

  ClientId* = range[-1 .. MaxClients-1]
  ClientIdValid* = range[-1 .. MaxClients-1]
  SpectatorId* = range [-1 .. MaxClients-1]
 
  Team* {.pure.} = enum
    Spectators = -1,
    Red,
    Blue

  Emote* {.pure.} = enum
    Normal,
    Pain,
    Happy,
    Surprise,
    Angry,
    Blink,

  Powerup* {.pure.} = enum
    Health,
    Armor,
    Weapon,
    Ninja,

  Emoticon* {.pure.} = enum
    Oop,
    Exclamation,
    Hearts,
    Drop,
    DotDot,
    Music,
    Sorry,
    Ghost,
    Sushi,
    SplatTee,
    DevilTee,
    Zomg,
    Zzz,
    Wtf,
    Eyes,
    Question,

  PlayerFlag* {.pure.} = enum
    Playing = 1 shl 0,
    InMenu = 1 shl 1,
    Chatting = 1 shl 2,
    Scoreboard = 1 shl 3,
    Aim = 1 shl 4,

  GameFlag* {.pure.} = enum
    Teams = 1 shl 0,
    Flags = 1 shl 1,

  GameStateFlag* {.pure.} = enum
    GameOver = 1 shl 0,
    SuddenDeath = 1 shl 1,
    Paused = 1 shl 2,

  NetObj* {.pure.} = enum
    Invalid,
    ObjPlayerInput,
    ObjProjectile,
    ObjLaser,
    ObjPickup,
    ObjFlag,
    ObjGameInfo,
    ObjGameData,
    ObjCharacterCore,
    ObjCharacter,
    ObjPlayerInfo,
    ObjClientInfo,
    ObjSpectatorInfo,
    EvtCommon,
    EvtExplosion,
    EvtSpawn,
    EvtHammerHit,
    EvtDeath,
    EvtSoundGlobal,
    EvtSoundWorld,
    EvtDamageInd,

  Sound* {.pure.} = enum
    GunFire,
    ShotgunFire,
    GrenadeFire,
    HammerFire,
    HammerHit,
    NinjaFire,
    GrenadeExplode,
    NinjaHit,
    RifleFire,
    RifleBounce,
    WeaponSwitch,
    PlayerPainShort,
    PlayerPainLong,
    BodyLand,
    PlayerAirJump,
    PlayerJump,
    PlayerDie,
    PlayerSpawn,
    PlayerSkid,
    TeeCry,
    HookLoop,
    HookAttachGround,
    HookAttachPlayer,
    HookNoattach,
    PickupHealth,
    PickupArmor,
    PickupGrenade,
    PickupShotgun,
    PickupNinja,
    WeaponSpawn,
    WeaponNoAmmo,
    Hit,
    ChatServer,
    ChatClient,
    ChatHighlight,
    CtfDrop,
    CtfReturn,
    CtfGrabPl,
    CtfGrabEn,
    CtfCapture,
    Menu,

  Weapon* {.pure.} = enum
    Hammer,
    Gun,
    Shotgun,
    Grenade,
    Rifle,
    Ninja,

