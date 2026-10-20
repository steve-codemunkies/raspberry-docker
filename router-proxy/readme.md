# Router Web Interface Proxy

This configuration sets up a secure HTTPS proxy to access your router's web interface at 192.168.1.1 through your domain with SSL/TLS encryption. It integrates with the existing nginx-reverse-proxy setup to handle SSL certificates and routing.

## Features
- Secure HTTPS access using existing Let's Encrypt certificates from nginx-proxy
- Automatic certificate renewal through existing acme-companion
- Proxies all router interface features including frames and websockets
- Lightweight nginx container that only handles router traffic

## Setup Instructions

1. Copy the environment file and set your domain:
   ```bash
   cp .env.example .env
   ```

2. Edit the `.env` file and set your domain name for the router interface:
   ```
   VIRTUAL_HOST=router.yourdomain.com
   ```

3. Create the necessary directories and copy files:
   ```bash
   sudo mkdir -p /opt/stacks/router-proxy
   sudo cp docker-compose.yml .env nginx.conf /opt/stacks/router-proxy/
   ```

4. Start the router proxy:
   ```bash
   sudo docker compose -f /opt/stacks/router-proxy/docker-compose.yml up -d
   ```

## Security Notes

- The connection between your browser and the proxy will be encrypted with HTTPS
- The connection between the proxy and your router remains unencrypted (HTTP)
- Access should still be limited to your internal network for security
- Consider setting up IP-based access restrictions in your nginx configuration

## Troubleshooting

If you experience issues:
1. Check your router is accessible at 192.168.1.1
2. Verify DNS resolution for your domain
3. Check the nginx-proxy logs for certificate issues
4. Some router interfaces might need additional headers - check the logs for any blocked requests