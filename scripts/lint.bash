#!/usr/bin/env bash

SHFMT_ACTION=${SHFMT_ACTION:-"--diff"}

[[ "${SHFMT_ACTION}" == "--diff" ]] \
  && shellcheck --shell=bash \
    --external-sources \
    --source-path=lib/ \
    --source-path=scripts/ \
    bin/* \
    lib/* \
    scripts/*

shfmt --language-dialect bash "${SHFMT_ACTION}" \
  -i 2 -ci -bn \
  ./bin/* \
  ./lib/* \
  ./scripts/*
