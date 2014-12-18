# Docker images with embedded Ubuntu Mirror

## Description

A script to create Docker images with Ubuntu 14.04 mirror.

Each image is built on top of the previous one following the *de-facto* order:

    - **frntn/ubuntu-mirror:main**       : main
    - **frntn/ubuntu-mirror:restricted** : main > restricted
    - **frntn/ubuntu-mirror:universe**   : main > restricted > universe
    - **frntn/ubuntu-mirror:multiverse** : main > restricted > universe > multiverse

## Usage

### Create images

```bash
# main only ~20.5 GiB
curl https://raw.github.com/frntn/docker-images/master/ubuntu-mirror/createimages.sh | bash -s -- main

# main + restricted ~21GiB (default behavior)
curl https://raw.github.com/frntn/docker-images/master/ubuntu-mirror/createimages.sh | bash
# -- or --
curl https://raw.github.com/frntn/docker-images/master/ubuntu-mirror/createimages.sh | bash -s -- restricted

# main + restricted + universe
curl https://raw.github.com/frntn/docker-images/master/ubuntu-mirror/createimages.sh | bash -s -- universe

# main + restricted + universe + multiverse
curl https://raw.github.com/frntn/docker-images/master/ubuntu-mirror/createimages.sh | bash -s -- multiverse
```

### Start mirror container - Serve other containers

First start the mirror container.
You must give a name for this container so it can be linked later (see below).

```bash
docker run -d --name ubuntu-mirror frntn/ubuntu-mirror:restricted
```

Then start an ubuntu-based client container by either:

**1- [DIRTY] overriding dns resolution**

The following command add an entry in `/etc/hosts`.
Once inside the container, you'll have to :
- first remove the lists cache to prevent update errors `rm -rf /var/lib/apt/lists`
- edit the `/etc/apt/sources.list` to fit with your local mirror available content (main, restricted, universe....)

```bash
FQDN="archive.ubuntu.com"
docker run -ti \
  --link ubuntu-mirror:$FQDN \
  ubuntu:14.04 \
  /bin/bash
```

**2- [RECOMMENDED] overriding the source.list**

The following command create an ad-hoc `source.list` used along with the
container started just after.
Here, you're not tied to the configuration of the image, and don't have
additional commands at startup.

```bash
FQDN="whatever.local"
cat <<EOF > sources.list-$FQDN
deb http://$FQDN/ubuntu/ trusty main restricted
deb http://$FQDN/ubuntu/ trusty-updates main restricted
deb http://$FQDN/ubuntu/ trusty-backports main restricted
deb http://$FQDN/ubuntu/ trusty-security main restricted
EOF

docker run -ti \
  --link ubuntu-mirror:$FQDN \
  -v $(readlink -f sources.list-$FQDN):/etc/apt/sources.list \
  ubuntu:14.04 \
  /bin/bash
```

### Start mirror container - Serve other hosts (VM or real hosts)

First start the mirror container.
You must publish the local exposed port to your host.

```bash
# Dynamic
docker run -P -d --name ubuntu-mirror frntn/ubuntu-mirror:restricted
docker ps # <- to see which port it has been associated to

# Static
docker run -p 80:80 -d --name ubuntu-mirror frntn/ubuntu-mirror:restricted
```

You then must configure your ubuntu-based client so it can access this container.
