FROM opensuse:13.2
MAINTAINER Nathan Cutler <ncutler@suse.com>

# first, install dependencies
RUN zypper --no-gpg-checks --non-interactive addrepo http://download.opensuse.org/repositories/home:smithfarm/openSUSE_13.2/home:smithfarm.repo
RUN zypper --no-gpg-checks --non-interactive ref
RUN zypper --no-gpg-checks --non-interactive install perl-App-Dochazka-REST
RUN zypper --no-gpg-checks --non-interactive install git
RUN zypper --no-gpg-checks --non-interactive install vim
RUN zypper --no-gpg-checks --non-interactive remove perl-App-Dochazka-REST

# postresql setup
RUN su - postgres -c '/usr/bin/initdb --locale=en_US.UTF-8 --auth="ident" /var/lib/pgsql/data &> initlog'
RUN install -d -o postgres -g postgres -m 700 /var/lib/pgsql/data
COPY bootstrap.sh /tmp/bootstrap.sh
RUN install -m 755 /tmp/bootstrap.sh /root/bootstrap.sh
COPY change_superuser_pwd.sh /tmp/change_superuser_pwd.sh
RUN install -o postgres -g postgres -m 755 /tmp/change_superuser_pwd.sh /var/lib/pgsql/change_superuser_pwd.sh
RUN su - postgres -c '/var/lib/pgsql/change_superuser_pwd.sh'
RUN su - postgres -c "sed -i 's/peer/password/g' /var/lib/pgsql/data/pg_hba.conf"
CMD /root/bootstrap.sh
#CMD su - postgres -c '/usr/lib/postgresql93/bin/pg_ctl start -s -w -D /var/lib/pgsql/data -l /var/lib/pgsql/data/postmaster.log -o ""'
#CMD su - postgres -c '/usr/bin/postgres -D /var/lib/pgsql/data'
#
# clone App::Dochazka::REST source code repository to /root
#WORKDIR /root
#RUN git clone git://github.com/smithfarm/dochazka-rest
