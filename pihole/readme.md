# PiHole DNS and Ad-blocking

To run [PiHole](https://pi-hole.net/) I'm using a slightly modified version of the [`docker-compose.yml` from their instructions](https://docs.pi-hole.net/docker/).

The main differences are:
* The http and https ports aren't exposed, as they will be routed through Nginx.
* `VIRTUAL_HOST` and `LETSENCRYPT_HOST` are added the `pihold.environment` section.
* Add a `pihole.networks` section and add the network from the Nginx configuration (`nginx-reverse-proxy` in my case)

Finally the following section is added at the end of the `docker-compose.yml` to allow the use of the external network:

```yml
networks:
  nginx-reverse-proxy:
    external: true
```

## Monitoring Integration

Pi-hole metrics are now being collected using [pihole-exporter](https://github.com/eko/pihole-exporter) and can be viewed in Grafana. The exporter collects various statistics from Pi-hole including:

- DNS queries (total, blocked, cached)
- Top allowed/blocked domains
- Top clients
- Forward destinations
- Query types

The metrics are automatically collected by Prometheus and can be visualized in Grafana. To view the metrics:

1. Log into Grafana
2. Import one of these recommended dashboards:
   - [Pi-hole Exporter](https://grafana.com/grafana/dashboards/10176)
   - [Pi-hole Dashboard](https://grafana.com/grafana/dashboards/14475)

The exporter is configured to collect metrics every 15 seconds in [`prometheus.yml`](../monitoring/prometheus/prometheus.yml).