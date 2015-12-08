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

Second, run the :code:`prerelease.sh` script to bump the version number,
commit all outstanding modifications, add a git tag, and append draft
Changes file entry: ::

    $ sh prerelease.sh

Third, push the changes to GitHub: ::

    $ git push --follow-tags

Fourth, optionally run the release script to push the release to OBS 
and CPAN: ::

    $ sh release.sh

