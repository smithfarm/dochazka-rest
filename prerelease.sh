#!/bin/bash
perl-reversion -bump
perl Build.PL
./Build distmeta
perl-reversion | tail -n1
