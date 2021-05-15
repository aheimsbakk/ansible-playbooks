# playbooks

My playbooks for home use. These playbooks, except of the `desktop.yml` playbook, can be tested on Vagrant. All playbooks is designed to run individually or as a part of a whole. `homeserver` playbooks is tested on Ubuntu Focal.

Traefik TLS configuration gives A+ on [SSL Labs](https://www.ssllabs.com/ssltest/).

## What is available

### Desktop

* `desktop.yml` --- my desktop configuration for Fedora

### Kubernetes deployments

* `deployments.yml` --- copy out deployment configuration files and apply them to running kubernetes

#### Gotify setup

After installing playbooks, go into the Gotify and add an application. Take the applications token and update the `gotify_token`. Voila, you get a notification every time someone logs into i`homeserver`.

All variables is configurable in `host_vars`. See `host_vars/k3s-m1.yml` for available parameters and default for the Vagrant development configuration.

### Raspberry PI

* `pi-pihole.yml` --- install and configure [pihole](https://pi-hole.net/) as auto updating container

Add custom IPv6 address by setting the `pihole_server_ipv6` variable, else default IPv6 is used if it exists. Add extra environment variables in a dictionary for watchtower in the `watchtower_env` variable.

## Testing

To spin up all services, start Vagrant. Services spun up in Vagrant use self signed certificate and named with [nip.io](https://nip.io). Default private IP for the VM is `10.20.30.11`.

```bash
vagrant up
```

### Services

Public available services.

* [Gitlab](https://gitlab.10.20.30.11.nip.io), with backup cronjob.
* [Gitlab registry](https://registry.10.20.30.11.nip.io:5487/v2), with cleanup cronjob.
* Gitlab SSH on `10.20.30.11:2222`
* [Gotify](https://gotify.10.20.30.11.nip.io), default username `admin` and password `password`
* [Nextcloud](https://nextcloud.10.20.30.11.nip.io) with backup cronjob, default username `admin` and password `password`

Services restricted with username and password. Defaults to `admin:password`.

* [Munin](https://munin.10.20.30.11.nip.io)
* [Smokeping](https://smokeping.10.20.30.11.nip.io)
* [Traefik](https://traefik.10.20.30.11.nip.io)

Other services running.

* [Duin](https://github.com/crazy-max/diun/), can notify on container updates to Gotify.
* `pod-updater` cronjob running in each namespace, which updates deployments regularly to fetch newer version of container images.

### Caveats

Your router will block nip.io name resolution if _DNS rebind protection_ is enabled.

###### vim: set spell spelllang=en:
