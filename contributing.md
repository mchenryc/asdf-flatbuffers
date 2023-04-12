# Contributing

Testing Locally:

```shell
asdf plugin test <plugin-name> <plugin-url> [--asdf-tool-version <version>] [--asdf-plugin-gitref <git-ref>] [test-command*]

#
asdf plugin test flatbuffers https://github.com/mchenryc/asdf-flatbuffers.git "flatc --version"
```

Tests are automatically run in GitHub Actions on push and PR.
