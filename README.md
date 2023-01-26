# playbooks

My playbooks for home use. The Kubernetes cluster can be tested with Vagrant running `vagrant up`. Traefik TLS configuration gives A+ on [SSL Labs](https://www.ssllabs.com/ssltest/).


These playbooks, except of the `desktop.yml` playbook, can be tested on Vagrant. All playbooks is designed to run individually or as a part of a whole. `homeserver` playbooks is tested on Ubuntu Focal.


## What is available

* `desktop-*.yml` --- my desktop configurations
* `pi-*.yml` --- raspberry pi plays
* `restic.yml` --- restic backup play

### Kubernetes deployments

* `deployments.yml` --- copy out deployment configuration files and apply them to running kubernetes

## Testing

To spin up all services, start Vagrant. Services spun up in Vagrant use self signed certificate and named with [nip.io](https://nip.io). Default private IP for the VM is `192.168.56.11`.

```bash
vagrant up
```
Variables is configurable in `group_vars`. See `group_vars/k3s.yml` for available parameters and default for the Vagrant development configuration.

### Services

Public available services.

* [Gotify](https://gotify.192.168.56.11.nip.io), default username `admin` and password `password`  
    After installing playbooks, go into the Gotify and add an application. Take the applications token and update the `gotify_token`. Voila, you get a notification every time someone logs into i`homeserver`.  
* [Nextcloud](https://nextcloud.192.168.56.11.nip.io) with backup cronjob, default username `admin` and password `password`
* [Vaultwarden](https://nextcloud.192.168.56.11.nip.io), configured to signup. Change in admin GUI.

Services restricted to source IP range. Defaults to `192.168.0.0/16`, `172.16.0.0/12` and `10.0.0.0/8`.

* [Grafana](https://grafana.192.168.56.11.nip.io)
* [Munin](https://munin.192.168.56.11.nip.io)
* [Prometheus](https://traefik.192.168.56.11.nip.io)
* [Smokeping](https://smokeping.192.168.56.11.nip.io)
* [Traefik](https://traefik.192.168.56.11.nip.io)
* [Vaultwarden Admin](https://traefik.192.168.56.11.nip.io/admin) - Vaultwarden administration UI

Other services running.

* `pod-updater` cronjob running in each namespace, which updates deployments regularly to fetch newer version of container images.

### Caveats

Your router will block nip.io name resolution if _DNS rebind protection_ is enabled.

###### vim: set spell spelllang=en:
