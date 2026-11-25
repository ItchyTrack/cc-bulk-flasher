#!/usr/bin/env python3
"""
Build a release from src/, tag+push it, and put the rednet update command on your clipboard.
"""
import argparse
import base64
import json
import shutil
import subprocess
import shlex
import sys
from pathlib import Path

from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey

try:
	import pyperclip
except ImportError:
	pyperclip = None

def load_config(repo_dir: Path) -> dict:
	path = repo_dir / "config.json"
	if not path.exists():
		sys.exit(f"Missing {path} -- copy config.example.json to config.json and fill it in")
	return json.loads(path.read_text())

def minify(source: str) -> str:
	"""Conservative line-based minifier: drops whole-line comments, blank
	lines, and leading/trailing whitespace. Does NOT touch inline trailing
	comments or anything inside strings, so it's safe but not maximal --
	good enough to meaningfully shrink normally-formatted source.
	"""
	out_lines = []
	in_block_comment = False
	for line in source.splitlines():
		stripped = line.strip()
		if in_block_comment:
			if "]]" in stripped:
				in_block_comment = False
			continue
		if stripped.startswith("--[["):
			if "]]" not in stripped:
				in_block_comment = True
			continue
		if stripped.startswith("--"):
			continue
		if not stripped:
			continue
		out_lines.append(stripped)
	return "\n".join(out_lines) + "\n"

def build_dist(repo_dir: Path, src_dir: str, dist_dir: str) -> None:
	src = repo_dir / src_dir
	dist = repo_dir / dist_dir
	if not src.is_dir():
		sys.exit(f"No such source dir: {src}")

	if dist.exists():
		shutil.rmtree(dist)
	dist.mkdir(parents=True)

	for path in src.rglob("*"):
		if path.is_dir():
			continue
		rel = path.relative_to(src)
		dest = dist / rel
		dest.parent.mkdir(parents=True, exist_ok=True)
		if path.suffix == ".lua":
			dest.write_text(minify(path.read_text()))
		else:
			shutil.copyfile(path, dest)

def git(repo_dir: Path, *args: str) -> None:
	subprocess.run(["git", *args], cwd=repo_dir, check=True)

def next_version(repo_dir: Path, increment: str = "patch") -> str:
	result = subprocess.run(
		["git", "describe", "--tags", "--abbrev=0"],
		cwd=repo_dir,
		capture_output=True,
		text=True,
	)
	if result.returncode != 0:
		return "v0.0.0"
	latest = result.stdout.strip().lstrip("v")
	try:
		major, minor, patch = map(int, latest.split("."))
	except ValueError:
		sys.exit(f"Invalid version tag: {latest}")
	if increment == "major":
		major += 1
		minor = 0
		patch = 0
	elif increment == "minor":
		minor += 1
		patch = 0
	else:
		patch += 1
	return f"v{major}.{minor}.{patch}"

def commit_tag_push(repo_dir: Path, branch: str, dist_dir: str, tag: str) -> None:
	git(repo_dir, "add", dist_dir)
	# Nothing to commit is fine (e.g. re-tagging unchanged dist/).
	subprocess.run(["git", "commit", "-m", f"release {tag}"], cwd=repo_dir)
	git(repo_dir, "tag", "-f", tag)
	git(repo_dir, "push", "origin", branch)
	git(repo_dir, "push", "-f", "origin", tag)

def gh_release(repo_dir: Path, tag: str) -> None:
	subprocess.run(
		["gh", "release", "create", tag, "--title", tag, "--notes", f"Release {tag}"],
		cwd=repo_dir,
		check=True,
	)

def build_manifest(repo_dir: Path, dist_dir: str, repo: str, tag: str) -> dict:
	dist = repo_dir / dist_dir
	targets_file = repo_dir / "targets.json"
	if not targets_file.is_file():
		sys.exit(f"Missing target configuration: {targets_file}")
	target_config = json.loads(targets_file.read_text())
	targets = {}
	for target, config in sorted(target_config.items()):
		files = {}
		for pattern in config.get("pull", []):
			matches = sorted(dist.glob(pattern))
			if not matches:
				sys.exit(f"Target '{target}': pull pattern matched no files: {pattern}")
			for path in matches:
				if not path.is_file(): continue
				rel = path.relative_to(dist).as_posix()
				url = f"https://raw.githubusercontent.com/{repo}/{tag}/{dist_dir}/{rel}"
				files[rel] = {"path": rel, "url": url}

		targets[target] = sorted(files.values(), key=lambda file: file["path"])
	return {"tag": tag, "targets": targets}

def load_signing_key(signing_key_hex: str) -> Ed25519PrivateKey:
	seed = bytes.fromhex(signing_key_hex)
	if len(seed) != 32:
		sys.exit("signing_key must be 32 bytes hex-encoded (64 hex chars)")
	return Ed25519PrivateKey.from_private_bytes(seed)

def sign_url(signing_key: Ed25519PrivateKey, url: str) -> str:
	data = url.encode()
	signature = signing_key.sign(data)
	return base64.b64encode(signature + data).decode()

def generate_keypair() -> tuple[str, str]:
	"""Generates a fresh Ed25519 keypair.

	Returns (signing_key_hex, pubkey_hex). signing_key_hex goes in
	config.json and must stay secret -- it's the only thing that can
	produce updates every computer will accept. pubkey_hex is safe to
	publish; it's what you pass to lua/install.lua on each computer.
	"""
	private_key = Ed25519PrivateKey.generate()
	seed = private_key.private_bytes_raw()
	pubkey = private_key.public_key().public_bytes_raw()
	return seed.hex(), pubkey.hex()

def main() -> None:
	parser = argparse.ArgumentParser()
	version_group = parser.add_mutually_exclusive_group()
	version_group.add_argument("--major", action="store_true", help="increment major version")
	version_group.add_argument("--minor", action="store_true", help="increment minor version")
	parser.add_argument("--repo-dir", default=".", help="repo root (default: cwd)")
	parser.add_argument("--gh-release", action="store_true", help="also create a GitHub Release via gh")
	parser.add_argument("--gen-keys", action="store_true", help="generate a new Ed25519 signing keypair and exit")
	parser.add_argument("--pubkey", action="store_true", help="print the public key for config.json's signing_key and exit")
	args = parser.parse_args()

	repo_dir = Path(args.repo_dir).resolve()

	if args.gen_keys:
		signing_key_hex, pubkey_hex = generate_keypair()
		print(f"signing_key (put in config.json, keep this private):\n{signing_key_hex}\n")
		print(f"pubkey (pass to lua/install.lua on every computer, safe to publish):\n{pubkey_hex}\n")
		return

	if args.pubkey:
		config = load_config(repo_dir)
		signing_key = load_signing_key(config["signing_key"])
		print(signing_key.public_key().public_bytes_raw().hex())
		return

	increment = "major" if args.major else "minor" if args.minor else "patch"
	args.tag = next_version(repo_dir, increment)

	config = load_config(repo_dir)

	print(f"Building {config['dist_dir']}/ from {config['src_dir']}/ ...")
	build_dist(repo_dir, config["src_dir"], config["dist_dir"])
	manifest = build_manifest(repo_dir, config["dist_dir"], config["repo"], args.tag)
	with open(f"{config["dist_dir"]}/manifest.json", "w") as f:
		json.dump(manifest, f)
	print(f"Tagging and pushing {args.tag} ...")
	commit_tag_push(repo_dir, config["branch"], config["dist_dir"], args.tag)
	if args.gh_release:
		gh_release(repo_dir, args.tag)

	manifest_url = (f"https://raw.githubusercontent.com/{config['repo']}/{args.tag}/{config['dist_dir']}/manifest.json")
	signing_key = load_signing_key(config["signing_key"])
	launcher_url = f"https://raw.githubusercontent.com/ItchyTrack/cc-bulk-flasher/main/lua/update.lua"
	payload_b64 = sign_url(signing_key, manifest_url)
	command = f"wget run {launcher_url} {shlex.quote(config['protocol'])} {payload_b64}"

	print(f"\n{len(manifest['targets'])} target(s): {', '.join(manifest['targets'])}")
	print(f"\nCommand ({len(command)} chars):\n{command}\n")

	if pyperclip is not None:
		try:
			pyperclip.copy(command)
			print("Copied to clipboard.")
		except Exception as exc:  # pyperclip has no clipboard backend, etc.
			print(f"Could not copy to clipboard ({exc}); command printed above.")
	else:
		print("pyperclip not installed; command printed above.")

if __name__ == "__main__":
	main()
