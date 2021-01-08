#!/bin/bash
find -regex .*.yml -exec yamllint {} +
