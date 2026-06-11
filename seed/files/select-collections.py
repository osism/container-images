#!/usr/bin/env python3
"""Select the collection set matching the mounted configuration repository.

Prints the path of the selected set on stdout (consumed by run.sh);
all diagnostics go to stderr. Exit 1 means no safe selection exists.

Resolution order: MANAGER_VERSION env, else manager_version from the
mounted configuration repository, else 'latest'. The 'latest' fallback
is reserved for genuinely-absent configuration (missing file, or
absent/null key); an unreadable or malformed configuration hard-fails.
USE_NON_MATCHING_COLLECTIONS=<set> forcibly selects a baked set with a
loud warning; it is the emergency override for version skew.

With --build-check, instead compares every baked set's pinned
ansible-core line against the bundled ansible-core and prints a notice
on mismatch (always exits 0; old-release compatibility is best-effort
by design).
"""

import os
import sys

import yaml

COLLECTIONS_ROOT = os.environ.get("SEED_COLLECTIONS_ROOT", "/opt/collections")
CONFIGURATION_FILE = os.environ.get(
    "SEED_CONFIGURATION_FILE",
    "/opt/configuration/environments/manager/configuration.yml",
)
REMEDIATION = (
    "Fix the configuration or set MANAGER_VERSION explicitly "
    "(it takes precedence and skips reading the configuration)."
)


def log(message):
    print(message, file=sys.stderr)


def fail(message):
    log(f"ERROR: {message}")
    sys.exit(1)


def available_sets():
    try:
        return sorted(
            entry
            for entry in os.listdir(COLLECTIONS_ROOT)
            if os.path.isdir(os.path.join(COLLECTIONS_ROOT, entry))
        )
    except OSError:
        return []


def core_line(version):
    return ".".join(str(version).split(".")[:2])


def set_core_version(name):
    try:
        with open(os.path.join(COLLECTIONS_ROOT, name, ".osism-set-info")) as fp:
            return str(yaml.safe_load(fp)["ansible_core_version"])
    except Exception:
        return None


def running_core_version():
    try:
        from ansible.release import __version__
    except ImportError:
        return None
    return __version__


def resolve(strict):
    """Return (version, source) wanted by the configuration.

    With strict=False (used for the override's diagnostic output),
    return (None, None) instead of failing on malformed configuration.
    """
    manager_version = os.environ.get("MANAGER_VERSION")
    if manager_version:
        return manager_version, "MANAGER_VERSION"
    if not os.path.exists(CONFIGURATION_FILE):
        return "latest", "default, no configuration.yml"
    try:
        with open(CONFIGURATION_FILE) as fp:
            configuration = yaml.safe_load(fp)
    except Exception as exc:
        if not strict:
            return None, None
        fail(f"cannot read {CONFIGURATION_FILE}: {exc}\n{REMEDIATION}")
    if configuration is None:
        return "latest", "default, empty configuration.yml"
    if not isinstance(configuration, dict):
        if not strict:
            return None, None
        fail(f"{CONFIGURATION_FILE} is not a mapping\n{REMEDIATION}")
    manager_version = configuration.get("manager_version")
    if manager_version is None:
        return "latest", "default, manager_version not set"
    if isinstance(manager_version, (dict, list)):
        if not strict:
            return None, None
        fail(
            f"manager_version in {CONFIGURATION_FILE} is not a scalar: "
            f"{manager_version!r}\n{REMEDIATION}"
        )
    return str(manager_version), "configuration.yml"


def warn_on_core_mismatch(name, running):
    pinned = set_core_version(name)
    if not pinned or not running:
        return
    if core_line(pinned) == core_line(running):
        return
    log(
        f"WARNING: collections for release {name} were released against\n"
        f"ansible-core {core_line(pinned)}; this image runs ansible-core "
        f"{core_line(running)}.\nCompatibility is best-effort."
    )


def build_check():
    running = running_core_version()
    for name in available_sets():
        warn_on_core_mismatch(name, running)
    sys.exit(0)


def main():
    if len(sys.argv) > 1 and sys.argv[1] == "--build-check":
        build_check()

    override = os.environ.get("USE_NON_MATCHING_COLLECTIONS")
    sets = available_sets()

    if override:
        if override not in sets:
            fail(
                f"USE_NON_MATCHING_COLLECTIONS={override!r} does not name a "
                f"collection set in this image.\n"
                f"Available sets: {' '.join(sets)}"
            )
        detected, _ = resolve(strict=False)
        log(
            f"WARNING: USE_NON_MATCHING_COLLECTIONS forces collection set "
            f"'{override}'\nwhile the configuration wants "
            f"'{detected or 'unknown (configuration unreadable)'}'.\n"
            f"Running role code from a different release than the deployed "
            f"images\ncan fail in subtle ways. You asked for this."
        )
        selected, source = override, "USE_NON_MATCHING_COLLECTIONS"
    else:
        selected, source = resolve(strict=True)
        if selected not in sets:
            fail(
                f"no collection set for manager_version '{selected}' in this "
                f"image.\nAvailable sets: {' '.join(sets)}\n"
                f"Your configuration pins images for release {selected}; "
                f"running role code\nfrom a different release against those "
                f"images can fail in subtle ways.\n"
                f"To proceed anyway, restart with: "
                f"USE_NON_MATCHING_COLLECTIONS=<set>"
            )

    log(f"Using collection set {selected} (from {source})")
    warn_on_core_mismatch(selected, running_core_version())
    print(os.path.join(COLLECTIONS_ROOT, selected))


if __name__ == "__main__":
    main()
