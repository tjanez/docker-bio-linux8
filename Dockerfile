# Dockerfile to build a containerized version of Bio-Linux 8
#
# VERSION 0.1

# Bio-Linux 8 is based on Ubuntu 14.04
FROM ubuntu:14.04

MAINTAINER Genialis <dev-team@genialis.com>

# set $HOME env variable
ENV HOME /root

# change to $HOME directory
WORKDIR $HOME

# disable installation of packages not suitable for a container environment
ADD apt-disable-install-of-packages.pref /etc/apt/preferences.d/disable-install-of-packages.pref

# add apt's sources for 'multiverse' repository and enable 'trusty-backports'
ADD apt-add-multiverse-and-enable-backports.list /etc/apt/sources.list.d/add-multiverse-and-enable-backports.list

# install utility packages
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && \
    apt-get -y install --no-install-recommends \
        build-essential \
        sharutils \
        wget \
        vim \
        git \
        mercurial \
        software-properties-common \
        tmux && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# NEBC Team's Bio-Linux 8 package signing key
# To obtain a fresh copy from upstream's install script, follow these steps:
#   wget -c http://nebc.nerc.ac.uk/downloads/bl8_only/upgrade8.sh
#   sed -i 's/mktemp \-d/pwd/' upgrade8.sh
#   UNPACK_ONLY=1 sh upgrade8.sh
#   dpkg --fsys-tarfile bio-linux-keyring.deb | tar xOf - ./usr/share/keyrings/bio-linux-8-signing.gpg > bio-linux8-signing.gpg
ADD bio-linux-8-signing.gpg /root/bio-linux-8-signing.gpg

RUN echo "Configuring apt repositories..." && \
    # official Bio-Linux PPA...
    apt-add-repository -y ppa:nebc/bio-linux && \
    # Michael Rutter's cran2deb4ubuntu PPA...
    apt-add-repository -y ppa:marutter/c2d4u && \
    # upstream CRAN packages for Ubuntu Trusty from R Studio CRAN mirror
    apt-add-repository -y 'deb http://cran.rstudio.com/bin/linux/ubuntu trusty/' && \
    apt-key adv --keyserver keyserver.ubuntu.com --recv-keys E084DAB9 && \
    # legacy Bio-Linux packages
    apt-add-repository -y 'deb http://nebc.nerc.ac.uk/bio-linux/ unstable bio-linux' && \
    apt-key add bio-linux-8-signing.gpg

ADD bl_master_package_list.txt $HOME/bl_master_package_list.txt
ADD rm_from_package_list.txt $HOME/rm_from_package_list.txt
RUN echo "Assembling list of packages to install..." && \
    cp $HOME/bl_master_package_list.txt $HOME/package_list.txt && \
    for p in `cat $HOME/rm_from_package_list.txt` ; do \
        sed --in-place "/^$p.*/d" $HOME/package_list.txt; \
    done && \
    echo "Installing packages..." && \
    apt-get update && \
    cat $HOME/package_list.txt | xargs apt-get install -y --no-install-recommends && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# set default CRAN mirror to 0-Cloud (cran.rstudio.com)
ADD cran-default-repos.txt $HOME/cran-default-repos.txt
RUN cat cran-default-repos.txt >> /etc/R/Rprofile.site

# create a biolinux user and add to sudo group
RUN useradd -r -m -U -d /home/biolinux -s /bin/bash -c "Bio-Linux User" -p "" biolinux
RUN usermod -a -G sudo biolinux
# turn off password requirement for sudo groups users
RUN sed -i "s/^\%sudo\tALL=(ALL:ALL)\sALL/%sudo ALL=(ALL) NOPASSWD:ALL/" /etc/sudoers

# change to biolinux user
USER biolinux

# change HOME directory
ENV HOME /home/biolinux
WORKDIR $HOME
