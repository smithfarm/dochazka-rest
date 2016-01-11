#
# dochazka Docker container
#
FROM opensuse:42.1
MAINTAINER Nathan Cutler <ncutler@suse.com>

# configure repo
RUN zypper --no-gpg-checks --non-interactive addrepo http://download.opensuse.org/repositories/home:smithfarm/openSUSE_Leap_42.1/home:smithfarm.repo
RUN zypper --no-gpg-checks --non-interactive ref

# install "general utility" packages 
RUN zypper --no-gpg-checks --non-interactive install \
    timezone

# install App::Dochazka::REST dependencies
RUN zypper --no-gpg-checks --non-interactive install \
    perl-App-Dochazka-REST

# install App::Dochazka::REST site configuration file
COPY REST_SiteConfig.pm /tmp/REST_SiteConfig.pm
RUN install -d -o root -g root -m 755 /etc/dochazka-rest
RUN install -o root -g root -m 644 /tmp/REST_SiteConfig.pm /etc/dochazka-rest/REST_SiteConfig.pm

# create Docker state directory
RUN install -d -o root -g root -m 777 /var/lib/dochazka

# set the timezone
RUN ln -sf /usr/share/zoneinfo/Europe/Prague /etc/localtime
ENV PGTZ Europe/Prague

# start the server
CMD [ "initialize" ]
ENTRYPOINT [ "dochazka-rest" ]
