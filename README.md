# All in One
Server Utilities & Automation Toolkit for Ubuntu/Debian.

A clean, modular, interactive CLI menu for common VPS/server tasks: updates, essentials, security hardening, firewall, networking tools, Docker, logs, and Optimizations.

## Quick Install (one-liner)
```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/Salarsdg/All-in-one/Stage/install.sh)"
```

## Run
```bash
sudo all-in-one
```

Or:
```bash
cd /opt/all-in-one
sudo bash main.sh
```

## Features
- Interactive modern menu (ASCII + colors)
- Modular structure (`modules/`)
- Logging (`logs/all-in-one.log`)
- Symlink-safe BASE_DIR resolution (works when executed via `/usr/local/bin/all-in-one`)
- Ubuntu/Debian (APT)

## Optimize & Tuning
From the menu: `Optimize & Tuning`
- Enable BBR
- Swap manager
- Network Optimization (Recommended)
- SSH Optimization (Recommended)
- System Limits Optimization
- Disable terminal ads
- Limit journald disk usage
- Optimization status
- **Optimize Everything (Recommended)** (runs the recommended items in order)

## Notes
- This tool uses *recommended* defaults. Anything risky (kernel switching, extreme sysctl) is intentionally excluded by default.

## License
MIT (recommended)
