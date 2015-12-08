===================
App::Dochazka::REST
===================
-----------------------------------------------------------------------
REST server component of the Dochazka Attendance & Time Tracking system
-----------------------------------------------------------------------

Documentation 
=============

http://metacpan.org/pod/App::Dochazka::REST

Release management
==================

First, make sure you have :code:`perl-reversion` and :code:`cpan-uploader`
installed. In openSUSE, this means installing the :code:`perl-Perl-Version`
and :code:`perl-CPAN-Uploader` packages.

Second, run the :code:`prerelease.sh` script to bump the version number:

    $ sh prerelease.sh

Now check the git status:

    $ git status
    $ git log --oneline

