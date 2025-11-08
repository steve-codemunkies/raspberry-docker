# Nginx Reverse Proxy

I'm using the [`nginxproxy/nginx-proxy`](https://hub.docker.com/r/nginxproxy/nginx-proxy) image for my proxy. See [Automated Nginx Reverse Proxy for Docker](http://jasonwilder.com/blog/2014/03/25/automated-nginx-reverse-proxy-for-docker/).

Because this is the modern internet I've also configured in [`nginxproxy/acme-companion`](https://hub.docker.com/r/nginxproxy/acme-companion). This monitors the nginx and creates certificates against [Let's Encrypt](https://letsencrypt.org/) as required.

I don't actually want to expose my services to the internet, so I'm going to use a [`DNS-01` challenge](https://github.com/nginx-proxy/acme-companion/blob/main/docs/Let's-Encrypt-and-ACME.md#dns-01-acme-challenge). This means proving that I control the domain that I'm requesting a certificate for. My domain registrar is [Namecheap](https://github.com/acmesh-official/acme.sh/wiki/dnsapi#dns_namecheap).

On my Raspberry Pi I have created `/opt/stacks/reverseproxy` and copied the [`docker-compose.yml`](docker-compose.yml) and populated [`.env`](.env) files to this folder. 

Finally the stack is started by executing `sudo docker compose -f /opt/stacks/reverseproxy/docker-compose.yml up -d`. 