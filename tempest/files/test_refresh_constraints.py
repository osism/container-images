"""Tests for refresh_constraints.py.

Run with: cd tempest/files && pytest -v
Requires: pip install pytest
"""
from pathlib import Path
from unittest.mock import patch

import pytest

from refresh_constraints import (
    extract_constraints_url,
    parse_tempest_version,
    refresh,
)


def test_parse_tempest_version_exact_pin(tmp_path: Path) -> None:
    req = tmp_path / "requirements.txt"
    req.write_text("tempest==46.0.0\nextras\nbarbican-tempest-plugin\n")
    assert parse_tempest_version(req) == "46.0.0"


def test_parse_tempest_version_missing_pin(tmp_path: Path) -> None:
    req = tmp_path / "requirements.txt"
    req.write_text("extras\nbarbican-tempest-plugin\n")
    with pytest.raises(ValueError, match="No 'tempest==' pin found"):
        parse_tempest_version(req)


def test_parse_tempest_version_unpinned(tmp_path: Path) -> None:
    req = tmp_path / "requirements.txt"
    req.write_text("tempest>=46.0.0\n")
    with pytest.raises(ValueError, match="No 'tempest==' pin found"):
        parse_tempest_version(req)


_TOX_INI_SAMPLE = """\
[tox]
envlist = pep8,py3
minversion = 3.18.0

[testenv]
install_command = pip install \\
    -c{env:UPPER_CONSTRAINTS_FILE:https://releases.openstack.org/constraints/upper/2025.2} \\
    {opts} {packages}

[testenv:pep8]
deps =
    -c{env:UPPER_CONSTRAINTS_FILE:https://releases.openstack.org/constraints/upper/2025.2}
"""


def test_extract_constraints_url_returns_first_match() -> None:
    url = extract_constraints_url(_TOX_INI_SAMPLE)
    assert url == "https://releases.openstack.org/constraints/upper/2025.2"


def test_extract_constraints_url_missing() -> None:
    with pytest.raises(ValueError, match="UPPER_CONSTRAINTS_FILE"):
        extract_constraints_url("[tox]\nenvlist = py3\n")


_CONSTRAINTS_BODY = "oslo.utils===8.2.0\nrequests===2.32.3\n"


def _fake_fetch(url: str) -> str:
    if url.endswith("/openstack/tempest/46.0.0/tox.ini"):
        return _TOX_INI_SAMPLE
    if url == "https://releases.openstack.org/constraints/upper/2025.2":
        return _CONSTRAINTS_BODY
    raise AssertionError(f"unexpected URL: {url}")


def test_refresh_writes_constraints_file(tmp_path: Path) -> None:
    req = tmp_path / "requirements.txt"
    req.write_text("tempest==46.0.0\nextras\n")
    out = tmp_path / "upper-constraints.txt"

    with patch("refresh_constraints.fetch", side_effect=_fake_fetch):
        refresh(requirements_path=req, output_path=out)

    assert out.read_text() == _CONSTRAINTS_BODY


def test_refresh_propagates_404_on_tox_ini(tmp_path: Path) -> None:
    from urllib.error import HTTPError
    req = tmp_path / "requirements.txt"
    req.write_text("tempest==99.99.99\n")
    out = tmp_path / "upper-constraints.txt"

    def fake_fetch(url: str) -> str:
        raise HTTPError(url, 404, "Not Found", hdrs=None, fp=None)

    with patch("refresh_constraints.fetch", side_effect=fake_fetch):
        with pytest.raises(HTTPError):
            refresh(requirements_path=req, output_path=out)

    assert not out.exists()
