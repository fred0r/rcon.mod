#################################################
## Add your servers below:                      ##
##   {ip port rconpass [channel]}              ##
## Channel is set via @matchbot start or here  ##
#################################################

set servers {
    { "1.2.3.4" "27015" "blah" }
}

# --- globals ---
set mb_teamsay 1
set mb_say 1
set mb_maxnamelength 15
set mb_weaponstats 0

array set kills {}
array set deaths {}
array set chan_for_ip {}
array set srv_for_ip {}

setudef flag matchbot
setudef str matchbotip

# --- store server credentials from config list ---
proc init_servers {} {
  global servers srv_for_ip
  foreach srv $servers {
    set ip [lindex $srv 0]
    set port [lindex $srv 1]
    set pass [lindex $srv 2]
    set chan [lindex $srv 3]
    set srv_for_ip($ip,host) $ip
    set srv_for_ip($ip,port) $port
    set srv_for_ip($ip,pass) $pass
    if {$chan != ""} {
      set srv_for_ip($ip,chan) $chan
    }
  }
}
init_servers

# --- restore or auto-start matchbot on connect ---
bind evnt - init-server restore_matchbot
proc restore_matchbot {type} {
  global chan_for_ip srv_for_ip
  # Restore from channel flags (set by @matchbot start)
  foreach chan [channels] {
    if {[channel get $chan matchbot]} {
      set ip [channel get $chan matchbotip]
      if {$ip != "" && [info exists srv_for_ip($ip,host)]} {
        set chan_for_ip($ip) $chan
        set_logaddress $ip
        putlog "Matchbot restored for $ip in $chan"
      }
    }
  }
  # Auto-start servers from config that have a channel set
  foreach ip [array names srv_for_ip] {
    if {[info exists srv_for_ip($ip,chan)] && ![info exists chan_for_ip($ip)]} {
      set chan $srv_for_ip($ip,chan)
      if {[validchan $chan]} {
        set chan_for_ip($ip) $chan
        channel set $chan +matchbot
        channel set $chan matchbotip $ip
        set_logaddress $ip
        putlog "Matchbot auto-started for $ip in $chan"
      }
    }
  }
}

# --- send logaddress to a server ---
proc set_logaddress {ip} {
  global srv_for_ip my-ip rcon-listen-port
  if {![info exists srv_for_ip($ip,host)]} return
  set srv_for_ip($ip,challenge) [challengercon $srv_for_ip($ip,host) $srv_for_ip($ip,port)]
  set response [rcon $srv_for_ip($ip,host) $srv_for_ip($ip,port) $srv_for_ip($ip,challenge) "$srv_for_ip($ip,pass)" "logaddress_add ${my-ip} ${rcon-listen-port}"]
}

# --- route incoming log lines ---
bind rcon - * rconmsg

proc rconmsg {msg} {
  global my-ip mb_teamsay mb_say mb_weaponstats chan_for_ip srv_for_ip

  set curchan ""
  if {[regexp {^([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+):([0-9]+) (.+)} $msg all srcip srcport msg]} {
    if {[info exists chan_for_ip($srcip)]} {
      set curchan $chan_for_ip($srcip)
    }
  }

  regexp {log L [^ ]+ - [0-9]{2}:[0-9]{2}:[0-9]{2}: (.+)} $msg orig msg

  if {$curchan == ""} {
    putlog $orig
    return
  }

  if {[regexp {\"(.+)\" attacked \"(.+)\" with \"(.+)\" \(damage \"([0-9]+)\"\) \(damage_armor \"([0-9]+)\"\) \(health \"(.+)\"\) \(armor \"([0-9]+)\"\)} $msg all nk1 nk2 gun damage damage_armor health armor]} {
    # do nothing. ignore.
  } elseif { [regexp {^Rcon: .+$} $msg] } {
      if {[regexp {Rcon: \"rcon .+ logaddress (.+) (.+)\" from \"(.+)\"} $msg all loghost logport address] && $loghost != ${my-ip}} {
        putrconchan $curchan "Uh oh...logaddress was changed to $loghost $logport by $address...getting it back"
        set_logaddress $srcip
      } else {
        putlog $msg
      }
  } elseif { [regexp {^Server cvars .+$} $msg] } { putlog $msg
  } elseif { [regexp {^Server cvar .+$} $msg] } { putlog $msg
  } elseif { [regexp {^Log file .+$} $msg] } { putlog $msg
  } elseif { [regexp {^\[ADMIN\] .+$} $msg] } { putlog $msg
  } elseif { [regexp {^\[META\] .+$} $msg] } { putlog $msg
  } elseif { [regexp {^Server say \"(.+)\"} $msg all s] } {
    putrconchan $curchan "\002Server\002: $s"
  } elseif { [regexp {^World triggered \"(.+)\"} $msg all txt] } {
    if {[string compare $txt "Round_End"] == 0} {
    } elseif {[string compare $txt "Round_Start"] == 0} {
      putrconchan $curchan "$msg"
    } else {
      putrconchan $curchan "$msg"
    }
 } elseif { [regexp {^Team \"(.+)\" scored \"(.+)\" with \"(.+)\" players} $msg all team score players] } {
    putrconchan $curchan "\002$team score:\002 $score"
    resetkills
    resetdeaths
 } elseif { [regexp {^Team \"(.+)\" triggered \"(.+)\" \(CT \"([0-9]+)\"\) \(T \"([0-9]+)\"\)} $msg all team txt scorect scoret] } {
    putrconchan $curchan "$msg"
  } elseif {[regexp {\"(.+)\" killed \"(.+)\" with \"(.+)\"} $msg all nk1 nk2 gun]} {

    set sid1 [serverid $nk1]
    set sid2 [serverid $nk2]

    if {[team $nk1] == [team $nk2]} {
      updatekills $sid1  -1
      updatedeaths $sid2 1
    } else {
      updatekills $sid1 1
      updatedeaths $sid2 1
    }

    putrconchan $curchan "[parsename $nk1] killed [parsename $nk2] with \00303$gun\003"
  } elseif {[regexp {\"(.+)\" say \"(.+)\"(.*)} $msg all nk1 txt dead]} {
    if {$mb_say} {
      if {[string compare $dead " (dead)"] == 0} {
        putrconchan $curchan "*DEAD*[parsename $nk1]: \00303$txt\003"
      } else {
        putrconchan $curchan "[parsename $nk1]: \00303$txt\003"
      }
    }
  } elseif {[regexp {\"(.+)\" say_team \"(.+)\"(.*)} $msg all nk1 txt dead]} {
    if {$mb_teamsay} {
      if {[string compare $dead " (dead)"] == 0} {
        putrconchan $curchan "*DEAD*[parsename $nk1] (team): \00303$txt\003"
      } else {
        putrconchan $curchan "[parsename $nk1] (team): \00303$txt\003"
      }
    }
  } elseif {[regexp {\"(.+)\" changed name to \"(.+)\"} $msg all nk1 nk2]} {
    putrconchan $curchan "[parsename $nk1] changed name to $nk2"
  } elseif {[regexp {\"(.+)\" triggered \"time\" \(time \"(.+)\"} $msg all nk1 val]} {
    putrconchan $curchan "[parsename $nk1] time: $val"
  } elseif {[regexp {\"(.+)\" triggered \"latency\" \(ping \"(.+)\"} $msg all nk1 val]} {
    putrconchan $curchan "[parsename $nk1] ping: $val"
  } elseif {[regexp {\"(.+)\" triggered \"(.+)\"} $msg all nk1 txt]} {
    if {[string compare $txt "Begin_Bomb_Defuse_With_Kit"] == 0} {
      putrconchan $curchan "[parsename $nk1] is defusing the bomb with a kit"
    } elseif {[string compare $txt "Begin_Bomb_Defuse_Without_Kit"] == 0} {
      putrconchan $curchan "[parsename $nk1] is defusing the bomb without a kit"
    } elseif {[string compare $txt "Planted_The_Bomb"] == 0} {
      putrconchan $curchan "[parsename $nk1] planted the bomb"
    } elseif {[string compare $txt "Got_The_Bomb"] == 0} {
      putrconchan $curchan "[parsename $nk1] got the bomb"
    } elseif {[string compare $txt "Dropped_The_Bomb"] == 0} {
      putrconchan $curchan "[parsename $nk1] dropped the bomb"
    } elseif {[string compare $txt "Spawned_With_The_Bomb"] == 0} {
      putrconchan $curchan "[parsename $nk1] has the bomb"
    } elseif {[string compare $txt "Defused_The_Bomb"] == 0} {
      putrconchan $curchan "[parsename $nk1] defused the bomb!"
    } else {
      putrconchan $curchan "[parsename $nk1] triggered $txt"
    }
  } elseif {[regexp {\"(.+)\" committed suicide with \"(.+)\"} $msg all nk1 txt]} {
    set sid1 [serverid $nk1]
    updatedeaths $sid1 1
    putrconchan $curchan "[parsename $nk1] committed suicide with $txt"
  } elseif {[regexp {\"(.+)\" triggered \"weaponstats\" \(weapon \"(.+)\"\) \(shots \"([0-9]+)\"\) \(hits \"([0-9]+)\"\) \(kills \"([0-9]+)\"\) \(headshots \"([0-9]+)\"\) \(tks \"([0-9]+)\"\) \(damage \"([0-9]+)\"\) \(deaths \"([0-9]+)\"} $msg all nk1 weapon shots hits kills headshots tks damage deaths] && $mb_weaponstats} {
    putrconchan $curchan "[parsename $nk1] \00303$weapon\003 shots: $shots hits: $hits kills: $kills hs: $headshots dmg: $damage"
  } elseif {[regexp {\"(.+)\" triggered \"weaponstats2\" \(weapon \"(.+)\"\) \(head \"([0-9]+)\"\) \(chest \"([0-9]+)\"\) \(stomach \"([0-9]+)\"\) \(leftarm \"([0-9]+)\"\) \(rightarm \"([0-9]+)\"\) \(leftleg \"([0-9]+)\"\) \(rightleg \"([0-9]+)\"} $msg all nk1 weapon head chest stomach larm rarm lleg rleg] && $mb_weaponstats} {
    putrconchan $curchan "[parsename $nk1] \00303$weapon\003 head: $head chest: $chest stomach: $stomach la: $larm ra: $rarm ll: $lleg rl: $rleg"
  } elseif {[regexp {\"(.+)\" joined team \"(.+)\"} $msg all nk1 newteam]} {
    putrconchan $curchan "\002[parsename $nk1]\002 joined the $newteam team"
  } elseif {[regexp {\"(.+)\" disconnected} $msg all nk1]} {
    putrconchan $curchan "[parsename $nk1] [steamid $nk1] disconnected"
  } elseif {[regexp {\"(.+)\" connected, address \"(.+)\"} $msg all nk1 address]} {
    putrconchan $curchan "\002[parsename $nk1]\002 [steamid $nk1] connected"
  } elseif {[regexp {\"(.+)\" entered the game} $msg all nk1]} {
    updatekills [serverid $nk1] 0
    updatedeaths [serverid $nk1] 0
    putrconchan $curchan "\002[parsename $nk1]\002 entered the game"
  } elseif {[regexp {Loading map \"(.+)\"} $msg all map]} {
    putrconchan $curchan "Loading map: $map"
  } elseif { [regexp {^Bad Rcon: .+$} $msg] } {
    putlog $msg
  } else {
    putrconchan $curchan $msg
    putlog "Unknown: $msg"
  }
}

proc parsename {name} {
  global kills deaths mb_maxnamelength
  
  if {[regexp {(.+)<([0-9]+)><([^>]+)><([A-Z]*)>} $name all nk sid auth team]} {
    if {[string compare $team "TERRORIST"] == 0} {
      return [format "\00304%.${mb_maxnamelength}s\003 \[%-2d/%2d\]" $nk [getkills $sid] [getdeaths $sid]]
    } elseif {[string compare $team "CT"] == 0} {
      return [format "\00312%.${mb_maxnamelength}s\003 \[%-2d/%2d\]" $nk [getkills $sid] [getdeaths $sid]]
    } else {
      return "$nk"
    }
  } else {
    return $name
  }
}

proc team {name} {
  if {[regexp {.+<[0-9]+><[^>]+><([A-Z]*)>} $name all team]} {
    return $team
  } else {
    return ""
  }
}


proc serverid {name} {
  if {[regexp {.+<([0-9]+)><[^>]+><[A-Z]*>} $name all serverid]} {
    return $serverid
  } else {
    return "0"
  }
}

proc steamid {name} {
  if {[regexp {.+<[0-9]+><([^>]+)>} $name all auth]} {
    return $auth
  } else {
    return ""
  }
}

 proc putrconchan {chan msg} {
  if {[string match "*<TERRORIST>*" $msg]} {
    regsub -all {<TERRORIST>} $msg {} msg
    set msg "\00304$msg\003"
  } elseif {[string match "*<CT>*" $msg]} {
    regsub -all {<CT>} $msg {} msg
    set msg "\00312$msg\003"
  }

  dccputchan 1 $msg

  if {$chan != ""} {
    set maxlen 400
    while {[string length $msg] > $maxlen} {
      set partial [string range $msg 0 $maxlen]
      set idx [string last " " $partial]
      if {$idx < 1} { set idx $maxlen }
      putquick "PRIVMSG $chan :[string range $msg 0 [expr {$idx - 1}]]"
      set msg [string trimleft [string range $msg $idx end]]
    }
    putquick "PRIVMSG $chan :$msg"
  }
  
}

proc updatekills {sid incr} {
  global kills
  
  if {$incr == 0} {
    set kills($sid) 0
  } elseif {[info exists kills($sid)]} {
    incr kills($sid) $incr
  } else {
    set kills($sid) $incr
  }
}

proc resetkills {} {
  global kills

  array unset kills  
}

proc getkills {sid} {
  global kills

  if {[info exists kills($sid)]} {
    return $kills($sid)
  } else {
    return 0
  }
}

proc updatedeaths {sid incr} {
  global deaths
  
  if {$incr == 0} {
    set deaths($sid) 0
  } elseif {[info exists deaths($sid)]} {
    incr deaths($sid) $incr
  } else {
    set deaths($sid) $incr
  }
}

proc resetdeaths {} {
  global deaths

  array unset deaths
}

proc getdeaths {sid} {
  global deaths

  if {[info exists deaths($sid)]} {
    return $deaths($sid)
  } else {
    return 0
  }
}

proc get_server_for_channel {chan} {
  global servers srv_for_ip chan_for_ip
  foreach ip [array names chan_for_ip] {
    if {$chan_for_ip($ip) == $chan} {
      return $ip
    }
  }
  return ""
}

proc matchbot {nickname ident handle channel argument } {
  global servers mb_say mb_teamsay mb_maxnamelength mb_weaponstats
  global chan_for_ip srv_for_ip my-ip rcon-listen-port

  set cmd [lindex $argument 0]
  set args [lrange $argument 1 end]

  if {$cmd == "stop"} {
    set ip [get_server_for_channel $channel]
    clearqueue help
    putquick "PRIVMSG $channel :Stopped matchbot"
    channel set $channel -matchbot
    if {$ip != ""} { unset chan_for_ip($ip) }
    resetkills
    resetdeaths
    return 1
  }

  if {$cmd == "start"} {
    if {[llength $args] < 3} {
      putquick "PRIVMSG $channel :Syntax: @matchbot start <ip> <port> <pass>"
      return 1
    }
    set ip [lindex $args 0]
    set port [lindex $args 1]
    set pass [lindex $args 2]

    if {![regexp {^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$} $ip]} {
      putquick "PRIVMSG $channel :Please use the server's IP address, not hostname"
      return 1
    }

    resetkills
    resetdeaths
    set chan_for_ip($ip) $channel
    set srv_for_ip($ip,host) $ip
    set srv_for_ip($ip,port) $port
    set srv_for_ip($ip,pass) $pass
    channel set $channel +matchbot
    channel set $channel matchbotip $ip
    set_logaddress $ip
    putquick "PRIVMSG $channel :Starting matchbot - $ip:$port"
    putquick "PRIVMSG $channel :Parameters: (say $mb_say) (teamsay $mb_teamsay) (weaponstats $mb_weaponstats) (maxnamelength $mb_maxnamelength)"
    return 1
  }

  if {$cmd == "set"} {
    set var [lindex $args 0]
    set val [lindex $args 1]

    if {$var == "say"} {
      if {$val == ""} {
        putquick "PRIVMSG $channel :mm1 display is set to $mb_say"
      } else {
        if {$val == "1" || $val == "on"} { set mb_say 1 } else { set mb_say 0 }
        putquick "PRIVMSG $channel :mm1 display was changed to $mb_say"
      }
    } elseif {$var == "teamsay"} {
      if {$val == ""} {
        putquick "PRIVMSG $channel :say_team display is set to $mb_teamsay"
      } else {
        if {$val == "1" || $val == "on"} { set mb_teamsay 1 } else { set mb_teamsay 0 }
        putquick "PRIVMSG $channel :say_team display was changed to $mb_teamsay"
      }
    } elseif {$var == "maxnamelength"} {
      if {$val == "" || ![string is integer $val]} {
        putquick "PRIVMSG $channel :Max name length is set to $mb_maxnamelength"
      } else {
        set mb_maxnamelength $val
        putquick "PRIVMSG $channel :Max name length was changed to $mb_maxnamelength"
      }
    } elseif {$var == "weaponstats"} {
      if {$val == ""} {
        putquick "PRIVMSG $channel :Weaponstats display is set to $mb_weaponstats"
      } else {
        if {$val == "1" || $val == "on"} { set mb_weaponstats 1 } else { set mb_weaponstats 0 }
        putquick "PRIVMSG $channel :Weaponstats display was changed to $mb_weaponstats"
      }
    } else {
      putserv "NOTICE $nickname :Syntax: @matchbot set <cmd> \[on|off|value\]"
      putserv "NOTICE $nickname :Commands:"
      putserv "NOTICE $nickname :  maxnamelength \[#\]  :: Sets the max name length"
      putserv "NOTICE $nickname :  say \[on|off\]  :: Show chat messages"
      putserv "NOTICE $nickname :  teamsay \[on|off\]  :: Show team chat"
      putserv "NOTICE $nickname :  weaponstats \[on|off\]  :: Show per-weapon stats"
    }
    return 1
  }

  putserv "NOTICE $nickname :ki server matchbot syntax:"
  putserv "NOTICE $nickname :@matchbot start <host> <port> <pass>  ::  Start matchbot in this channel"
  putserv "NOTICE $nickname :@matchbot stop  ::  Stop matchbot in this channel"
  putserv "NOTICE $nickname :@matchbot set <param> \[value\]  ::  Change settings"
  return 1
}

bind pub o|o @matchbot matchbot

proc myrcon {ip mycmd} {
  global srv_for_ip
  if {![info exists srv_for_ip($ip,host)]} { return "" }
  set response [rcon $srv_for_ip($ip,host) $srv_for_ip($ip,port) $srv_for_ip($ip,challenge) "$srv_for_ip($ip,pass)" $mycmd]
  if {[regexp {Bad challenge.} $response all] || [regexp {No challenge for your address.} $response all]} {
    set srv_for_ip($ip,challenge) [challengercon $srv_for_ip($ip,host) $srv_for_ip($ip,port)]
    set response [rcon $srv_for_ip($ip,host) $srv_for_ip($ip,port) $srv_for_ip($ip,challenge) "$srv_for_ip($ip,pass)" $mycmd]
  }
  return $response
}

proc rconsay {nickname ident handle channel argument } {
  set ip [get_server_for_channel $channel]
  if {$ip == "" || $argument == ""} {
    putserv "PRIVMSG $channel :Syntax: @say <text> (start matchbot first)"
  } else {
    putserv "PRIVMSG $channel :[myrcon $ip "say $argument"]"
  }
  return 1
}
bind pub o|o @say rconsay

proc rconmap {nickname ident handle channel argument } {
  set ip [get_server_for_channel $channel]
  if {$ip == "" || $argument == ""} {
    putserv "PRIVMSG $channel :Syntax: @map <map> (start matchbot first)"
  } else {
    putserv "PRIVMSG $channel :[myrcon $ip "changelevel $argument"]"
  }
  return 1
}
bind pub o|o @map rconmap

proc rconexec {nickname ident handle channel argument } {
  set ip [get_server_for_channel $channel]
  if {$ip == "" || $argument == ""} {
    putserv "PRIVMSG $channel :Syntax: @rcon <cmd> (start matchbot first)"
  } else {
    putserv "PRIVMSG $channel :[myrcon $ip $argument]"
  }
  return 1
}
bind pub o|o @rcon rconexec

proc rconchallenge {nickname ident handle channel argument } {
  set ip [get_server_for_channel $channel]
  if {$ip == ""} {
    putserv "PRIVMSG $channel :Start matchbot first"
  } else {
    set srv_for_ip($ip,challenge) [challengercon $srv_for_ip($ip,host) $srv_for_ip($ip,port)]
    putserv "PRIVMSG $channel :Challenge received for $ip"
  }
  return 1
}
bind pub o|o @challenge rconchallenge
