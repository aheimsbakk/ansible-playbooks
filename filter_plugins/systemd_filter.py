#!/usr/bin/python
from __future__ import (absolute_import, division, print_function)
__metaclass__ = type

class FilterModule(object):
    def filters(self):
        return {
            'systemd_escape': self.systemd_escape
        }

    def systemd_escape(self, value, path=False, force_absolute=False):
        """
        :param value: The string to escape
        :param path: If True, behaves like 'systemd-escape --path'
        :param force_absolute: If True, absolute paths like '/var' become '-var'
                               (preserving the leading slash as a dash).
        """
        if not value:
            return ""

        # ---------------------------------------------------------
        # MODE 1: Path Escaping (--path)
        # ---------------------------------------------------------
        if path:
            # Handle root/multiple slash edge cases (e.g. "/" or "//" -> "-")
            # If the path is just slashes, systemd returns "-"
            if value.replace("/", "") == "":
                return "-"

            clean_val = value

            # Standard systemd behavior: Remove leading/trailing slashes
            if not force_absolute:
                clean_val = value.strip('/')

            # If force_absolute is On: Only strip TRAILING slashes, keep LEADING.
            else:
                clean_val = value.rstrip('/')
                # If it started with /, ensure the first char becomes -
                # The loop below handles replacing '/' with '-', so we just keep it.

            result = []
            for char in clean_val:
                if char == '/':
                    result.append('-')
                elif char == '-' or char == '\\' or not (char.isalnum() or char in '._:'):
                    # Escape existing dashes and special chars
                    result.append("\\x{:02x}".format(ord(char)))
                else:
                    result.append(char)

            return "".join(result)

        # ---------------------------------------------------------
        # MODE 2: Standard Escaping (default)
        # ---------------------------------------------------------
        else:
            result = []
            for i, char in enumerate(value):
                if char.isalnum() or char in ':_-':
                    result.append(char)
                elif char == '.' and i > 0:
                    result.append(char)
                else:
                    result.append("\\x{:02x}".format(ord(char)))
            return "".join(result)
