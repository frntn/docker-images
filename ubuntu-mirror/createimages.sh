#!/bin/bash

#
# ORIGNAL SCRIPT LOCATION:
#
#    - https://github.com/frntn/docker-images/blob/master/ubuntu-mirror/createimages.sh
#
# DESCRIPTION AND HOWTO:
#
#    - https://github.com/frntn/docker-images/blob/master/ubuntu-mirror/README.md
#

maxstage="$(echo "$1" | sed '/^\(main\|restricted\|universe\|multiverse\)$/b;s/.*//g')"
maxstage="${maxstage:-restricted}"

dryrun="$(echo "$2" | sed '/^echo$/b;s/.*//g')"
cyan="$(tput setaf 6)"
green="$(tput setaf 2)"
bgreen="$(tput bold ; tput setaf 2)"
red="$(tput setaf 1)"
reset="$(tput sgr0)"
wwwpath="/var/www/mirror.local"

command -v docker || curl http://get.docker.com/ | sh

cat <<EOF > sources.list
deb mirror://mirrors.ubuntu.com/mirrors.txt trusty main restricted universe
deb mirror://mirrors.ubuntu.com/mirrors.txt trusty-updates main restricted universe
deb mirror://mirrors.ubuntu.com/mirrors.txt trusty-backports main restricted universe
deb mirror://mirrors.ubuntu.com/mirrors.txt trusty-security main restricted universe
EOF

cat <<EOF > mirror.list-14.04
set base_path      /mirrors
set run_postmirror 0
set nthreads       20
set _tilde         0

deb http://ubuntu-archive.mirrors.proxad.net/ubuntu/ trusty
deb http://ubuntu-archive.mirrors.proxad.net/ubuntu/ trusty-updates
deb http://ubuntu-archive.mirrors.proxad.net/ubuntu/ trusty-backports
deb http://ubuntu-archive.mirrors.proxad.net/ubuntu/ trusty-security

clean http://ubuntu-archive.mirrors.proxad.net/ubuntu
EOF

cat <<EOF > nginx.site-available.mirror-local
server{
     listen 80;
     server_name mirror.local;

     location / {
         root $wwwpath;
         autoindex on;
     }
}
EOF

cat <<EOF > Dockerfile
FROM ubuntu:14.04
MAINTAINER Matthieu Fronton <m@tthieu.fr>

# Some mirrors don't have the required packages for mirror
# So we keep the default one
#ADD sources.list /etc/apt/sources.list
ADD mirror.list-main /etc/apt/mirror.list
ADD nginx.site-available.mirror-local /etc/nginx/sites-available/mirror.local

RUN apt-get update ; \
    DEBIAN_FRONTEND=noninteractive apt-get -y -o DPkg::Options::=--force-confold install apt-mirror nginx ; \
    mkdir -p $wwwpath ; \
    mkdir -p /mirrors ; \
    apt-mirror ; \
    ln -s /mirrors/mirror/ubuntu-archive.mirrors.proxad.net/ubuntu /var/www/mirror.local/ubuntu ; \
    sed -i '/^daemon/d' /etc/nginx/nginx.conf ; \
    sed -i '/^worker_processes/a daemon off;' /etc/nginx/nginx.conf ; \
    rm /etc/nginx/sites-enabled/default ; \
    ln -sf /etc/nginx/sites-available/mirror.local /etc/nginx/sites-enabled/

EXPOSE 80
CMD ["service", "nginx", "start"]
EOF

src_namespace=""
src_imagename="ubuntu:"
src_imagetag="14.04"
dst_namespace="frntn/"
dst_imagename="ubuntu-mirror:"
for dst_imagetag in main restricted universe multiverse
do
  src="$src_namespace$src_imagename$src_imagetag"
  dst="$dst_namespace$dst_imagename$dst_imagetag"
  echo "${cyan}INFO: Start building '$dst' image from '$src'...${reset}"

  # update mirror.list content
  sed '/^deb /s/$/ '$dst_imagetag'/' mirror.list-$src_imagetag > mirror.list-$dst_imagetag

  # update mirror.list reference inside Dockerfile
  sed -i '/^ADD mirror.list/s,'$src_imagetag','$dst_imagetag',' Dockerfile

  # build
  $dryrun docker build -t $dst .
  SUCCESS=$?

  if [ $SUCCESS -eq 0 ]; then
    echo "${green}SUCCESS: Build is over for image '$dst'"
  else
    echo "${red}FAILED: An error occured while trying to build image '$dst'. Next build(s) can't proceed. Exiting"
    exit
  fi

  # update Dockerfile for next build
  echo "${reset}"
  sed -i '/^FROM/s,'$src','$dst',' Dockerfile

  src_namespace=$dst_namespace
  src_imagename=$dst_imagename
  src_imagetag=$dst_imagetag

  [ "$dst_imagetag" = "$maxstage" ] && break
done

cat <<EOF > start-local-ubuntu-mirror.sh
docker run -d --name ubuntu-mirror $dst && \
echo "${green}SUCCESS: Container started${reset}" || \
echo "${red}FAILED: An error occured while trying to start the container${reset}"
EOF

if [ $SUCCESS -eq 0 ]; then
  chmod +x start-local-ubuntu-mirror.sh
  $dryrun ./start-local-ubuntu-mirror.sh && \
  echo "
${bgreen}
Congrats !

You now have a fully functional local ubuntu mirror inside a Docker container \\o/
To use it simply start a new container linked to the local ubuntu mirror named \"ubuntu-mirror\"
The link alias **must** be the FQDN target of your deb directives inside the container sources.list

Example usage (w/ official ubuntu image):
----------------------------------------

    docker run -ti --link ubuntu-mirror:archive.ubuntu.com ubuntu:14.04 /bin/bash
${reset}
"
fi