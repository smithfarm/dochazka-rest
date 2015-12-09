FROM opensuse:13.2
MAINTAINER Nathan Cutler <ncutler@suse.com>

# configure repo
RUN zypper --no-gpg-checks --non-interactive addrepo http://download.opensuse.org/repositories/home:smithfarm/openSUSE_13.2/home:smithfarm.repo
RUN zypper --no-gpg-checks --non-interactive ref

# install packages
RUN zypper --no-gpg-checks --non-interactive install \
    git \
    iproute2 \ 
    net-tools \
    sudo \
    timezone \
    vim \
    perl-Test-JSON \
    perl-Test-Fatal \
    perl-Module-Build

# install RPM version of App::Dochazka::REST to bring in runtime dependencies
RUN zypper --no-gpg-checks --non-interactive install \
    perl-App-Dochazka-REST

# remove RPM version of App::Dochazka::REST because we will install from source later
RUN zypper --no-gpg-checks --non-interactive remove \
    perl-App-Dochazka-REST

# add smithfarm user
RUN useradd -d /home/smithfarm -m -s /bin/bash smithfarm
COPY sudoers /tmp/sudoers
RUN install -o root -g root -m 440 /tmp/sudoers /etc/sudoers

# clone repo
WORKDIR /home/smithfarm
RUN su - smithfarm -c 'git clone git://github.com/smithfarm/dochazka-rest'
WORKDIR /home/smithfarm/dochazka-rest
RUN perl Build.PL
RUN ./Build
RUN ./Build install

# install App::Dochazka::REST site configuration file
COPY REST_SiteConfig.pm /tmp/REST_SiteConfig.pm
RUN install -d -o root -g root -m 755 /etc/dochazka-rest
RUN install -o root -g root -m 644 /tmp/REST_SiteConfig.pm /etc/dochazka-rest/REST_SiteConfig.pm

# set the timezone
RUN ln -sf /usr/share/zoneinfo/Europe/Prague /etc/localtime
ENV PGTZ Europe/Prague

CMD sleep infinity
