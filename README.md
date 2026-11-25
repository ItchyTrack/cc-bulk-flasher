# cc bulk flasher

This is used to flash a bunch of cc: tweaked computers at once with shared and unshared code.

Make a github repo with `config.json` and `targets.json` and run `release.py --pubkey` to get the public key.

Run `wget run https://raw.githubusercontent.com/ItchyTrack/cc-bulk-flasher/refs/heads/main/lua/install.lua` `<pubkey>` `<target>` on any computer you want to flash and restart it.

Then run `release.py` in the github repo and run the command it gives you on any computer conneted to rednet. It will make a `dist` dir and push it with a new git tag. All connected computers computer will pull the new code according to the `targets.json`.

If you share your private key others will be able to publish to all your computers.
