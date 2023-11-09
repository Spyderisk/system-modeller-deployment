# Spyderisk System Modeller Deployment Project

## Overview

This project contains scripts and configuration files deploy an instance of the
open source [Spyderisk System Modeller](https://github.com/Spyderisk/system-modeller) on a machine you
control, typically a server or a laptop. As of the end of 2023, Spyderisk is
fully available but only works in very specific circumstances. This README file
documents how to do a Spyderisk deployment in those few circumstances. We are 
pretty proud of our efforts to bring 12 years of academic research out into the 
open and we expect it to get increasingly easy to install and run.

Being an open source project which promotes transparency at all levels,
Spyderisk is primarily written for and targeted to Linux/Unix. We have made
some efforts to make it work on Windows too, and within strict limits we do
support Windows users.

The scenarios we explicitly support in this document for installing Spyderisk are:

* On a Linux server, as an online service for use by multiple people
* On a Linux server, with multiple instances on multiple ports, each of which can be used by multiple people
* On a Linux laptop, for use by one person. This is quite similar to the Linux server case
* On a Windows laptop, for use by one person
* On a test Linux server, which does not have access to the internet or a fully-qualified domain name

We explicitly do not expect Spyderisk will work in any of the following scenarios:

* *Mac*. We have not tried installing Spyderisk on any Mac. 
* *Windows Server*. There are many reasons, including Microsoft's decision to discontinue 
  the free Hyper V Server product line in January 2022. In addition, Spyderisk is cybersecurity
  risk assessment, and from our knowledge we do not encourage anyone to run a Linux server on the internet
  under the Windows Subsystem for Linux. Microsoft does not do it and neither should you.
* *Microsoft Edge or Apple Safari browsers*. This is down to our testing capacity, not
  any desire we have to limit our users' choices.

We will thoughtfully consider all contributions from those who wish to expand
the list of supported scenarios.

## Required knowledge

You will need to understand how to install and configure Docker. 

We do not recommend anyone install a service live on the internet unless they are
confident in security measures around domain names, IP networking and routing,
and virtualisation.

There is a lower level of knowledge required to install on a laptop, assuming
the laptop is protected by its own firewall, and that docker is set up to
disallow access from outside the laptop.

## Technical overview

The deployment is made with `docker-compose` executed on the server or laptop.

This project orchestrates:

* A reverse proxy (in the `proxy` container) which configures the following
  endpoints:

  * /system-modeller -> /system-modeller on the `ssm` container;
  * /system-modeller/adaptor -> /system-modeller/adaptor on the `adaptor` container;
  * /auth -> /auth on the `keycloak` container;
  * /documentation -> the documentation website.

* [Spyderisk System Modeller](https://github.com/Spyderisk/system-modeller) (`ssm` container)
* [System Modeller Adaptor](https://github.com/Spyderisk/system-modeller-adaptor) (`ssm-adaptor` container)
* [MongoDB](https://www.mongodb.com/) database
* [Keycloak](https://www.keycloak.org/) which is bundled with Spyderisk and must be used, unless you have existing Keycloak installation

Two orchestration definitions are provided:

* `docker-compose.yml` which deploys a default insecure Keycloak service
* `docker-compose_external_kc.yml` which links to an external Keycloak service

Of the containers, the only one configured to expose any ports outside of
the docker network is `proxy`.

## Prerequisites

[Docker](https://www.docker.com/) is required to orchestrate the containers.
Docker is available on various host operating systems, but we recommend using
some form of Linux. For example, on Debian or Ubuntu type `sudo apt install docker`.

If you do use Windows Desktop, install the closed-source 
[Docker Desktop](https://www.docker.com/products/docker-desktop/) making sure you
comply with the [Docker Desktop license](https://docs.docker.com/subscription/desktop-license/).

One of the [Chrome](https://www.google.com/chrome/),
[Chromium](https://www.chromium.org/Home/) or
[Firefox](https://www.mozilla.org/firefox/) browsers. We have done the most
testing to date with Chrome and that is probably the best-supported, but to the
best of our knowledge Chromium works just as well. We strongly prefer working
promoting open source first, and our browser testing and preferences in future
are likely to reflect that.

On Windows Desktop you also need to first install
[Windows System for Linux v2](https://learn.microsoft.com/en-us/windows/wsl/about)
which in turn requires enabling
[Microsoft Hyper V](https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/hyper-v-technology-overview)
virtualisation technology.

Only Windows Desktop 10 or Windows Desktop 11 are supported.

## Deployment

General method:

1. Edit the `.env` file to set appropriate values.
2. Edit the `.env_adaptor` file to set appropriate values.
3. Download a Spyderisk [knowledgebase](https://github.com/Spyderisk/domain-network/packages/1826148) `zip` file asset.
   e.g. `domain-network-6a3-2-2.zip` and copy it into the `knowledgebases` folder.
4. Run `docker-compose pull` to get the latest images (otherwise the locally cached
   ones are used, if they exist).
5. Run `docker-compose up -d` or `docker-compose -f docker-compose_external_kc.yml up -d` to start the containers.

See below for details.

### Keycloak

The Spyderisk System Modeller uses Keycloak to authenticate users. The `docker-compose.yml` script will create an insecure Keycloak container for testing, preconfigured with a Keycloak `admin` account, and Spyderisk `testuser` and `testadmin` accounts, all using `password` as the password. For a production system you should configure Spyderisk to connect to a secure external Keycloak service and launch the software using the `docker-compose_external_kc.yml` file.

To communicate securely, the Spyderisk System Modeller and Keycloak must be configured with a shared secret. This secret is defined in the `KEYCLOAK_CREDENTIALS_SECRET` variable in the `.env` file and is inserted into the `ssm` container (and into the optional insecure `keycloak` container).

To use an external Keycloak service, edit the `.env` file and update:

* `EXTERNAL_KEYCLOAK_AUTH_SERVER_URL`
* `KEYCLOAK_CREDENTIALS_SECRET`

When configuring an external Keycloak, the suggested configuration is:

* Create a realm called `ssm-realm`
  * Set the "display name" to "SPYDERISK"
  * Set the "HTML display name" to `SPYDE<b>RISK</b>`
* Create a client called "system-modeller", with options:
  * client authentication: on
  * standard flow: enabled
  * service accounts roles: enabled
* Service account roles:
  * account: manage-account, view-profile, manage-account-links
  * realm-management: manage-users, query-groups, query-users, view-users
  * other: admin, user
  * defaults: offline_access, uma_authorization, default-roles-ssm-realm
  * valid redirect URIs: http://* (otherwise it doesn't like http)
  * credentials:
    * use "client Id & secret"
    * client secret defined to be `KEYCLOAK_CREDENTIALS_SECRET` in the `.env` file
* Users:
  * Spyderisk administrator:
    * account: manage-account, view-profile, manage-account-links
    * realm-management: manage-users, query-groups, query-users, view-users
    * other: admin, user
    * defaults: offline_access, uma_authorization, default-roles-ssm-realm
  * Spyderisk user:
    * account: manage-account, view-profile, manage-account-links
    * other: user
    * defaults: offline_access, uma_authorization, default-roles-ssm-realm

### Deployment on a Linux Server

Edit `.env` and update `SERVICE_PROTOCOL`, `SERVICE_DOMAIN`, and `SERVICE_PORT`
values to your organisation's settings.

To start the service and connect to an external Keycloak:

```sh
sudo -E docker-compose -f docker-compose_external_kc.yml up -d
```

or to connect to an insecure local Keycloak:

```shell
sudo -E docker-compose up -d
```

#### Multiple Deployments on the same Linux Server

Multiple deployments of the dockerised Spyderisk System Modeller can co-exist on the same server.
Each deployment requires its own folder, and adjusted PORT settings.

* copy the system-modeller-deployment to a folder with a different name e.g. `security1`
* edit `.env` and use different names values for:
  * update `SERVICE_DOMAIN` to a different name than the first deployment SERVICE_DOMAIN
  * update `PROXY_EXTERNAL_PORT` to a different value than the first deployment PROXY_EXTERNAL_PORT
* run `docker-compose pull` (optional step to ensure that the latest images are downloaded)

Start the second deployment with or without a secure Keycloak service as described above. The second
service can be access/proxied from the port defined by PROXY_EXTERNAL_PORT value.

#### Deployment on a Test Server

Sometimes we need to deploy onto a docker host server which does not have an
FQDN and where we cannot open a public port. In this case we need to invent an
FQDN and make it so that both the SSM container and the client web browser both
(a) resolve to the docker host server when looking up the FQDN and (b) can
access the server on the appropriate port.

For example, if the host server is `fiab.altostrat.com` and we are using the
default public-facing port for the SSM of 8089, then to route from the web
browser (client machine) to the server:

1. Make up an FQDN for the service, e.g. `example.com`
2. On the web browser (client) host, add a line to the `hosts` file (either
   `/etc/hosts` or `C:\Windows\System32\drivers\etc\hosts`) so that the client
   interprets the made up FQDN as being on the local machine:

   ``` 127.0.0.1   example.com ```
3. From the local (client) host, make an SSH tunnel from the local
   `localhost:8089` to `localhost:8089` on the server (in this example, the
   host machine is `fiab.altostrat.com` and the SSH port is a non-standard `17248`):

```sh
ssh -nNT -L 8089:localhost:8089 username@fiab.altostrat.com:17248 -v
```

This way, when the URL `http://example.com:8089/whatever` is put into the
web browser on the client machine, the FQDN is looked up in the local `hosts`
file and localhost (`127.0.0.1`) is returned. The browser connects on port 8089
on localhost which actually goes through the SSH tunnel to the server and
connects to port 8089 there instead, where the reverse proxy is listening on
port 8089.

To get the SSM container to also understand the made up FQDN (so that it can
contact Keycloak using the FQDN) we need to:

4. Add an `extra_hosts` clause to the `docker-compose.yml` file in the `ssm`
   definition, e.g.:

```yaml
extra_hosts:
      - "example.com:host-gateway"
```

5. Use the same made up FQDN in the `.env` file:

```sh
SERVICE_DOMAIN=example.com
```

The IP address in the `extra_hosts` clause needs to be the (internal) IP
address of the host. When the SSM tries to connect to Keycloak on the URL
`http://example.com:8089/auth/something` the `extra_hosts` clause means
it will connect to the host machine and from there back into our reverse proxy
and then to Keycloak. Without this the SSM container will try to use the
`resolv.conf` file from the docker host which passes on to some DNS which does
not know about the made up FQDN.

### Deployment on a Personal Machine, both Linux and Windows

The software is designed to be deployed on a server which has an externally
accessible domain name. It can be made to work on a personal machine but some
extra configuration is required, and this is not our highest testing priority.

The Spyderisk software must be configured so that there is a single URL used to
access Keycloak. The `docker-compose.yml` file sets the address to be
`${SERVICE_PROTOCOL}://${SERVICE_DOMAIN}:${SERVICE_PORT}/auth/`.

This URL must work (a) from the `ssm` container and (b) from the web browser of
a user. On Windows (using Docker Desktop) an appropriate hostname for
`SERVICE_DOMAIN` is `host.docker.internal` which Docker Desktop automatically
inserts into the Windows `hosts` file (`C:\Windows\System32\drivers\etc\hosts`)
to point at the docker host IP address. For Linux there is no equivalent
`host.docker.internal` entry in the `hosts` file (`/etc/hosts`), so it has to
be added manually, e.g. `<ip address of docker gateway> host.docker.internal`,
the default docker gateway is `172.17.0.1`.

An alternative is to manually edit the `hosts` file to add in your own made-up FQDN e.g.
`spyderisk.example.com` along with the Docker gateway IP address and use that as the `SERVICE_DOMAIN` domain name.

To start the service with the insecure local Keycloak:

```shell
docker-compose up -d
```

or to connect to an external Keycloak:

```sh
docker-compose -f docker-compose_external_kc.yml up -d
```

The port exposed to the host machine is by default 8089 but this can be
changed by editing value of `PROXY_EXTERNAL_PORT` in the `.env` file.

When the service is running, access e.g. <http://host.docker.internal:8089/system-modeller> in your web browser.

## Inspecting an Existing Deployment

### Accessing the Logs

From within a deployment's folder, the `docker logs` command can be used to
inspect the log files:

```shell
# get the log for all the containers:
docker-compose logs
# get the log for the SSM:
docker-compose logs ssm
# get the log for the SSM and "follow" the log file to see new entries as they arrive:
docker-compose logs ssm -f
# tail the ssm log but starting from just the last few lines:
docker-compose logs ssm -f --tail=100
```

### Finding the Spyderisk System Modeller Version

To discover what version of the SSM an existing deployment is using, the
`docker container inspect` command can be used.

From within a deployment's folder, find the names of the containers:

```shell
docker-compose ps

       Name                     Command               State          Ports
----------------------------------------------------------------------------------
example_adaptor_1    gunicorn -b 0.0.0.0:8000 - ...   Up                                                 
example_keycloak_1   /tmp/import/entrypoint.sh        Up (healthy)   8080/tcp, 8443/tcp                  
example_mongo_1      docker-entrypoint.sh mongod      Up             27017/tcp                           
example_proxy_1      /tmp/import/entrypoint_tra ...   Up             0.0.0.0:8086->80/tcp,:::8086->80/tcp
example_ssm_1        /var/lib/tomcat/bin/catali ...   Up                                                 
```

The use, e.g.:

```shell
docker container inspect example_ssm_1 | grep 'image.revision'
                "org.opencontainers.image.revision": "426e694d0c86499505745a4418655d3ad641c9c1",
```

The long number is the git commit ID. It can be pasted into the search bar in
GitHub (for instance) to jump to that specific commit. The build timestamp is
also available with the key `org.opencontainers.image.created`.

### Monitoring Resource Usage

To see CPU, memory and network usage (one off):

```shell
docker ps -q|xargs docker stats --no-stream
```

To keep monitoring it (like `top`):

```shell
docker ps -q | xargs docker stats
```

## Upgrading a Deployment

It is sometimes possible to upgrade the SSM container in a deployment while
keeping the user accounts and system models. This will only work if the new SSM
software is compatible with the databases of the previous version.

1. Go to the deployment's folder.
2. Stop all the containers in the deployment:

```shell
$ docker-compose stop
Stopping system-modeller-deployment_proxy_1    ... done
Stopping system-modeller-deployment_ssm_1      ... done
Stopping system-modeller-deployment_mongo_1    ... done
Stopping system-modeller-deployment_keycloak_1 ... done
Stopping system-modeller-deployment_adaptor    ... done
```

3. Remove the SSM container (using the name from the list in the previous
   step): `docker container rm system-modeller-deployment_ssm_1`
4. The container is created from an underlying image described in the
   `docker-compose.yml` file. If the name/tag of the new image is the same as
   the old (for instance if "latest" is being used), then just do `docker-compose
   pull` to update the local image registry. Or, you might want to change the
   image reference in `docker-compose.yml` file to a different SSM image (e.g.
   change "dev" to "master" or change a tagged version).
5. Bring the system back up again: `docker-compose up -d`
