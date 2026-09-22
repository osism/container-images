# Carried patches for the ceph-daemon image

Build-time patches applied to the Ceph code inside the `ceph-daemon` image,
kept per Ceph release series. A patch lives here when the image needs a change
the released Ceph it builds on does not have. That change may be merged
upstream and not yet released, proposed and not yet merged, or specific to
OSISM and never headed upstream at all -- the directory treats them alike.

Everything below is the convention the build enforces. The patches currently in
the tree are used as examples; they are not the subject.

## Layout

    patches/v<major>/NNNN-<name>.patch

`<major>` comes from the image's `VERSION` (`${VERSION%%.*}`), so a `v19.2.6`
build reads `patches/v19/`. A series with no directory is built unpatched, and
that is the normal state — not an error.

**Remove a patch once the image no longer needs it**, and the series directory
with the last of them. For a change headed upstream that is when a release in
the series carries it; a patch that is OSISM's own has no such end and stays
while the need does. Leaving a patch behind after its reason has gone means
either one that no longer applies, failing the build, or one that still applies
and silently re-carries something the upstream code has since revised.

## The NNNN- prefix is a contract with the build

The number selects *how* a patch is applied, because the targets live in
different places. It is not ordering decoration:

| prefix | target | how it is applied |
|---|---|---|
| `0001` | a module inside the `cephadm` zipapp | in the unpacked zipapp, at its root |
| `0002` | the zipapp's `__main__.py` | in the unpacked zipapp, targeted at that member |
| `0003` | `/usr/share/ceph/mgr/cephadm/*.py` | plain source on disk, patched directly |

A patch under a new prefix needs a matching loop in the Containerfile.
Adding the file alone is not enough — but it is also not silently ignored: the
build counts what it applied and asserts that count equals the number of
`*.patch` files present, so an unmatched file fails the build.

**A series need not carry every prefix.** What a series needs depends on how
that Ceph version happens to be structured, so compare against the series you
are working on rather than against its neighbours. The current carry
illustrates this: `v19` and `v20` have all three, while `v18` has no `0001`,
because reef's cephadm is a single-file zipapp with no `cephadmlib/` and the
change that `0001` makes elsewhere has nowhere to go but `__main__.py`. A
missing number there is correct, not an omission to repair.

## Why the zipapp needs unpacking

`/usr/sbin/cephadm` ships as a zipapp rather than a script, so `patch -p1`
cannot reach its members. The build unpacks it, applies the `0001`/`0002`
patches, repacks with `zipapp.create_archive`, and deletes the `.pyc` siblings
of the patched members so stale bytecode cannot be what actually runs. The
shebang is preserved byte-for-byte, including its leading space.

This is a property of how cephadm is shipped, so it applies to any patch
targeting it, whatever the patch is for.

## Generating and regenerating a series

Patches are `git diff` snapshots of a branch in a ceph worktree. Take them at
the branch's **current HEAD**, not from an older snapshot: a stale patch
validates code the branch no longer contains, which defeats the build's own
verification.

Per target, from the worktree:

    git diff <base>..HEAD -- <path-in-ceph>  > NNNN-<name>.patch

piping each through `sed 's|/<prefix>/|/|g'` so the paths match where the build
applies them, and excluding test directories from a diff that would otherwise
sweep them in.

`<base>` is **the release tag the image builds for that series** — each series
is diffed against its own version, not against a tag shared across series.

## Verification

Applying cleanly proves nothing about behaviour, so the Containerfile's
verification step loads the packaged code and executes it rather than grepping
for strings, and is gated to the series that actually carry patches.

A carry should assert the behaviour it exists to produce, and should reach
every file it touches — it is easy to assert two of four patched files and
believe the set is covered. After a local rebuild, confirm at minimum that
`applied == total` for the series, that the repacked zipapp carries the patched
members and no stale `.pyc`, and that the verification step passes.

Note for local builds: the image's `chgrp`/`chown` ownership-fix stage fails
under rootless podman, identically on unmodified `main`. Neutralise those lines
in a scratch copy to rebuild locally; it is unrelated to any patch here.
