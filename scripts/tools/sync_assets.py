"""Mount purchased assets from the private Kubik-assets repo into the game.

Copies <Kubik-assets>/game/  ->  <Kubik>/assets/purchased/   (git-ignored)

The public Kubik repo never contains purchased content; this script is the
one bridge. The game must always run when assets/purchased/ is absent -
purchased art is a drop-in layer, never a dependency.

Usage:
    python scripts/tools/sync_assets.py            # sibling ../Kubik-assets
    python scripts/tools/sync_assets.py --from D:/path/to/Kubik-assets
    KUBIK_ASSETS_DIR=/srv/Kubik-assets python scripts/tools/sync_assets.py

True sync with a manifest: only files this script itself copied are ever
pruned, so a rename in the assets repo cannot leave a stale twin behind,
while everything Godot derives inside the mount (extracted textures,
.import sidecars) is left alone.
"""
import json
import os
import shutil
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DEST = os.path.join(ROOT, "assets", "purchased")


def source_dir(argv):
    if "--from" in argv:
        return os.path.abspath(argv[argv.index("--from") + 1])
    env = os.environ.get("KUBIK_ASSETS_DIR")
    if env:
        return os.path.abspath(env)
    return os.path.join(os.path.dirname(ROOT), "Kubik-assets")


def main():
    src_repo = source_dir(sys.argv[1:])
    src = os.path.join(src_repo, "game")
    if not os.path.isdir(src):
        print("[sync_assets] no assets to mount: %s not found" % src)
        print("[sync_assets] clone the private repo next to Kubik:")
        print("    git clone https://github.com/FrostyyTiger/Kubik-assets %s" % src_repo)
        return 1

    manifest_path = os.path.join(DEST, ".sync_manifest.json")
    old_manifest = []
    if os.path.exists(manifest_path):
        try:
            old_manifest = json.load(open(manifest_path))
        except (ValueError, OSError):
            old_manifest = []

    copied, removed, kept = 0, 0, 0
    new_manifest = []
    for dirpath, _dirs, files in os.walk(src):
        rel = os.path.relpath(dirpath, src)
        out = os.path.join(DEST, rel) if rel != "." else DEST
        os.makedirs(out, exist_ok=True)
        for f in files:
            s = os.path.join(dirpath, f)
            d = os.path.join(out, f)
            new_manifest.append(os.path.join(rel, f) if rel != "." else f)
            st = os.stat(s)
            if os.path.exists(d):
                dt = os.stat(d)
                if dt.st_size == st.st_size and dt.st_mtime >= st.st_mtime:
                    kept += 1
                    continue
            shutil.copy2(s, d)
            copied += 1

    # prune only what a previous sync copied and the source no longer has;
    # a pruned asset takes its Godot .import sidecar with it
    gone = set(old_manifest) - set(new_manifest)
    for rel in sorted(gone):
        for victim in (os.path.join(DEST, rel), os.path.join(DEST, rel + ".import")):
            if os.path.exists(victim):
                os.remove(victim)
                removed += 1
    for dirpath, dirs, _files in os.walk(DEST, topdown=False):
        for dd in dirs:
            full = os.path.join(dirpath, dd)
            if not os.listdir(full):
                os.rmdir(full)

    with open(manifest_path, "w") as f:
        json.dump(sorted(new_manifest), f, indent=0)

    print("[sync_assets] mounted %s -> %s" % (src, DEST))
    print("[sync_assets] copied %d, unchanged %d, pruned %d" % (copied, kept, removed))
    return 0


if __name__ == "__main__":
    sys.exit(main())
