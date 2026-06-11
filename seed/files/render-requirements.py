#!/usr/bin/env python3
"""Render a galaxy requirements.yml for a pinned OSISM release.

Fetches the release manifest (base.yml) from osism/release, validates
it, and writes requirements.yml plus a .osism-set-info marker into the
given collection set directory. Exits non-zero on any problem: a
broken collection set must never ship silently.
"""

import os
import sys
import urllib.request

import yaml

RELEASE_URL_TEMPLATE = os.environ.get(
    "SEED_RELEASE_URL_TEMPLATE",
    "https://raw.githubusercontent.com/osism/release/main/{version}/base.yml",
)

COLLECTION_REPOSITORIES = [
    ("https://github.com/osism/ansible-collection-commons.git", "osism.commons"),
    ("https://github.com/osism/ansible-collection-services.git", "osism.services"),
]


def main():
    if len(sys.argv) != 3:
        sys.exit("usage: render-requirements.py VERSION OUTPUT_DIR")
    version, output_dir = sys.argv[1], sys.argv[2]

    url = RELEASE_URL_TEMPLATE.format(version=version)
    try:
        with urllib.request.urlopen(url) as response:
            manifest = yaml.safe_load(response)
    except Exception as exc:
        sys.exit(f"cannot fetch release manifest {url}: {exc}")

    if str(manifest.get("manager_version")) != version:
        sys.exit(
            f"manifest {url} is for manager_version "
            f"{manifest.get('manager_version')!r}, expected {version!r}"
        )

    try:
        collections = [
            {
                "name": repository,
                "type": "git",
                "version": f"v{manifest['ansible_collections'][name]}",
            }
            for repository, name in COLLECTION_REPOSITORIES
        ]
        collections.append(
            {
                "name": "https://github.com/osism/ansible-playbooks-manager.git",
                "type": "git",
                "version": str(manifest["manager_playbooks_version"]),
            }
        )
        set_info = {
            "manager_version": version,
            "ansible_core_version": str(manifest["ansible_core_version"]),
        }
    except KeyError as exc:
        sys.exit(f"manifest {url} is missing {exc}")

    os.makedirs(output_dir, exist_ok=True)
    with open(os.path.join(output_dir, "requirements.yml"), "w") as fp:
        yaml.safe_dump({"collections": collections}, fp, sort_keys=False)
    with open(os.path.join(output_dir, ".osism-set-info"), "w") as fp:
        yaml.safe_dump(set_info, fp, sort_keys=False)


if __name__ == "__main__":
    main()
