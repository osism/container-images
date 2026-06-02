# SPDX-License-Identifier: Apache-2.0

import hiyapyco

conf = hiyapyco.load(
    "/zuul/.ansible-lint",
    "/ansible-lint.yml",
    method=hiyapyco.METHOD_MERGE,
    interpolate=True,
    failonmissingfiles=True,
)

# Always use the rules baked into the image; ignore any repo-local rulesdir
# (which would point at a path we no longer create inside the mount).
conf["rulesdir"] = ["/opt/osism/ansible-lint-rules"]

with open("/tmp/ansible-lint.yml", "w+") as fp:
    fp.write(hiyapyco.dump(conf,
                           default_flow_style=True,
                           explicit_start=True))
