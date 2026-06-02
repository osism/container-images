# SPDX-License-Identifier: Apache-2.0

import sys
import yaml
import os
from typing import Any, Dict, Optional, Union

from ansiblelint.file_utils import Lintable
from ansiblelint.rules import AnsibleLintRule

_RULES_DIR = os.path.dirname(os.path.abspath(__file__))


class OsismFQCNRule(AnsibleLintRule):
    """Use FQCN for all actions."""

    id = "osism-fqcn"
    severity = "MEDIUM"
    description = "Check whether the long version is used in the playbook"
    tags = ["formatting", "osism"]

    # WARNING  Rule ... has an invalid version_changed field '', is should be a 'X.Y.Z' format value.
    version_changed = "0.0.1"

    def matchtask(
        self, task: Dict[str, Any], file: Optional[Lintable] = None
    ) -> Union[bool, str]:

        with open(
            os.path.join(_RULES_DIR, "osism_fqcn_list.yaml"), "r"
        ) as fileStream:
            try:
                osism_fqcn_list = yaml.safe_load(fileStream)
            except yaml.YAMLError as exception:
                print(exception)
                sys.exit(0)

        # block/rescue/always aren't real modules; ansible-lint sets their action to this fixed string
        module = task["action"]["__ansible_module_original__"]
        if module == "block/always/rescue":
            return False

        for category in osism_fqcn_list:
            if module in osism_fqcn_list[category]:
                return False
        return True
