# Spyderisk System Modeller Deployment Project

## Overview

The purpose of this project is to provide a configured system that can deploy
the dockerised Spyderisk software on a server along with keycloak and mongo
containers.

The deployment would be with `docker-compose` executed directly on the server
or remotely via `docker machine`.

This project orchestrates:

* a reverse proxy (in the `proxy` container) which configures the following
  endpoints:

  * /system-modeller -> /system-modeller on the `ssm` container;
  * /system-modeller/adaptor -> /system-modeller/adaptor on the `adaptor` container;
  * /auth -> /auth on the `keycloak` container;
  * /documentation -> the documentation website.

* the system-modeller (`ssm` container);
* Keycloak
* MongoDB
* SSM-Adaptor

The orchestration is defined in a `docker-compose.yml` file.

Of the four containers, the only one configured to expose any ports outside of
the docker network is `nginx`.

The deployment can also work with an existing external keycloak service, see
relevant section [below](#Deployment using an external keycloak service).

## Deployment

General method:

1. Edit the `.env` file to set appropriate values.
1. Edit the `.env_adaptor` file to set appropriate values.
3. Download the most recent [knowledgebase](https://github.com/Spyderisk/domain-network/packages/1826148)
   e.g. `domain-network-6a3-2-2.zip` and paste it into the `knowledgebases` folder.
2. Run `docker-compose pull` to get the latest images (otherwise the locally cached
   ones are used, if they are there).
4. Run `docker-compose up -d` to start the containers.

See below for details.

### Deployment on a Laptop

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

An alternative is to manually edit the `hosts` file to add in a made-up FQDN e.g.
`spyderisk.example.com` and use that as the `SERVICE_DOMAIN` domain name.

To start the service:

```shell
docker-compose up
```

The port exposed to the host machine is by default 8089 but this can be
changed by editing value of `PROXY_EXTERNAL_PORT` in the `.env` file.

When the service is running, access e.g. <http://host.docker.internal:8089/system-modeller> in your web browser.

### Deployment on a Server

Edit `.env` and update `SERVICE_PROTOCOL`, `SERVICE_DOMAIN`, and `SERVICE_PORT`
values to your organisation's settings.

To start the service:

```shell
docker-compose up -d
```

or as normal user with sudo:

```shell
sudo -E docker-compose up -d
```

### Deployment using an external keycloak service

In order to use an external keycloak service we need to know the URL of the
keycloak auth endpoint, and the relevant shared secret. At this point we also
assume that realm `ssm-realm` exists in the external keycloak service.

Edit `.env` file and update:

- `EXTERNAL_KEYCLOAK_AUTH_SERVER_URL` variable,
- `KEYCLOAK_CREDENTIALS_SECRET` variable

Finally, start the service using the `docker-compose_external_kc.yml` docker
compose file, e.g. `docker-compose -f docker-compose_external_kc.yml up -d`.


#### Multiple deployments on the same server

Multiple deployments of the dockerised SSM can co-exist on the same server.
Each deployment requires its own folder, and adjusted PORT settings.

- copy the system-modeller-deployment to a folder with a different name e.g. `security1`
- edit `.env` and use different names values for:
  - update `SERVICE_DOMAIN` to a different name than the first deployment SERVICE_DOMAIN
  - update `PROXY_EXTERNAL_PORT` to a different value than the first deployment PROXY_EXTERNAL_PORT
- run `docker-compose pull` (optional step to ensure that the latest images are downloaded)

Start the second deployment using `docker-compose up -d`. The second SSM
service can be access/proxied from the port defined by PROXY_EXTERNAL_PORT
value.


#### Deployment on a test server

Sometimes we need to deploy onto a docker host server which does not have an
FQDN and where we cannot open a public port. In this case we need to invent an
FQDN and make it so that both the SSM container and the client web browser both
(a) resolve to the docker host server when looking up the FQDN and (b) can
access the server on the appropriate port.

For example, if the host server is `fiab.spdns.org` and we are using the
default public-facing port for the SSM of 8089, then to route from the web
browser (client machine) to the server:

1. Make up an FQDN for the service, e.g. `example.com`
2. On the web browser (client) host, add a line to the `hosts` file (either
   `/etc/hosts` or `C:\Windows\System32\drivers\etc\hosts`) so that the client
   interprets the made up FQDN as being on the local machine:

   ``` 127.0.0.1   example.com ```
3. From the local (client) host, make an SSH tunnel from the local
   `localhost:8089` to `localhost:8089` on the server (in this example, the
   host machine is `fiab.spdns.org` and the SSH port is a non-standard `17248`):
```
ssh -nNT -L 8089:localhost:8089 username@fiab.spdns.org:17248 -v
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

```
SERVICE_DOMAIN=example.com
```

The IP address in the `extra_hosts` clause needs to be the (internal) IP
address of the host. When the SSM tries to connect to Keycloak on the URL
`http://example.com:8089/auth/something` the `extra_hosts` clause means
it will connect to the host machine and from there back into our reverse proxy
and then to Keycloak. Without this the SSM container will try to use the
`resolv.conf` file from the docker host which passes on to some DNS which does
not know about the made up FQDN.


## Inspecting an Existing Deployment

### Accessing the logs

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

### Finding the SSM version

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
GitLab (for instance) to jump to that specific commit. The build timestamp is
also available with the key `org.opencontainers.image.created`.


### Monitoring resource usage

To see CPU, memory and network usage (one off):

```shell
docker ps -q|xargs docker stats --no-stream
```

To keep monitoring it (like `top`):

```shell
docker ps -q | xargs docker stats
```


## Upgrading a deployment

It is sometimes possible to upgrade the SSM container in a deployment while
keeping the user accounts and system models. This will only work if the new SSM
software is compatible with the databases of the previous version. (TODO: if
the domain models in the SSM change, what happens?)

1. Go to the deployment's folder.
1. Stop all the containers in the deployment:

```shell
$ docker-compose stop
Stopping system-modeller-deployment_proxy_1    ... done
Stopping system-modeller-deployment_ssm_1      ... done
Stopping system-modeller-deployment_mongo_1    ... done
Stopping system-modeller-deployment_keycloak_1 ... done
Stopping ssm-adaptor                           ... done
```

3. Remove the SSM container (using the name from the list in the previous
   step): `docker container rm system-modeller-deployment_ssm_1`
1. The container is created from an underlying image described in the
   `docker-compose.yml` file. If the name/tag of the new image is the same as
   the old (for instance if "latest" is being used), then just do `docker-compose
   pull` to update the local image registry. Or, you might want to change the
   image reference in `docker-compose.yml` file to a different SSM image (e.g.
   change "dev" to "master" or change a tagged version).
1. Bring the system back up again: `docker-compose up -d`

