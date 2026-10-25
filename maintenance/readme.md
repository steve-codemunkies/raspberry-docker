# Pi Maintenance

An unattended script that, every Sunday at 03:00:

1. Runs `apt-get update` and downloads package updates
2. Applies the updates (`apt-get upgrade`) and removes unused packages
3. Pulls updated Docker images for every stack in `/opt/stacks/*` and recreates changed containers

Output is written to `/var/log/pi-maintenance.log` **and** pushed to Loki, so it can be viewed in Grafana.
By default the script does not reboot the Pi; if a reboot is needed it logs a warning. Automatic reboot is opt-in via `AUTO_REBOOT=true`.

## Prerequisites

* Docker installed (see [docker-install](../docker-install/))
* The [monitoring stack](../monitoring/) deployed to `/opt/stacks/monitoring`, **including Loki** (added to the monitoring compose file). Grafana does not store logs itself; Loki does, and Grafana queries it.
* `curl` and `flock` (both present on Raspberry Pi OS)
* No reboot is performed unless you explicitly enable `AUTO_REBOOT` (default `false`)

## Permissions

* The script must run as **root** (apt and docker both need it). It exits if not.
* Script: `root:root`, mode `755`. The service runs as root via systemd, so no sudoers entry is needed.
* Loki is published only on `127.0.0.1:3100`, so the host script can push to it without exposing it to the network.

## Setup

1. Update and restart the monitoring stack so Loki is running (see [monitoring readme](../monitoring/readme.md)).

2. Install the script and systemd units:
   ```bash
   sudo mkdir -p /opt/maintenance
   sudo install -o root -g root -m 755 pi-maintenance.sh /opt/maintenance/pi-maintenance.sh
   sudo install -o root -g root -m 644 pi-maintenance.service /etc/systemd/system/pi-maintenance.service
   sudo install -o root -g root -m 644 pi-maintenance.timer /etc/systemd/system/pi-maintenance.timer
   ```

3. Enable the schedule:
   ```bash
   sudo systemctl daemon-reload
   sudo systemctl enable --now pi-maintenance.timer
   ```

## Updating the script on the target system

systemd runs whatever is at `/opt/maintenance/pi-maintenance.sh` each time the timer fires, so updating means re-installing the file. Nothing needs restarting.

1. Get the latest version of this repo onto the Pi (e.g. `git pull`) and change to this directory.

2. Check the syntax and re-install the script:
   ```bash
   bash -n pi-maintenance.sh
   sudo install -o root -g root -m 755 pi-maintenance.sh /opt/maintenance/pi-maintenance.sh
   ```

3. Only if `pi-maintenance.service` or `pi-maintenance.timer` changed, re-install them and reload systemd:
   ```bash
   sudo install -o root -g root -m 644 pi-maintenance.service /etc/systemd/system/pi-maintenance.service
   sudo install -o root -g root -m 644 pi-maintenance.timer /etc/systemd/system/pi-maintenance.timer
   sudo systemctl daemon-reload
   sudo systemctl restart pi-maintenance.timer
   ```

4. Optionally test it. This performs real updates (and a reboot if `FORCE_REBOOT=true`):
   ```bash
   sudo systemctl start pi-maintenance.service
   journalctl -u pi-maintenance.service -f
   ```

5. If a new option was added, set it in `/etc/default/pi-maintenance` (see [Configuration](#configuration)).

## Schedule

The schedule is `OnCalendar=Sun *-*-* 03:00:00` in `pi-maintenance.timer` (system local time; check with `timedatectl`). `Persistent=true` means a run missed while the Pi was off happens at next boot.

To change it:
```bash
sudo systemctl edit --full pi-maintenance.timer
sudo systemctl restart pi-maintenance.timer
```

Check the next run:
```bash
systemctl list-timers pi-maintenance.timer
```

## Running manually

```bash
sudo /opt/maintenance/pi-maintenance.sh
# or via systemd
sudo systemctl start pi-maintenance.service
journalctl -u pi-maintenance.service -f
```

## Configuration

Optional overrides go in `/etc/default/pi-maintenance` (read by the service) or can be exported when running manually:

| Variable | Default | Purpose |
|---|---|---|
| `LOKI_URL` | `http://127.0.0.1:3100` | Loki endpoint |
| `STACKS_DIR` | `/opt/stacks` | Directory containing one folder per compose stack |
| `RECREATE_CONTAINERS` | `true` | Run `docker compose up -d` after pulling so new images are used |
| `PRUNE_IMAGES` | `true` | Remove dangling images afterwards |
| `LOG_FILE` | `/var/log/pi-maintenance.log` | Local log file |
| `AUTO_REBOOT` | `false` | Schedule a reboot after maintenance when updates require one |
| `REBOOT_DELAY_MINUTES` | `2` | Minutes to wait before the scheduled reboot |
| `FORCE_REBOOT` | `false` | Schedule a reboot at the end of every run, whether or not one is required |

To enable automatic reboots, add to `/etc/default/pi-maintenance`:
```bash
AUTO_REBOOT=true
REBOOT_DELAY_MINUTES=2
```

Reboot decisions are made once, at the very end of the run (after the OS updates **and** Docker steps), in this order:

1. `FORCE_REBOOT=true`: a reboot is always scheduled, even if steps failed.
2. `AUTO_REBOOT=true`, a reboot is required (`/var/run/reboot-required` exists) and no steps failed: a reboot is scheduled.
3. A reboot is required but neither of the above applies: only a warning is logged.
4. Otherwise nothing happens.

The reboot is scheduled with `shutdown -r +REBOOT_DELAY_MINUTES`; cancel it with `sudo shutdown -c`.

## Viewing logs in Grafana

The Loki data source is provisioned automatically. In Grafana go to **Explore**, choose **Loki** and run:

```
{job="pi-maintenance"}
```

Filter further with `level` (`info`, `warning`, `error`) or `step` (e.g. `apt-upgrade`, `docker-pull-monitoring`). Example: `{job="pi-maintenance", level="error"}`.

If Loki is unreachable, the script keeps going and records a warning in the local log file.
