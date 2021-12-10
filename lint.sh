#!/bin/bash

# yamllint
find . -regex '.*.yml' -exec yamllint {} +

# ansible-lint
ansible-lint ./*yml
