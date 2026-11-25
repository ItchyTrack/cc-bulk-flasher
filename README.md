# cc bulk flasher

This is used to flash a bunch of cc: tweaked computers at once with shared and unshared code.

Make a github repo with `config.json` and `targets.json` and run `release.py --pubkey` to get the public key.

Run this with your public key and target string to the command on any computer you want to flash and restart it.
```lua
wget run https://raw.githubusercontent.com/ItchyTrack/cc-bulk-flasher/refs/heads/main/lua/install.lua
```
Example:
```lua
wget run .../install.lua 19a62a9695368290f4f55cc2fb85fc74c1f6db281ced746d4dfa4eb576f35be8 door5
```
Then run `release.py` in the github repo and run the command it gives you on any computer conneted to rednet. It will make a `dist` dir and push it with a new git tag. All connected computers computer will pull the new code according to the `targets.json`.

If you share your private key others will be able to publish to all your computers.
