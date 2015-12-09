===================
App::Dochazka::REST
===================
-----------------------------------------------------------------------
REST server component of the Dochazka Attendance & Time Tracking system
-----------------------------------------------------------------------

Documentation 
=============

http://metacpan.org/pod/App::Dochazka::REST

Docker container
================

This release includes a :code:`Dockerfile` that can be used to create
a Dockerized testing environment. Cheatsheet follows: ::

    $ cd docker/
    $ docker build -t dochazka-rest .
    $ docker run -it dochazka-rest

This should start the container and give you a bash prompt with PostgreSQL
running in the background.

Release management
==================

First, make sure you have :code:`perl-reversion` and :code:`cpan-uploader`
installed. In openSUSE, this means installing the :code:`perl-Perl-Version`
and :code:`perl-CPAN-Uploader` packages.

Second, run the :code:`prerelease.sh` script to bump the version number,
commit all outstanding modifications, add a git tag, and append draft
Changes file entry: ::

    $ sh prerelease.sh

Third, push the changes to GitHub: ::

    $ git push --follow-tags

Fourth, optionally run the release script to push the release to OBS 
and CPAN: ::

    $ sh release.sh

