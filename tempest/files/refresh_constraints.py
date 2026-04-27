"""Refresh tempest/files/upper-constraints.txt from the pinned tempest tag.

Reads the tempest version pin from requirements.txt, fetches that tag's
tox.ini from openstack/tempest on GitHub, extracts the UPPER_CONSTRAINTS_FILE
URL, downloads the constraints file, and writes it to the target path.

Pure stdlib so it runs anywhere with Python 3.
"""
import argparse
import re
import sys
from pathlib import Path
from urllib.request import urlopen

_TEMPEST_PIN_RE = re.compile(r"^tempest==(\S+)\s*$", re.MULTILINE)
_CONSTRAINTS_URL_RE = re.compile(r"UPPER_CONSTRAINTS_FILE:([^}]+)")


def parse_tempest_version(requirements_path: Path) -> str:
    """Return the version pinned by `tempest==X.Y.Z` in requirements_path.

    Raises ValueError if no exact pin is present.
    """
    text = requirements_path.read_text()
    match = _TEMPEST_PIN_RE.search(text)
    if not match:
        raise ValueError(
            f"No 'tempest==' pin found in {requirements_path}"
        )
    return match.group(1)


def extract_constraints_url(tox_ini_text: str) -> str:
    """Return the first UPPER_CONSTRAINTS_FILE URL found in tox.ini text.

    tempest's tox.ini repeats the same URL across multiple testenv sections;
    the first match is canonical. Raises ValueError if none is present.
    """
    match = _CONSTRAINTS_URL_RE.search(tox_ini_text)
    if not match:
        raise ValueError(
            "No UPPER_CONSTRAINTS_FILE entry found in tox.ini"
        )
    return match.group(1).strip()


_TEMPEST_TOX_URL = (
    "https://raw.githubusercontent.com/openstack/tempest/{version}/tox.ini"
)


def fetch(url: str) -> str:
    """Fetch a URL and return its body as text. Raises on HTTP errors."""
    with urlopen(url) as response:
        return response.read().decode("utf-8")


def refresh(requirements_path: Path, output_path: Path) -> None:
    """Refresh output_path with constraints for the tempest version pinned
    in requirements_path."""
    version = parse_tempest_version(requirements_path)
    tox_ini = fetch(_TEMPEST_TOX_URL.format(version=version))
    constraints_url = extract_constraints_url(tox_ini)
    constraints = fetch(constraints_url)
    output_path.write_text(constraints)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--requirements",
        type=Path,
        default=Path(__file__).parent / "requirements.txt",
        help="Path to requirements.txt (default: alongside this script)",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=Path(__file__).parent / "upper-constraints.txt",
        help="Path to write the constraints file (default: alongside this script)",
    )
    args = parser.parse_args(argv)
    refresh(requirements_path=args.requirements, output_path=args.output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
