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

Install [Vagrant](https://www.vagrantup.com/) and [VirtualBox](https://www.virtualbox.org/) for your distro. Start the environment.

```bash
vagrant up
```

Variables is configurable in `group_vars`. See `group_vars/k3s.yml` for available parameters and default for the Vagrant development configuration.

### Services

Public available services.

* [Gotify](https://gotify.192.168.56.11.nip.io), default username `admin` and password `password`  
    After installing playbooks, go into the Gotify and add an application. Take the applications token and update the `gotify_token`. Voila, you get a notification every time someone logs into `homeserver`.
* [Nextcloud](https://nextcloud.192.168.56.11.nip.io) with database backup cronjob - default username `admin` and password `password`
  * For Collabora office install the app `Nextcloud Office` and go to admin interface and find `Office`
    * Use your own server, in `URL (and Port) of Collabora Online-server` add `https://collabora.nextcloud.192.168.56.11.nip.io/`.
    * Check `Disable certificate verification`.
    * Allow list for WOPI requests should contain `10.42.0.1`.
    * Go to the admin interface for Collabora and accept the certificate.
    * Now you can edit Office documents.
  * Nextcloud Talk, with `talk-aio` container. Configure as follows.
    * High-performance backend `hpb.nextcloud.192.168.56.11.nip.io` with password `password`.  
      Caveats: Will only work with proper certificate and can't be tested in this setup.
    * List of Public STUN server, [public-stun-list.txt](https://gist.github.com/mondain/b0ec1cf5f60ae726202e).
    * TURN server is our server `nextcloud.192.168.56.11.nip.io:3478` with password `password`.  
      TURN server is exposed with K3s LoadBalancer on port `3478` UDP and TCP on all nodes in this setup.
* [Vaultwarden](https://vaultwarden.192.168.56.11.nip.io) with database backup cronjob  
    Configured with signup. Change in admin GUI.

Services restricted to source IP range. Defaults to `192.168.0.0/16`, `172.16.0.0/12` and `10.0.0.0/8`.

* [Collabora CODE Admin](https://collabora.nextcloud.192.168.56.11.nip.io/browser/dist/admin/admin.html), default username `admin` and password `password`
* [Grafana](https://grafana.192.168.56.11.nip.io)
* [Munin](https://munin.192.168.56.11.nip.io)
* [Prometheus](https://prometheus.192.168.56.11.nip.io)
* [Smokeping](https://smokeping.192.168.56.11.nip.io)
* [Traefik](https://traefik.192.168.56.11.nip.io) with HTTP Strict Transport Security disabled, the middleware `default-https-headers@file` is disabled. This ensure that we can test Collabora office. Turn HSTS on in production.
* [Vaultwarden Admin](https://vaultwarden.192.168.56.11.nip.io/admin), Vaultwarden administration UI

Other services running.

* `pod-updater` cronjob running in each namespace, which updates deployments regularly to fetch newer version of container images

### Caveats

Your router will block nip.io name resolution if _DNS rebind protection_ is enabled.

###### vim: set spell spelllang=en:
