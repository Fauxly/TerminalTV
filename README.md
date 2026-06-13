# TerminalTV

<p align="center">
  <img src="docs/logo.png" alt="TerminalTV" width="600">
</p>

<p align="center">
  <strong>A Real Shell Terminal for Apple TV (tvOS)</strong>
</p>

<p align="center">
  Run shell commands, manage files, and access the tvOS filesystem directly from your Apple TV.
</p>

---

## Overview

TerminalTV is a native tvOS terminal application designed specifically for Apple TV.

Unlike traditional file managers, TerminalTV provides access to a real shell environment, allowing you to execute system commands, browse the filesystem, manage files, and interact with your device through a clean and lightweight terminal interface.

---

## Features

### Terminal

* Real shell command execution (`/bin/sh`)
* Command history support
* Built-in terminal commands
* Keyboard support
* Fast and lightweight interface

### File Management

* Browse directories
* Create and delete files
* Create and remove folders
* Copy and move files
* View file contents
* Access the tvOS filesystem

### Web File Manager

* Upload files from any browser
* Download files directly from Apple TV
* Delete files remotely
* Browse files through a web interface

### System Access

Examples of supported commands:

```bash
pwd
whoami
id
uname -a
ps aux
which sh
find
env
ls -la /
```

Access to common system paths:

```text
/
├── Applications
├── Library
├── System
├── private
├── usr
└── var
```

---

## Screenshots

Add screenshots here.

| Terminal   | File Manager |
| ---------- | ------------ |
| Screenshot | Screenshot   |

---

## Installation

### Build from Source

```bash
git clone https://github.com/Fauxly/TerminalTV.git
cd TerminalTV
```

Open the project in Xcode and build for tvOS.

---

## Requirements

* Apple TV
* tvOS 15.0+
* Xcode 15+
* Swift 5+

---

## Roadmap

### Version 1.1

* Command auto-completion
* Colored terminal output
* Additional built-in commands
* Improved file manager

### Version 1.2

* SSH Client
* SFTP Support
* SCP File Transfers

### Version 2.0

* Multiple terminal tabs
* File editor
* Plugin support
* Advanced networking tools

---

## Why TerminalTV?

* Built specifically for Apple TV
* Real shell environment
* Simple and lightweight
* Native Swift implementation
* Designed for developers, power users, and jailbreak enthusiasts

---

## Contributing

Contributions, bug reports, and feature requests are welcome.

Feel free to open an issue or submit a pull request.

---

## License

MIT License

---
