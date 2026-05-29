# rcon.mod

Eggdrop C module providing RCON control of GoldSrc/HLDS game servers (Counter-Strike, etc.) + a matchbot TCL plugin.

## Module: `rcon.c` / `rcon.h`

### Installation

Copy the `rcon.mod/` directory into `eggdrop/src/mod/`, re-run `./configure`, and `make`.

```sh
cp -r rcon.mod eggdrop-1.8.x/src/mod/
cd eggdrop-1.8.x
./configure
make config
make
```

Then load in `eggdrop.conf`:

```
loadmodule rcon
```

### TCL commands

| Command | Description |
|---|---|
| `rcon host port challenge password cmd` | Sends an RCON command to the server and returns the response |
| `challengercon host port` | Requests a challenge number from the server (required for RCON auth) |

### Config variables

| Variable | Default | Description |
|---|---|---|
| `rcon-listen-port` | `43456` | UDP port the module listens on for the server's `logaddress` stream |

### Log stream

Set `logaddress` on the server to point the bot's IP and `rcon-listen-port`:

```
rcon_password "yourpass"
logaddress <bot-ip> 43456
```

The module binds the `rcon` TCL event, firing for every log line received.

---

## Plugin: `matchbot.tcl`

A matchbot script that listens to the server's log stream via the `rcon` bind and relays events to an IRC channel with colored formatting.

### Usage

```
source scripts/matchbot.tcl
```

Configure at the top of the file:

```tcl
set rhost    "counterstrike.server.com"
set rport    "27015"
set rconpass "blah"
```

### IRC commands

| Command | Description |
|---|---|
| `@matchbot start [channel]` | Start the matchbot in the given channel (or current channel) |
| `@matchbot stop` | Stop the matchbot |
| `@matchbot set <param> [value]` | View or change a parameter |
| `@say <text>` | Make the server say something via RCON |
| `@map <mapname>` | Change the server map |
| `@rcon <cmd>` | Send an arbitrary RCON command |
| `@challenge` | Refresh the RCON challenge number |

### Settings (`@matchbot set`)

| Parameter | Values | Default | Description |
|---|---|---|---|
| `say` | on/off | on | Relay chat messages from players |
| `teamsay` | on/off | on | Relay team-chat messages |
| `maxnamelength` | number | 15 | Max displayed name width |

### Features

- **Kill feed** — shows kills with weapon, tracks K/D per player
- **Team-colored names** — TERRORIST names in red, CT names in blue
- **Round events** — bomb plants/defuses, round start/end, team scores
- **Connect/disconnect** — player join/leave notifications
- **Auto-reconnect** — re-sends `logaddress` if someone changes it
- **Line coloring** — entire line colored red if it mentions `<TERRORIST>`, blue for `<CT>` (tags stripped from output)
- **IRC safety** — messages >400 chars are split at word boundaries
- **Resets** — K/D resets at round end
