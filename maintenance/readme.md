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

To enable automatic reboots, add to `/etc/default/pi-maintenance`:
```bash
AUTO_REBOOT=true
REBOOT_DELAY_MINUTES=2
```

Safeguard: a reboot is only scheduled when updates indicate a reboot is required (`/var/run/reboot-required` exists) and the maintenance run recorded no failed steps. Otherwise only a warning is logged.

## Viewing logs in Grafana

The Loki data source is provisioned automatically. In Grafana go to **Explore**, choose **Loki** and run:

```
{job="pi-maintenance"}
```

Filter further with `level` (`info`, `warning`, `error`) or `step` (e.g. `apt-upgrade`, `docker-pull-monitoring`). Example: `{job="pi-maintenance", level="error"}`.

If Loki is unreachable, the script keeps going and records a warning in the local log file.
