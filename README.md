# wild
Wild is a lightweight server framework for RedM that supports many standard role-playing features and more.

It does not use a database connection. Instead, it simply uses a local JSON file to store data and it has no anti-cheating methods whatsoever. Intended for use in LAN parties.

## How to install
1. Download and place all wild resources into a `[wild]` subfolder under `resources` in your FXServer.
2. In your `server.cfg` file, disable the `spawnmanager` and `basic-gamemode` default resources. Add the following lines:
```
ensure wild-core
ensure wild-satchel
start wild-interact
start wild-shops
start wild-war
start wild-guarma
start wild-horses
start wild-emote
start wild-blips
```

3. Rename the following files in their respective folders:

| Folder          | Current Filename            | New Filename                |
|-----------------|-----------------------------|-----------------------------|
| wild-core       | `_config.json`              | `config.json`               |
|                 | `_honor.json`               | `honor.json`                |
|                 | `_npcs.json`                | `npcs.json`                 |
|                 | `_player_outfits.json`      | `player_outfits.json`       |
|                 | `_players.json`             | `players.json`              |
| wild-horses     | `_player_horses.json`       | `player_horses.json`        |
| wild-war        | `_factions.json`            | `factions.json`             |
| wild-satchel    | `_player_inventories.json`  | `player_inventories.json`   |