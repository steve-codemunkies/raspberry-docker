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