# Contributing to Phoenix privacy architecture Linux implementation (beta) 🐦‍🔥

**Phoenix for Linux is not currently accepting contributions.** In the future, this may be allowed under a CLA, to protect [Wild Blue](https://thewild.blue)'s ability to incorporate Phoenix into a proprietary product. You are, of course, free to fork and modify it, in accordance with the license terms. Issues and PRs are welcome. Looking at you, security people.

## Design of scripts

- Operate from: Absolute directories (typically admin user home)
- Operate on: Own state and system state, via absolute directories and other mechanisms
- Assume system ownership, i.e. precedence over other configurations
- Assume Bash + Ubuntu environment (for now)
- Flags `-e` and `-a` are always set, except during early execution and explicit exceptions, e.g. `set +a; UNEXPORTED_VAR=value; set -a`
- Idempotent/repeatable operations are preferred, otherwise completed operations must be remembered to prevent repetition
- Existing configurations and state are backed up before modification, with suffix `.init-phoenix.aas.backup`
- Crypts are restricted to a single owner, a limitation of `gocryptfs`/FUSE (other users can still access, under the `allow_other` mount option)
  - **Crypt owners**: `root`, admin user (`ubuntu`), `mysql`
  - **Crypts**: Root crypt, Docker volume crypt (owned by `root`), admin crypt, MySQL crypt
  - **Crypts containing admin/user data**: Docker volume crypt (owned by `root`), admin crypt, MySQL crypt
- Minimal permissions are the default for sensitive files (`600`) and all directories (`700`)
- **Host privilege is not data privilege**, e.g. `sudo mysql` requires two different passwords
- Crypto-quality secrets are the default for automated or infrequent, manual processes
- Password-like secrets are the default for frequent, manual processes

### Crypt restore (experimental)

- Do platform init
- `cd / && sudo tar -xpvz --same-owner -g /dev/null -f /PATH/TO/docker-vol-crypt-data-20XX-XX-XX-XXXX-XXs.incremental.tar.gz` (extract in chronological order)
- `cd / && sudo tar -xpvz --same-owner -g /dev/null -f /PATH/TO/admin-crypt-data-20XX-XX-XX-XXXX-XXs.incremental.tar.gz` (extract in chronological order)
- `cd / && sudo tar -xpvz --same-owner -g /dev/null -f /PATH/TO/mysql-crypt-data-20XX-XX-XX-XXXX-XXs.incremental.tar.gz` (extract in chronological order)
- If 'AAS' crypts, reinstall minutely/daily services or root crypt will be out of sync with restored

## Known issues ⚠️

*Future issues should be documented via GitHub*

- There are Docker volumes mounted in admin crypt (move)
- Many DRY violations in scripts (may benefit from Bash functions)
- Script state management could be better
- A script is needed to downgrade/reconcile crypts configured with service features, for local use, e.g. in WSL (need self-signed certs?)
- The OpenIPMI service is auto-installed with Prometheus Node Exporter, which will fail to start if the associated hardware is unavailable, resulting in a 'degraded' system (solve on Ubuntu with `apt remove openipmi`)
- Docker metrics are currently misconfigured, based on a bad assumption (that the service could bind to an arbitrary interface)
  - Remedy: Bind to `0.0.0.0` but configure a firewall to emulate interface binding
- A containerized connector for LLDAP and Vaultwarden is available, but unimplemented
- Privacy concern: Unknown if HedgeDoc removes metadata from uploaded images (it should)
- Nextcloud install is not sufficiently automated, contains race condition
- Nextcloud can be optimized by switching to the FPM image and having a corresponding special Nginx config