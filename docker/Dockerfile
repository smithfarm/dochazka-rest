FROM opensuse:13.2
MAINTAINER Nathan Cutler <ncutler@suse.com>

# configure repo
RUN zypper --no-gpg-checks --non-interactive addrepo http://download.opensuse.org/repositories/home:smithfarm/openSUSE_13.2/home:smithfarm.repo
RUN zypper --no-gpg-checks --non-interactive ref

# install "general utility" packages 
RUN zypper --no-gpg-checks --non-interactive install \
    aaa_base-extras \
    git \
    iproute2 \ 
    net-tools \
    sudo \
    timezone \
    vim

# install App::Dochazka::REST dependencies
RUN zypper --no-gpg-checks --non-interactive install \
    perl-App-CELL \
    perl-App-Dochazka-Common \
    perl-Authen-Passphrase \
    perl-Date-Holidays-CZ \
    perl-DBD-Pg \
    perl-DBIx-Connector \
    perl-HTTP-Message \
    perl-Plack-Middleware-Session \
    perl-Plack \
    perl-Test-JSON \
    perl-Test-Fatal \
    perl-Module-Build \
    perl-Web-Machine \
    perl-Web-MREST \
    perl-Web-MREST-CLI

# add smithfarm user
RUN useradd -d /home/smithfarm -m -s /bin/bash smithfarm
COPY sudoers /tmp/sudoers
RUN install -o root -g root -m 440 /tmp/sudoers /etc/sudoers

# install App::Dochazka::REST site configuration file
COPY REST_SiteConfig.pm /tmp/REST_SiteConfig.pm
RUN install -d -o root -g root -m 755 /etc/dochazka-rest
RUN install -o root -g root -m 644 /tmp/REST_SiteConfig.pm /etc/dochazka-rest/REST_SiteConfig.pm

# set the timezone
RUN ln -sf /usr/share/zoneinfo/Europe/Prague /etc/localtime
ENV PGTZ Europe/Prague

# clone repo
COPY gitconfig /tmp/gitconfig
RUN install -o smithfarm -g users -m 644 /tmp/gitconfig /home/smithfarm/.gitconfig
WORKDIR /home/smithfarm
USER smithfarm
RUN git clone git://github.com/smithfarm/dochazka-rest
WORKDIR /home/smithfarm/dochazka-rest
RUN perl Build.PL
RUN ./Build
RUN sudo ./Build install

CMD sleep infinity
