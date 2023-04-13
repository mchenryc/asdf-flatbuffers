<div align="center">

# asdf-flatbuffers [![Build](https://github.com/mchenryc/asdf-flatbuffers/actions/workflows/build.yml/badge.svg)](https://github.com/mchenryc/asdf-flatbuffers/actions/workflows/build.yml) [![Lint](https://github.com/mchenryc/asdf-flatbuffers/actions/workflows/lint.yml/badge.svg)](https://github.com/mchenryc/asdf-flatbuffers/actions/workflows/lint.yml)


[flatbuffers](https://flatbuffers.dev/) plugin for the [asdf version manager](https://asdf-vm.com).

</div>

# Contents

- [Dependencies](#dependencies)
- [Install](#install)
- [Contributing](#contributing)
- [License](#license)

# Dependencies

- `bash`, `curl`, `jq`, `unzip`: generic POSIX utilities.
- `SOME_ENV_VAR`: set this environment variable in your shell config to load the correct version of tool x.

# Install

This plugin needs `unzip` and `jq` to be installed.

If you have a Debian system you can install unzip it by typing:
`sudo apt-get install unzip`

Install jq with `asdf plugin add jq`

Plugin:

```shell
asdf plugin add flatbuffers
# or
asdf plugin add flatbuffers https://github.com/mchenryc/asdf-flatbuffers.git
```

flatbuffers:

```shell
# Show all installable versions
asdf list-all flatbuffers

# Install specific version
asdf install flatbuffers latest

# Set a version globally (on your ~/.tool-versions file)
asdf global flatbuffers latest

# Now flatbuffers commands are available
flatc --version
```

Check [asdf](https://github.com/asdf-vm/asdf) readme for more instructions on how to
install & manage versions.

# Contributing

Contributions of any kind welcome! See the [contributing guide](contributing.md).

[Thanks goes to these contributors](https://github.com/mchenryc/asdf-flatbuffers/graphs/contributors)!

# License

See [LICENSE](LICENSE) © [mchenryc](https://github.com/mchenryc/)
