#!/bin/bash
# generic release script
# meant to be run from the distro directory
CPAN_NAME=$(cat CPAN_NAME)
OBS_NAME="perl-$CPAN_NAME"
OBS_DIR="$HOME/home:smithfarm/$OBS_NAME/"
perl Build.PL
./Build distmeta
./Build dist
( cd $OBS_DIR ; osc -A https://api.opensuse.org/ up ; osc rm -f $CPAN_NAME-*.tar.gz )
cp $CPAN_NAME-*.tar.gz $OBS_DIR
./Build distclean
( cd $OBS_DIR ; osc service dr ; osc add $CPAN_NAME-*.tar.gz ; osc -A https://api.opensuse.org/ commit )
#( cd $OBS_DIR ; cpan-upload -u SMITHFARM $CPAN_NAME-*.tar.gz )
