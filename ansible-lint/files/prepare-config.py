# SPDX-License-Identifier: Apache-2.0

import hiyapyco

conf = hiyapyco.load(
    "/zuul/.ansible-lint",
    "/ansible-lint.yml",
    method=hiyapyco.METHOD_MERGE,
    interpolate=True,
    failonmissingfiles=True,
)

with open("/zuul/.ansible-lint", "w+") as fp:
    fp.write(hiyapyco.dump(conf,
                           default_flow_style=True,
                           explicit_start=True))
