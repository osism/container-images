"""OSISM Django settings for the ARA server.

Loads ARA's own settings and replaces only the password hasher.

ARA authenticates the API with HTTP Basic: the callback sends the password on
every request and Django verifies it every time. With Django's default PBKDF2
(1,000,000 iterations since Django 5.2) each request costs ~350 ms of CPU and
blocks a gunicorn worker, which roughly doubles the run time of a playbook
with the ARA callback enabled.

PBKDF2 stretching protects low-entropy human passwords. The OSISM ara
password is a generated random machine secret, which stretching does not
make meaningfully stronger, so the iteration count is lowered to 1000
(Django's historical minimum).

Stored hashes convert automatically: after a successful login Django
re-hashes the password when the stored iteration count differs from the
hasher's, so an existing user's 1,000,000-iteration hash is replaced on the
first authenticated request.

OSISM_ARA_PBKDF2_ITERATIONS overrides the count, e.g. for measurements.
"""

import os

from django.contrib.auth.hashers import PBKDF2PasswordHasher

from ara.server.settings import *  # noqa: F401,F403

_iterations = os.environ.get("OSISM_ARA_PBKDF2_ITERATIONS", "1000")
try:
    PBKDF2_ITERATIONS = int(_iterations)
except ValueError:
    raise ValueError(
        f"OSISM_ARA_PBKDF2_ITERATIONS must be a positive integer, got: {_iterations!r}"
    )
if PBKDF2_ITERATIONS < 1:
    raise ValueError(
        f"OSISM_ARA_PBKDF2_ITERATIONS must be a positive integer, got: {_iterations!r}"
    )


class OsismPBKDF2PasswordHasher(PBKDF2PasswordHasher):
    iterations = PBKDF2_ITERATIONS


# Only this hasher: it shares the algorithm name "pbkdf2_sha256" with
# Django's PBKDF2PasswordHasher, and Django looks hashers up by that name,
# so listing the stock class as well could make it the one that verifies
# (and re-hashes) stored passwords.
PASSWORD_HASHERS = ["osism_ara.settings.OsismPBKDF2PasswordHasher"]
