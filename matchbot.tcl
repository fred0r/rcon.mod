# Server ip address/hostname
set rhost "counterstrike.server.com"

# Server port
set rport "27015"

# Rcon password
set rconpass "blah"


#################################################
## Shouldn't need to change anything down here ##
#################################################

set matchchan ""
set challenge [challengercon $rhost $rport]
set mb_teamsay 1
set mb_say 1
set mb_maxnamelength 15
set mb_weaponstats 0

array set kills {}
array set deaths {}


bind rcon - * rconmsg

proc rconmsg {msg} {
  global rhost rport my-ip
  global mb_teamsay mb_say mb_weaponstats matchchan

  regexp {log L [^ ]+ - [0-9]{2}:[0-9]{2}:[0-9]{2}: (.+)} $msg orig msg

#  putlog $msg

  if {[regexp {\"(.+)\" attacked \"(.+)\" with \"(.+)\" \(damage \"([0-9]+)\"\) \(damage_armor \"([0-9]+)\"\) \(health \"(.+)\"\) \(armor \"([0-9]+)\"\)} $msg all nk1 nk2 gun damage damage_armor health armor]} {
    # do nothing. ignore.
  } elseif { [regexp {^Rcon: .+$} $msg] } {
      if {[regexp {Rcon: \"rcon .+ logaddress (.+) (.+)\" from \"(.+)\"} $msg all loghost logport address] && $loghost != ${my-ip}} {
          if {$matchchan == ""} {
              putrconchan "Uh oh...logaddress was changed to $loghost $logport by $address..."
          } else {
              putrconchan "Uh oh...logaddress was changed to $loghost $logport by $address...getting it back"
              getrconlog
          }
      } else {
          putlog $msg
      }
  } elseif { [regexp {^Server cvars .+$} $msg] } {
    putlog $msg
  } elseif { [regexp {^Server cvar .+$} $msg] } {
    putlog $msg
  } elseif { [regexp {^Log file .+$} $msg] } {
    putlog $msg
  } elseif { [regexp {^\[ADMIN\] .+$} $msg] } {
    putlog $msg
  } elseif { [regexp {^\[META\] .+$} $msg] } {
    putlog $msg
  } elseif { [regexp {^Server say \"(.+)\"} $msg all s] } {
    putrconchan "\002Server\002: $s"
  } elseif { [regexp {^World triggered \"(.+)\"} $msg all txt] } {
    if {[string compare $txt "Round_End"] == 0} {
    } elseif {[string compare $txt "Round_Start"] == 0} {
      putrconchan "$msg"
    } else {
      putrconchan "$msg"
    }
 } elseif { [regexp {^Team \"(.+)\" scored \"(.+)\" with \"(.+)\" players} $msg all team score players] } {
    putrconchan "\002$team score:\002 $score"
    resetkills
    resetdeaths
 } elseif { [regexp {^Team \"(.+)\" triggered \"(.+)\" \(CT \"([0-9]+)\"\) \(T \"([0-9]+)\"\)} $msg all team txt scorect scoret] } {
    putrconchan "$msg"
  } elseif {[regexp {\"(.+)\" killed \"(.+)\" with \"(.+)\"} $msg all nk1 nk2 gun]} {
   
    set sid1 [serverid $nk1]
    set sid2 [serverid $nk2]
    
    # team kill
    if {[team $nk1] == [team $nk2]} {
      updatekills $sid1  -1
      updatedeaths $sid2 1
    } else { # regular kill
      updatekills $sid1 1
      updatedeaths $sid2 1
    }
    
    putrconchan "[parsename $nk1] killed [parsename $nk2] with \00303$gun\003"
  } elseif {[regexp {\"(.+)\" say \"(.+)\"(.*)} $msg all nk1 txt dead]} {
    if {$mb_say} {
      if {[string compare $dead " (dead)"] == 0} {
        putrconchan "*DEAD*[parsename $nk1]: \00303$txt\003"
      } else {
        putrconchan "[parsename $nk1]: \00303$txt\003"
      }
    }
  } elseif {[regexp {\"(.+)\" say_team \"(.+)\"(.*)} $msg all nk1 txt dead]} {
    if {$mb_teamsay} {
      if {[string compare $dead " (dead)"] == 0} {
        putrconchan "*DEAD*[parsename $nk1] (team): \00303$txt\003"
      } else {
        putrconchan "[parsename $nk1] (team): \00303$txt\003"
      }
    }
  } elseif {[regexp {\"(.+)\" changed name to \"(.+)\"} $msg all nk1 nk2]} {
    putrconchan "[parsename $nk1] changed name to $nk2"
  } elseif {[regexp {\"(.+)\" triggered \"(.+)\"} $msg all nk1 txt]} {
    if {[string compare $txt "Begin_Bomb_Defuse_With_Kit"] == 0} {
      putrconchan "[parsename $nk1] is defusing the bomb with a kit"
    } elseif {[string compare $txt "Begin_Bomb_Defuse_Without_Kit"] == 0} {
      putrconchan "[parsename $nk1] is defusing the bomb without a kit"
    } elseif {[string compare $txt "Planted_The_Bomb"] == 0} {
      putrconchan "[parsename $nk1] planted the bomb"
    } elseif {[string compare $txt "Got_The_Bomb"] == 0} {
      putrconchan "[parsename $nk1] got the bomb"
    } elseif {[string compare $txt "Dropped_The_Bomb"] == 0} {
      putrconchan "[parsename $nk1] dropped the bomb"
    } elseif {[string compare $txt "Spawned_With_The_Bomb"] == 0} {
      putrconchan "[parsename $nk1] has the bomb"
    } elseif {[string compare $txt "Defused_The_Bomb"] == 0} {
      putrconchan "[parsename $nk1] defused the bomb!"
    } else {
      putrconchan "[parsename $nk1] triggered $txt"
    }
  } elseif {[regexp {\"(.+)\" committed suicide with \"(.+)\"} $msg all nk1 txt]} {  
    set sid1 [serverid $nk1]
    
    updatedeaths $sid1 1
    
    putrconchan "[parsename $nk1] committed suicide with $txt"
  } elseif {[regexp {\"(.+)\" triggered \"weaponstats\" \(weapon \"(.+)\"\) \(shots \"([0-9]+)\"\) \(hits \"([0-9]+)\"\) \(kills \"([0-9]+)\"\) \(headshots \"([0-9]+)\"\) \(tks \"([0-9]+)\"\) \(damage \"([0-9]+)\"\) \(deaths \"([0-9]+)\"} $msg all nk1 weapon shots hits kills headshots tks damage deaths] && $mb_weaponstats} {
    putrconchan "[parsename $nk1] \00303$weapon\003 shots: $shots hits: $hits kills: $kills hs: $headshots dmg: $damage"
  } elseif {[regexp {\"(.+)\" triggered \"weaponstats2\" \(weapon \"(.+)\"\) \(head \"([0-9]+)\"\) \(chest \"([0-9]+)\"\) \(stomach \"([0-9]+)\"\) \(leftarm \"([0-9]+)\"\) \(rightarm \"([0-9]+)\"\) \(leftleg \"([0-9]+)\"\) \(rightleg \"([0-9]+)\"} $msg all nk1 weapon head chest stomach larm rarm lleg rleg] && $mb_weaponstats} {
    putrconchan "[parsename $nk1] \00303$weapon\003 head: $head chest: $chest stomach: $stomach la: $larm ra: $rarm ll: $lleg rl: $rleg"
  } elseif {[regexp {\"(.+)\" joined team \"(.+)\"} $msg all nk1 newteam]} {
    putrconchan "\002[parsename $nk1]\002 joined the $newteam team"
  } elseif {[regexp {\"(.+)\" disconnected} $msg all nk1]} {
    putrconchan "[parsename $nk1] [steamid $nk1] disconnected"
  } elseif {[regexp {\"(.+)\" connected, address \"(.+)\"} $msg all nk1 address]} {
    putrconchan "\002[parsename $nk1]\002 [steamid $nk1] connected"
  } elseif {[regexp {\"(.+)\" entered the game} $msg all nk1]} {
    updatekills [serverid $nk1] 0
    updatedeaths [serverid $nk1] 0
    putrconchan "\002[parsename $nk1]\002 entered the game"
  } elseif {[regexp {Loading map \"(.+)\"} $msg all map]} {
    putrconchan "Loading map: $map"
  } elseif { [regexp {^Bad Rcon: .+$} $msg] } {
    putlog $msg
  } else {
    putrconchan $msg
    putlog "Unknown: $msg"
  }
}

proc parsename {name} {
  global kills deaths mb_maxnamelength
  
  if {[regexp {(.+)<([0-9]+)><([^>]+)><([A-Z]*)>} $name all nk sid auth team]} {
    if {[string compare $team "TERRORIST"] == 0} {
      return [format "\00304%-${mb_maxnamelength}.${mb_maxnamelength}s\003 \[%-2d/%2d\]" $nk [getkills $sid] [getdeaths $sid]]
    } elseif {[string compare $team "CT"] == 0} {
      return [format "\00312%-${mb_maxnamelength}.${mb_maxnamelength}s\003 \[%-2d/%2d\]" $nk [getkills $sid] [getdeaths $sid]]
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

proc getrconlog {} {
    global rhost rport challenge my-ip rcon-listen-port rconpass
    set response [myrcon "logaddress ${my-ip} ${rcon-listen-port}"]
}

proc putrconchan {msg} {
  global matchchan

  if {[string match "*<TERRORIST>*" $msg]} {
    regsub -all {<TERRORIST>} $msg {} msg
    set msg "\00304$msg\003"
  } elseif {[string match "*<CT>*" $msg]} {
    regsub -all {<CT>} $msg {} msg
    set msg "\00312$msg\003"
  }

  dccputchan 1 $msg

  if {$matchchan != ""} {
    set maxlen 400
    while {[string length $msg] > $maxlen} {
      set partial [string range $msg 0 $maxlen]
      set idx [string last " " $partial]
      if {$idx < 1} { set idx $maxlen }
      putquick "PRIVMSG $matchchan :[string range $msg 0 [expr {$idx - 1}]]"
      set msg [string trimleft [string range $msg $idx end]]
    }
    putquick "PRIVMSG $matchchan :$msg"
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

proc matchbot {nickname ident handle channel argument } {
  global matchchan rhost rport challenge rconpass rcon-listen-port my-ip
  global mb_say mb_teamsay mb_maxnamelength mb_weaponstats

  set cmd [lindex $argument 0]
  set args [lrange $argument 1 end]

  resetkills
  resetdeaths

  if {$cmd == "stop"} {
    clearqueue help
    putquick "PRIVMSG $channel :Stopped matchbot"
    set matchchan ""
  } elseif {$cmd == "start"} {
    if {$args != ""} {
        set matchchan $args
    } else {
        set matchchan $channel
    }

    getrconlog
    putquick "PRIVMSG $channel :Starting matchbot in \"$matchchan\""
    putquick "PRIVMSG $channel :Parameters: (say $mb_say) (teamsay $mb_teamsay) (weaponstats $mb_weaponstats) (maxnamelength $mb_maxnamelength)"
  } elseif {$cmd == "set"} {
    set var [lindex $args 0]
    set val [lindex $args 1]

    if {$var == "say"} {
      if {$val == ""} {
        putquick "PRIVMSG $channel :mm1 display is set to $mb_say"
      } else {
        if {$val == "1" || $val == "on"} {
          set mb_say 1
        } else {
          set mb_say 0
        }

        putquick "PRIVMSG $channel :mm1 display was changed to $mb_say"
      }

    } elseif {$var == "teamsay"} {
      if {$val == ""} {
        putquick "PRIVMSG $channel :say_team display is set to $mb_teamsay"
      } else {
        if {$val == "1" || $val == "on"} {
          set mb_teamsay 1
        } else {
          set mb_teamsay 0
        }

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
        if {$val == "1" || $val == "on"} {
          set mb_weaponstats 1
        } else {
          set mb_weaponstats 0
        }

        putquick "PRIVMSG $channel :Weaponstats display was changed to $mb_weaponstats"
      }
    } else {
      putserv "NOTICE $nickname :Syntax: @matchbot set <cmd> \[on|off|value\]"
      putserv "NOTICE $nickname :Commands:"
      putserv "NOTICE $nickname :  maxnamelength \[#\]  :: Sets the max name length to \002\#\002, for display purposes"
      putserv "NOTICE $nickname :  say \[on|off\]  :: Sets the display of message mode 1 data \002on\002 or \002off\002"
      putserv "NOTICE $nickname :  teamsay \[on|off\]  :: Sets the display of message mode 2 data (team_say) \002on\002 or \002off\002"
      putserv "NOTICE $nickname :  weaponstats \[on|off\]  :: Shows per-weapon stats on death"
    }

  } else {
    putserv "NOTICE $nickname :ki server matchbot syntax:"
    putserv "NOTICE $nickname :@matchbot start \[target\]  ::  Starts a matchbot in \002target\002, or the current channel if \002target\002 is not specified"
    putserv "NOTICE $nickname :@matchbot stop  ::  Stops matchbot"
    putserv "NOTICE $nickname :@matchbot set <parameter> \[value\]   ::  Sets or displays matchbot parameters :: \002@matchbot set\002 for more info"
  }


  return 1
}

bind pub o|o @matchbot matchbot


proc rconsay {nickname ident handle channel argument } {
  global rhost rport rconpass challenge

  if {$argument == ""} {
    putserv "PRIVMSG $channel :Syntax: @say <text>"
  } else {
    set response [myrcon "say $argument"]
    putserv "PRIVMSG $channel :$response"
  }

  return 1
}

bind pub o|o @say rconsay

proc rconmap {nickname ident handle channel argument } {
  global rhost rport rconpass challenge

  if {$argument == ""} {
    putserv "PRIVMSG $channel :Syntax: @map <map>"
  } else {
    set response [myrcon "changelevel $argument"]
    putserv "PRIVMSG $channel :$response"
  }

  return 1
}

bind pub o|o @map rconmap

proc rconexec {nickname ident handle channel argument } {
  global rhost rport rconpass challenge
  if {$argument == ""} {
    putserv "PRIVMSG $channel :Syntax: @rcon <cmd>"
  } else {
    set response [myrcon $argument]
    putserv "PRIVMSG $channel :$response"
  }

  return 1
}

bind pub o|o @rcon rconexec

bind pub o|o @challenge rconchallenge

proc rconchallenge {nickname ident handle channel argument } {
      global rhost rport challenge
      set challenge [challengercon $rhost $rport]
      putserv "PRIVMSG $channel :Challenge received"
}

proc myrcon {mycmd} {
  global rhost rport rconpass challenge

  set response [rcon $rhost $rport $challenge "$rconpass" $mycmd]

  if {[regexp {Bad challenge.} $response all] || [regexp {No challenge for your address.} $response all]} {
      set challenge [challengercon $rhost $rport]
      set response [rcon $rhost $rport $challenge "$rconpass" $mycmd]
  }

  return $response
}
