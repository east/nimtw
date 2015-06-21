import netmsgtypes, netmsgdefs, msgpacker, strutils

# server messages
netmsg:
  Invalid: discard

  SvMotd:
    msg: string
    
  SvBroadcast:
    msg: string

  SvChat:
    team: Team
    clientId: ClientId
    msg: StringHalfStrict

  SvKillMsg:
    killer: ClientId
    victim: ClientId
    weapon: Weapon
    modeSpecial: int

  SvSoundGlobal:
    soundId: Sound

  SvTuneParams: discard
  SvExtraProjectile: discard
  SvReadyToEnter: discard

  SvWeaponPickup:
    weapon: Weapon

  SvEmoticon:
    clientId: ClientId
    emoticon: Emoticon

  SvVoteClearOptions: discard
  
  SvVoteOptionListAdd:
    numOptions: range[1 .. 15]
    description0: StringStrict
    description1: StringStrict
    description2: StringStrict
    description3: StringStrict
    description4: StringStrict
    description5: StringStrict
    description6: StringStrict
    description7: StringStrict
    description8: StringStrict
    description9: StringStrict
    description10: StringStrict
    description11: StringStrict
    description12: StringStrict
    description13: StringStrict
    description14: StringStrict

  SvVoteOptionAdd:
    description: StringStrict

  SvVoteOptionRemove:
    description: StringStrict

  SvVoteSet:
    timeout: range[0 .. 60]
    description: StringStrict
    reason: StringStrict

  SvVoteStatus:
    yes: ClientIdValid
    no: ClientIdValid
    pass: ClientIdValid
    total: ClientIdValid

  # client messages
  ClSay:
    team: bool
    msg: StringHalfStrict

  ClSetTeam:
    team: Team

  ClSetSpectatorMode:
    spectatorId: SpectatorId

  ClStartInfo:
    name: StringStrict
    clan: StringStrict
    country: int
    skin: StringStrict
    useCustomColor: bool
    colorBody: int
    colorFeet: int

  ClChangeInfo:
    name: StringStrict
    clan: StringStrict
    country: int
    skin: StringStrict
    useCustomColor: bool
    colorBody: int
    colorFeet: int

  ClKill: discard

  ClEmoticon:
    emoticon: Emoticon

  ClVote:
    vote: range[-1 .. 1]

  ClCallVote:
    typeStr: StringStrict
    value: StringStrict
    reason: StringStrict

  ClIsDDNet: discard

  SvDDRaceTime:
    time: int
    check: int
    finish: range[0 .. 1]

  SvRecord:
    serverTimeBest: int
    playerTimeBest: int

  SvPlayerTime:
    time: int
    clientId: ClientId

  SvTeamsState: discard

  ClShowOthers:
    show: bool


when isMainModule:
  var t = SvPlayerTime()

  t.time = 5
  t.clientId = 15


  var msg : NetMsg = t

  var t2 = SvPlayerTime(msg)

  echo("msg: ", t2[])



