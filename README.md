# Proxmox Wi-Fi Edition

An experimental project to add Wi-Fi installation and host-networking support for the **Apple Mac mini (Late 2014, Macmini7,1)** running Proxmox VE.

The initial hardware target is the Mac mini's **Broadcom BCM4360** wireless adapter. The goal is to make it possible to install and manage Proxmox VE on this machine using Wi-Fi when an Ethernet connection is unavailable.

> **Project status: Early development / research.** This is not an official Proxmox project or a supported Proxmox VE distribution. Compatibility, installer integration, and upgrade behaviour are still being investigated. Do not use experimental images on systems containing data you cannot afford to lose.

## Goals

- Detect the target Mac mini hardware reliably during installation.
- Investigate and integrate the appropriate Broadcom BCM4360 driver and firmware where licensing and distribution requirements permit.
- Provide an installer workflow for selecting a wireless network and entering its credentials.
- Configure Wi-Fi so that host networking remains available after installation and reboot.
- Preserve Ethernet installation and networking as a fallback.
- Keep the build reproducible, documented, and verifiable.
- Track compatibility against the latest stable Proxmox VE release, verifying the actual release and ISO before each build.

## Target hardware

| Component | Initial target |
|---|---|
| Computer | Apple Mac mini (Late 2014) |
| Model identifier | Macmini7,1 |
| Wireless chipset | Broadcom BCM4360 |
| Wireless interface | To be detected and verified on the target system |
| Proxmox VE | Latest stable release, selected and recorded at build time |

Other Mac models and wireless chipsets are outside the initial support scope.

## Important networking notes

A Wi-Fi client interface does not behave exactly like a wired Ethernet interface. In particular, ordinary Wi-Fi client mode generally cannot be used as a transparent Linux bridge for virtual machines in the same way as Ethernet.

The project will therefore distinguish between:

- **Host connectivity:** connecting the Proxmox host to a wireless network for management and internet access.
- **Guest connectivity:** a separately designed routed or NAT-based approach where required.

A wired Ethernet connection remains the recommended option for clusters, high-availability deployments, and workloads that require conventional bridged networking.

## Development approach

The implementation will be developed and tested in stages:

1. **Baseline and hardware audit** — record the official Proxmox VE release, inspect its installer and kernel, and identify the Mac mini's exact PCI and wireless hardware.
2. **Build environment** — create documented build and verification scripts on the Linux development machine.
3. **Driver compatibility** — determine a maintainable, legally distributable way to support the BCM4360 on the selected Proxmox kernel.
4. **Installer integration** — design and implement wireless detection, network selection, credential handling, and connection setup.
5. **Installed-system persistence** — verify that wireless networking survives installation, reboot, and normal network service operation.
6. **Hardware testing** — test installation and recovery on the actual Mac mini, retaining an Ethernet fallback.
7. **Release preparation** — publish reproducible build instructions, checksums, known limitations, and test results.

No specific driver packaging method or installer patch is considered final until it has been checked against the selected official ISO and kernel.

## Repository layout

The repository will grow as the implementation is validated. The planned structure is:

```text
.
├── build/          # ISO acquisition, verification, and build tooling
├── drivers/        # Driver integration research and packaging
├── installer/      # Installer detection and Wi-Fi workflow
├── patches/        # Reviewed patches against upstream components
├── scripts/        # Hardware audit and maintenance utilities
├── tests/          # Automated and hardware test procedures
├── docs/           # Design notes, compatibility, and troubleshooting
└── .github/
    └── workflows/ # Continuous integration
```

## Safety and data

- Back up all important data before installing or testing an image.
- Testing may require erasing the Mac mini's internal storage. No disk-wipe or installation step should be run without confirming the target disk and backing up its contents.
- Keep a known-good official Proxmox VE installer available for recovery.
- Never publish Wi-Fi passwords, private keys, tokens, or other credentials in this repository or in build logs.

## Building

Build instructions will be added after the official ISO, build dependencies, and driver integration method have been verified. Until then, there is no supported release build procedure.

## Contributing and issue reports

Early contributions should focus on reproducible hardware information, compatibility findings, and clearly documented test results. Please include the exact Proxmox VE release, installer image checksum, kernel version, Mac model identifier, and relevant hardware IDs when reporting a problem. Remove personal information and network credentials from logs.

## Disclaimer

Proxmox Wi-Fi Edition is an independent community project. It is not affiliated with, endorsed by, or supported by Proxmox Server Solutions GmbH or Apple Inc. Proxmox VE and related trademarks belong to their respective owners. Any third-party driver remains subject to its own licence and distribution terms.
