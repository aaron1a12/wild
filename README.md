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
3. Go to `wild-core` and rename `_config.json` and `_players.json` to `config.json` and `players.json`