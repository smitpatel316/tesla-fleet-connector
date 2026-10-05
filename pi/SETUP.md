# Signing-host setup (Raspberry Pi or any always-on box)

Signed Fleet API commands need a private key that matches the public key
Tesla has for your developer app. This setup keeps the private key on ONE
host (the "signing host"); the agent machine only ever sends the OAuth
token over SSH stdin.

## 1. Generate the keypair (on the signing host)

```sh
mkdir -p ~/tesla-key && cd ~/tesla-key
openssl ecparam -genkey -name prime256v1 -noout -out private-key.pem
openssl ec -in private-key.pem -pubout -out public-key.pem
chmod 600 private-key.pem
```

Self-sign a TLS pair for the on-demand proxy (proxy is localhost-only, so
a self-signed cert is fine):

```sh
openssl req -x509 -newkey rsa:2048 -keyout proxy-tls-key.pem \
  -out proxy-tls-cert.pem -days 825 -nodes -subj "/CN=localhost"
chmod 600 proxy-tls-key.pem
```

## 2. Serve the public key from your partner domain

Tesla fetches your app's public key from:

```
https://<your-partner-domain>/.well-known/appspecific/com.tesla.3p.public-key.pem
```

Serve it with any static file server. Example layout:

```
~/tesla-key/www/.well-known/appspecific/com.tesla.3p.public-key.pem  <- copy of public-key.pem
```

```sh
cp public-key.pem www/.well-known/appspecific/com.tesla.3p.public-key.pem
# serve ~/tesla-key/www over HTTPS at your partner domain
```

Register the domain as a partner in your Tesla developer app
(developer.tesla.com).

## 3. Install the command script

Copy `tesla-cmd.sh` to the signing host (default the CLI expects:
`~/tesla-key/tesla-cmd.sh`, override with `TESLA_CMD_SCRIPT`). It needs
Docker (for the official `tesla/vehicle-command` image) and curl.

```sh
scp pi/tesla-cmd.sh <signing-host>:~/tesla-key/
ssh <signing-host> 'chmod +x ~/tesla-key/tesla-cmd.sh'
```

## 4. Pair the virtual key to the car (one-time, from a phone)

Open on the phone that has the Tesla app, signed in as a driver of the car:

```
https://tesla.com/_ak/<your-partner-domain>
```

Approve the key. Until this is done, signed commands are rejected — the
CLI will tell you and point at this step.

## 5. Point the CLI at the signing host

```sh
export TESLA_SSH_HOST="<signing-host>"        # SSH target, default: budupi
export TESLA_CMD_SCRIPT="~/tesla-key/tesla-cmd.sh"
export TESLA_PARTNER_DOMAIN="<your-partner-domain>"
```

Then: `tesla-api command --vin <VIN> --command honk_horn` (or any other
Fleet API command; see the [Fleet API docs](https://developer.tesla.com/docs/fleet-api)).

## Security notes

- `private-key.pem` never leaves the signing host. Not in git, not in
  backups to third parties, not in chat.
- The OAuth token travels over the SSH channel's stdin, never in a remote
  command line (so it can't show up in `ps` on the signing host).
- The proxy binds to `127.0.0.1` on the signing host and is stopped after
  every command (`trap cleanup EXIT`).
