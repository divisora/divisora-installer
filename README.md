## Divisora: Private, Automatic and Dynamic portal to other security zones
### Description
Divisora project is an attemt to build a secure and open source portal for users/administrators who want to access different security zones. Instead of relying on each protocol being secure, this project aims to minimize the security impact of opening access without loosing control by only exposing a portal through HTTPS / noVNC.

At this point this project should be considered a Proof-of-Concept rather than a stable release. Please feel free to contribute with comments / review / code updates through Issues / Pull-requests.

## Table of Contents

- [Prerequisites](#Prerequisites)
- [Components](#Components)
- [Design](#Design)
- [Pages](#Pages)
- [Authentication](#Authentication)
- [Install](#Install)
- [Known / Observed issues](#KnownObservedissues)
- [Debug](#Debug)
- [Todo](#Todo)


## Prerequisites
- Ubuntu 22.04
- Python 3.10+
    - Docker SDK (works with podman with some extra packages)
    - (pip)
- [FreeIPA](https://github.com/freeipa/freeipa-container) / [divisora-freeipa](https://github.com/divisora/divisora-freeipa)

## Components
- [divisora-nginx](https://github.com/divisora/divisora-nginx) - Nginx (web front/relay)
- [divisora-core-manager](https://github.com/divisora/divisora-core-manager) - Manager (auth/api)
- [divisora-node-manager](https://github.com/divisora/divisora-node-manager) - Node Manager (setup containers)
- [divisora-novnc](https://github.com/divisora/divisora-novnc) - NoVNC (http/https -> vnc)
- VNC (user container)
    - [divisora-cubicle-ubuntu](https://github.com/divisora/divisora-cubicle-ubuntu)
    - [divisora-cubicle-openbox](https://github.com/divisora/divisora-cubicle-openbox)

## Design
```
# Connection scheme
client ---> nginx ---> auth
                  <--- (NoVNC info for nginx proxy)
                  ---> NoVNC (node + unique port) ---> VNC

            node ---> api
                 <--- containers to build/run

# Expected communication path
client --(https)--> nginx --(https)--> NoVNC --(VNC+TLS)--> VNC
```

## Pages
```
/           page to access noVNC/VNC
/not_ready  landing page before container/cubicle is created/ready
/admin      add/modify/delete values for users/nodes
/login      default login-page
/logout     default logout-page
/api        api for divisora-node-manager
/static     default place for static content for webpages (css/js/pics)
```

## Authentication
Nginx auth and VNC auth do not need to come from the same source. This PoC have Nginx to use static values from Python/Flask while VNC is using FreeIPA to login the user. Even if both sources (portal / PAM) could use e.g. freeipa with OTP, a lost cookie will not provide an attacker full access, only access to Portal/NOVNC. While two authentication steps can be overwhelming, it provides a great security barrier for stolen sessions. Everytime a user refreshes the browser, a new login will be created since all connections will revert to a fresh login prompt. Can be anoying in the long-run but it provides a higher security environment were a "stolen" browser will never give an attacker full access.

## Install
```
There is alot of moving parts regarding the installation and all kind of different settings that can be made along the way.
Everything is made to work independently of others, but that also mean that every setting need to match. This setup-script is more considered a guideline than a best-practice.

./setup.sh
```

### Known / Observed issues
- General
    - docker build might crash if node-manager service is running on the same machine. Since it filters on tags, not names, it will shutdown machines that do "not exist".
    - docker in Ubuntu is weird when snapd is installed. Doesnt change iptables and indirectly do not expose ports.
    - Everything is running as root, even if podman is used. Must dive deeper into which component really have the need for root and which does not.
- Cubicle
    - No sound. VNC as a protocol doesnt support it.    

### Debug
```
journalctl -xef
podman ps -a
podman image ls
podman images -a
podman exec -it <mycontainer> /bin/bash
```

### Todo
- Cubicle 
    - Default (blocking) iptables when cubicle is started
- Services
    - Create a central log server
    - Screen recording
    - Keystroke recording
    - Proxy to filter web traffic
- Node
    - Create support for multiple nodes
    - Add SSL support to NOVNC and between NOVNC and VNC server
    - Make it not run as root
- Web / Core
    - Create health 'window' on the login page. Traffic direction must be set first.
    - Token-based login (maybe through FreeIPA?)
    - Hash the return values of the API.
    - Make everything in /admin editable
    - Password/Admin protect pages
