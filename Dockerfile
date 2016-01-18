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

# pull BL8 upgrade script from nerc server
RUN wget -c http://nebc.nerc.ac.uk/downloads/bl8_only/upgrade8.sh

# replace the mktemp step with current working directory
RUN sed -i 's/mktemp \-d/pwd/' upgrade8.sh

# run script in unpack mode only
RUN UNPACK_ONLY=1 sh upgrade8.sh

# install bio-linux repository keys
RUN dpkg -EGi ./bio-linux-keyring.deb

# add Bio-Linux and CRAN-to-DEB repositories
RUN apt-add-repository -y ppa:nebc/bio-linux && apt-add-repository -y ppa:marutter/c2d4u

# add bio-linux and rstudio cran legacy lists to apt sources
ADD bio-linux-legacy.list /etc/apt/sources.list.d/bio-linux-legacy.list
ADD cran-latest-r.list /etc/apt/sources.list.d/cran-latest-r.list
RUN apt-get update

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
