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

# disable installation of packages with graphical user interface
ADD apt-disable-install-of-gui-packages.pref /etc/apt/preferences.d/disable-install-of-gui-packages.pref

# add apt's sources for 'multiverse' repository and enable 'trusty-backports'
ADD apt-add-multiverse-and-enable-backports.list /etc/apt/sources.list.d/add-multiverse-and-enable-backports.list

# install some required/useful packages
RUN apt-get update && apt-get -y install build-essential sharutils wget vim git mercurial software-properties-common tmux

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

# pin some additional packages to ensure they update okay
# as per Tim's Bio-Linux upgrade script
RUN orphans=`cat $HOME/pseudo_orphans.txt | egrep -v "^#"` && for p in $orphans ; do for l in "Package: $p" 'Pin: origin ?*' 'Pin-Priority: 1001' '' ; do echo "$l" ; done done > $HOME/pseudo_orphans.pin && echo $orphans | xargs apt-get -y install

# update the system to register new packages
RUN apt-get update && \
apt-get -y --force-yes -o "Dir::Etc::Preferences=$HOME/pseudo_orphans.pin" upgrade && \
apt-get -y --force-yes -o "Dir::Etc::Preferences=$HOME/pseudo_orphans.pin" dist-upgrade

# install bio-linux packages
ENV DEBIAN_FRONTEND noninteractive
ADD rm_from_package_list.txt $HOME/rm_from_package_list.txt
RUN for p in `cat $HOME/rm_from_package_list.txt` ; do sed -ir "/^$p.*/d" $HOME/bl_master_package_list.txt; done
RUN echo 'mysql-server mysql-server/root_password password root' | debconf-set-selections \
&& echo 'mysql-server mysql-server/root_password_again password root' | debconf-set-selections
RUN chmod +x $HOME/bl_install_master_list.sh
#RUN /bin/bash $HOME/bl_install_master_list.sh

# set default CRAN mirror to 0-Cloud (cran.rstudio.com)
ADD cran-default-repos.txt $HOME/cran-default-repos.txt
RUN cat cran-default-repos.txt >> /etc/R/Rprofile.site

# clean up
#RUN rm *.*
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

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
