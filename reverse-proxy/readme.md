# Nginx Reverse Proxy

I'm using the [`nginxproxy/nginx-proxy`](https://hub.docker.com/r/nginxproxy/nginx-proxy) image for my proxy. See [Automated Nginx Reverse Proxy for Docker](http://jasonwilder.com/blog/2014/03/25/automated-nginx-reverse-proxy-for-docker/).

Because this is the modern internet I've also configured in [`nginxproxy/acme-companion`](https://hub.docker.com/r/nginxproxy/acme-companion). This monitors the nginx and creates certificates against [Let's Encrypt](https://letsencrypt.org/) as required.

I don't actually want to expose my services to the internet, so I'm going to use a [`DNS-01` challenge](https://github.com/nginx-proxy/acme-companion/blob/main/docs/Let's-Encrypt-and-ACME.md#dns-01-acme-challenge). This means proving that I control the domain that I'm requesting a certificate for. My domain registrar is [Namecheap](https://github.com/acmesh-official/acme.sh/wiki/dnsapi#dns_namecheap).

On my Raspberry Pi I have created `/opt/stacks/reverseproxy` and copied the [`docker-compose.yml`](docker-compose.yml) and populated [`.env`](.env) files to this folder. 

Finally the stack is started by executing `sudo docker compose -f /opt/stacks/reverseproxy/docker-compose.yml up -d`.

## Deploying a new stack

When deploying a new stack it's useful to be able to view the logs to ensure that certificate provisioning is working. But we don't want to be constantly stopping and starting the containers to see the logs, so how to do it?

The first step is to get a list of the running containers:

```shell
sudo docker ps
```

Which gives us this output:

```
CONTAINER ID   IMAGE                       COMMAND                  CREATED       STATUS                 PORTS                                                                                                        NAMES
2f3aeef9543e   pihole/pihole:latest        "start.sh"               10 days ago   Up 10 days (healthy)   67/udp, 80/tcp, 0.0.0.0:53->53/tcp, 0.0.0.0:53->53/udp, [::]:53->53/tcp, [::]:53->53/udp, 123/udp, 443/tcp   pihole
7c472902e88e   nginxproxy/acme-companion   "/bin/bash /app/entr…"   10 days ago   Up 10 days                                                                                                                          reverseproxy-nginx-proxy-acme-1
f62db5c95da8   nginxproxy/nginx-proxy      "/app/docker-entrypo…"   10 days ago   Up 10 days             0.0.0.0:80->80/tcp, [::]:80->80/tcp, 0.0.0.0:443->443/tcp, [::]:443->443/tcp                                 reverseproxy-nginx-proxy-1
```

The container we're interested in is `reverseproxy-nginx-proxy-acme-1` and this has a container id of `7c472902e88e`. Next we connect to the logs:

```shell
sudo docker logs -f --tail 100 -t <container id>
```

So to view the logs for this container I'll use

```shell
sudo docker logs -f --tail 100 -t 7c472902e88e
```