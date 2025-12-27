# playbooks

My playbooks for home use. The Kubernetes cluster can be tested with libvirt, see the Testing section. Traefik TLS configuration gives A+ on [SSL Labs](https://www.ssllabs.com/ssltest/).

These playbooks, except of the `desktop-*.yml` playbook, can be tested on libvirt. All playbooks is designed to run individually or as a part of a whole.


## What is available

* `desktop-*.yml` --- my desktop configurations
* `forgejo-runner.yml` --- create forgejo runners
* `pi-*.yml` --- raspberry pi plays
* `restic.yml` --- restic backup play

### Kubernetes deployments

* `deployments.yml` --- copy out deployment configuration files and apply them to running kubernetes
* `provision-vms.yml` --- start virtual machines for development locally
* `provision-k3s.yml` --- configure a small, large or huge k3s, cluster

## Start developing

Vagrant is deprecated from this environment due to licensing change. We need more steps, but the community have decided rightfully to abandon them.

### Development environment

Install libvirt and enable the default bridge, `virbr0`, to start at boot. We assume that the bridge is configured with the subnet `192.168.122.0/24` from now. You also need to be able to create virtual machine on `qemu:///system`. Add yourself to the `libvirt` group. Everything is tested on Debian Trixie. If you have problems on other distros, why not use Debian 🙃.

```bash
sudo usermod -aG libvirt $USER  # May need to log out and in before continuing
sudo apt install -y python3-libvirt python3-lxml  # To cumbersome to install into the environment
mkdir -p .venv
pipenv install
pipenv run ansible-galaxy install -fr roles/requirements.yml

grep -q 192\.168\.122 $HOME/.ssh/config || cat <<EOF > $HOME/.ssh/config

# Don't care about key checking on development hosts, and add persistent sessions.
Host 192.168.122.*
    ControlMaster auto
    ControlPath /tmp/ssh-%C
    ControlPersist 1h
    UserKnownHostsFile /dev/null
    StrictHostKeyChecking no
EOF
```
### Testing

This describes all the steps to get Kubernetes running and deploying all containers.

- Enter the python environment.
  ```bash
  pipenv shell
  ```
- Start the virtual machines. `state=present` is not needed since it is the default. Set `state=absent` to destroy VMs. Playbook for provisioning virtual machines expects you have `$HOME/.ssh/id_ed25519.pub`. Do you have a different public SSHkey, change it in [provision-k3s-vms.yml](provision-k3s-vms.yml).
  ```bash
  ansible-playbook -i hosts-k3s.yml provision-vms.yml -l localhost -e state=present
  ```
- Install the Kubernetes environment. `hosts-k3s.yaml` is the hosts file for our VMs.
  ```bash
  ansible-playbook -i hosts-k3s.yml provision-k3s.yml
  ```
- Congrats kubernetes runs on 3 VMs, one control plane node and two agents nodes.
- Deploy resources on the cluster.
  ```
  ansible-playbook -i hosts-k3s.yml deployments.yml
  ```

See `group_vars/k3s.yml` for overriding default versions hardcoded in the files.

## Services

Public available services.

* [Gotify](https://gotify.192.168.122.11.nip.io), default username `admin` and password `password`  
    After installing playbooks, go into the Gotify and add an application. Take the applications token and update the `gotify_token`. Voila, you get a notification every time someone logs into `homeserver`.
* [Nextcloud](https://nextcloud.192.168.122.11.nip.io) with database backup cronjob - default username `admin` and password `password`
  * For Collabora office install the app `Nextcloud Office` and go to admin interface and find `Office`
    * Use your own server, in `URL (and Port) of Collabora Online-server` add `https://collabora.nextcloud.192.168.122.11.nip.io/`.
    * Check `Disable certificate verification`.
    * Allow list for WOPI requests should contain `10.42.0.1`.
    * Go to the admin interface for Collabora and accept the certificate.
    * Now you can edit Office documents.
  * Nextcloud Talk, with `talk-aio` container. Configure as follows.
    * High-performance backend `hpb.nextcloud.192.168.122.11.nip.io` with password `password`.  
      Caveats: Will only work with proper certificate and can't be tested in this setup.
    * List of Public STUN server, [public-stun-list.txt](https://gist.github.com/mondain/b0ec1cf5f60ae726202e).
    * TURN server is our server `nextcloud.192.168.122.11.nip.io:3478` with password `password`.  
      TURN server is exposed with K3s LoadBalancer on port `3478` UDP and TCP on all nodes in this setup.
* [Vaultwarden](https://vaultwarden.192.168.122.11.nip.io) with database backup cronjob  
    Configured with signup. Change in admin GUI.

Services restricted to source IP range. Defaults to `192.168.0.0/16`, `172.16.0.0/12` and `10.0.0.0/8`.

* [Collabora CODE Admin](https://collabora.nextcloud.192.168.122.11.nip.io/browser/dist/admin/admin.html), default username `admin` and password `password`.
* [ForgeJo](https://forgejo.192.168.122.11.nip.io), ForgeJo self-hosted GitHub alternative. Needs configuring before usage.
* [Grafana](https://grafana.192.168.122.11.nip.io)
* [Munin](https://munin.192.168.122.11.nip.io)
* [Prometheus](https://prometheus.192.168.122.11.nip.io)
* [Smokeping](https://smokeping.192.168.122.11.nip.io)
* [Traefik](https://traefik.192.168.122.11.nip.io) with HTTP Strict Transport Security disabled, the middleware `default-https-headers@file` is disabled. This ensure that we can test Collabora office. Turn HSTS on in production.
* [Vaultwarden Admin](https://vaultwarden.192.168.122.11.nip.io/admin), Vaultwarden administration UI.

Other services running.

* `pod-updater` cronjob running in each namespace, which updates deployments regularly to fetch newer version of container images

## Caveats

Your router will block nip.io name resolution if _DNS rebind protection_ is enabled.

## Investigate dropped traefik in by network policies

Use `tshark` to look into dropped by a Kubernetes network policy. For more information about `k3s` logging see [Additional Network Policy Logging](https://docs.k3s.io/advanced#additional-logging-sources).

### All dropped traffic

```bash
tshark -i nflog:100 -T fields -e nflog.prefix -e ip.src -e ip.dst -e tcp.dstport -e udp.dstport
```

### Filter by IP

```bash
tshark -i nflog:100 -T fields -e nflog.prefix -e ip.src -e ip.dst -e tcp.dstport -e udp.dstport -Y 'ip.src == 10.42.0.37'
```

### Filter by word in policy name

```bash
tshark -i nflog:100 -T fields -e nflog.prefix -e ip.src -e ip.dst -e tcp.dstport -e udp.dstport -Y 'nflog.prefix matches "(?i)nextcloud"'
```

###### vim: set spell spelllang=en:
