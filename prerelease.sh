#!/bin/bash
perl-reversion -bump
perl Build.PL
./Build distmeta
perl-reversion | tail -n1
VERSION=$(grep -P 'Version \d\.*\d{3,3}' lib/App/Dochazka/REST.pm | cut -d' ' -f2)
echo $VERSION >>Changes
git --no-pager log $(git describe --tags --abbrev=0)..HEAD --oneline --no-color >>Changes
git commit -as -m $VERSION
git tag -m $VERSION $VERSION
echo "Now edit Changes"
