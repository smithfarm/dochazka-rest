#!/bin/bash
set -e
perl Build.PL
./Build
sudo ./Build install
prove -l t/
