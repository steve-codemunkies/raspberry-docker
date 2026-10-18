# Network Monitoring Stack

This directory contains the configuration for a comprehensive network monitoring solution using:
- Prometheus (metrics collection and storage)
- Node Exporter (system metrics collection)
- Grafana (visualization and dashboards)
- Loki (log storage; receives logs from the [maintenance script](../maintenance/) and is queried from Grafana)

## Setup Instructions

1. Copy the `.env.example` file to `.env`:
   ```bash
   cp .env.example .env
   ```

2. Edit the `.env` file and set your domain names for Prometheus and Grafana.

3. Create the necessary directories and set permissions:
   ```bash
   sudo mkdir -p /opt/stacks/monitoring
   sudo cp docker-compose.yml .env /opt/stacks/monitoring/
   sudo cp -r prometheus loki grafana /opt/stacks/monitoring/
   ```

4. Start the monitoring stack:
   ```bash
   sudo docker compose -f /opt/stacks/monitoring/docker-compose.yml up -d
   ```

## Accessing the Services

- Grafana will be available at https://your-grafana-domain
  - Default login: admin/admin
  - You'll be prompted to change the password on first login

- Prometheus will be available at https://your-prometheus-domain

- Loki listens on `127.0.0.1:3100` on the Pi only (not exposed to the network).

## Initial Grafana Setup

1. Log in to Grafana
2. Add Prometheus as a data source:
   - URL: http://prometheus:9090
   - Access: Server (default)
3. Import dashboard 1860 for Node Exporter metrics
4. The Loki data source (http://loki:3100) is provisioned automatically. View logs under Explore > Loki, e.g. `{job="pi-maintenance"}`.

## Metrics Available

- System metrics (CPU, Memory, Disk, Network)
- Process statistics
- Network statistics
- And more...

You can add more exporters later for monitoring specific services or collecting additional metrics.
