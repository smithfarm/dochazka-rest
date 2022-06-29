#!/bin/bash
set -e
sudo zypper --gpg-auto-import-keys --non-interactive refresh
# Checking prerequisites...
#   requires:
#     !  Authen::Passphrase::SaltedDigest is not installed
#     !  DBD::Pg is not installed
#     !  DBIx::Connector is not installed
#     !  Date::Calc is not installed
#     !  Date::Holidays::CZ is not installed
#     !  Mason is not installed
#   build_requires:
#     !  Authen::Passphrase::SaltedDigest is not installed
#     !  DBIx::Connector is not installed
#     !  Date::Holidays::CZ is not installed
#     !  Mason is not installed
sudo zypper --non-interactive install \
    perl-Authen-Passphrase \
    perl-DBD-Pg \
    perl-DBIx-Connector \
    perl-Date-Calc \
    perl-Date-Holidays-CZ \
    perl-Mason
