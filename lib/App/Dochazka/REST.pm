# ************************************************************************* 
# Copyright (c) 2014-2015, SUSE LLC
# 
# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
# 1. Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
# 
# 2. Redistributions in binary form must reproduce the above copyright
# notice, this list of conditions and the following disclaimer in the
# documentation and/or other materials provided with the distribution.
# 
# 3. Neither the name of SUSE LLC nor the names of its contributors may be
# used to endorse or promote products derived from this software without
# specific prior written permission.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
# ************************************************************************* 

package App::Dochazka::REST;

use 5.012;
use strict;
use warnings;

use App::CELL qw( $CELL $log $meta $core $site );
use App::Dochazka::REST::ConnBank qw( $dbix_conn );
use File::Path;
use File::ShareDir;
use File::Spec;
use Log::Any::Adapter;
use Params::Validate qw( :all );
use Try::Tiny;
use Web::Machine;
use Web::MREST::CLI qw( normalize_filespec );



=head1 NAME

App::Dochazka::REST - Dochazka REST server



=head1 VERSION

Version 0.525

=cut

our $VERSION = '0.525';


=head2 Development status

Alpha.



=head1 SYNOPSIS

Start the server with default settings:

    $ dochazka-rest

Point browser to:

    http://localhost:5000/

Use L<App::Dochazka::CLI> command-line interface to access full functionality:

    $ dochazka-cli



=head1 DESCRIPTION

This distribution, L<App::Dochazka::REST>, including all the modules in C<lib/>,
the scripts in C<bin/>, and the configuration files in C<config/>,
constitutes the REST server (API) component of Dochazka, the open-source
Attendance/Time Tracking (ATT) system. 

Dochazka as a whole aims to be a convenient, open-source ATT solution.



=head1 ARCHITECTURE

Dochazka consists of four main components:

=over

=item * Dochazka clients

=item * REST server (this module)

=item * PostgreSQL database

=item * Data model

=back

In a nutshell, clients attempt to translate user intent into REST API
calls, which are transmitted over a network (using the HTTP protocol) to
the server. The server processes incoming HTTP requests. Requests for 
valid REST resources are passed to the API for processing and errors are
generated for invalid requests. The result is returned to the client in
an HTTP response. The REST API uses the PostgreSQL server to save state.
The clients and the REST API use the data model to represent and manipulate
objects.



=head1 DOCUMENTATION

=over

=item * L<App::Dochazka::REST::Guide>

A detailed guide to the REST server.

=item * L<App::Dochazka::REST::Docs::Resources>

Dochazka REST API documentation.

=item * L<App::Dochazka::Common>

Dochazka data model and other bits used by all Dochazka components.

=item * L<App::Dochazka::CLI> and L<App::Dochazka::CLI::Guide>

Reference Dochazka command-line client.

=item * L<App::Dochazka::WWW>

Reference Dochazka WWW client.

=over



=head1 FUNCTIONS


=head2 run_sql

Takes a L<DBIx::Connector> object and an array of SQL statements. Runs them 
one by one until an exception is thrown or the last statement completes
successfully. Returns a status object which will be either OK or ERR.
If NOT_OK, the error text will be in C<< $status->text >>.

=cut

sub run_sql {
    my ( $conn, @stmts ) = @_;
    my $status;
    try {
        foreach my $stmt ( @stmts ) {
            $log->debug( "Running SQL statement $stmt" );
            $conn->run( fixup => sub { $_->do( $stmt ); } );
        }
    } catch {
        $status = $CELL->status_err( 'DOCHAZKA_DBI_ERR', args => [ $_ ] );
    };
    return $status if $status;
    return $CELL->status_ok;
}


sub _do_audit_triggers {
    my ( $mode, $conn ) = @_;

    my $sql;
    if ( $mode eq 'create' ) {
        $sql = $site->DBINIT_CREATE_AUDIT_TRIGGERS;
    } elsif ( $mode eq 'delete' ) {
        $sql = $site->DBINIT_DELETE_AUDIT_TRIGGERS;
    } else {
        die "AAADFDGGGGGGAAAAAAAHHH! " . __PACKAGE__ . "::_do_audit_triggers";
    }

    my @prepped_sql;
    foreach my $table ( @{ $site->DOCHAZKA_AUDIT_TABLES } ) {
        my $sql_copy = $sql;
        my $question_mark = quotemeta('?');
        $log->debug( "Replacing question mark with $table" );
        $sql_copy =~ s{$question_mark}{$table};
        push( @prepped_sql, $sql_copy );
    }
    my $status = run_sql( 
        $conn, 
        @prepped_sql,
    );
    return $status;
}


=head2 create_audit_triggers

Create the audit triggers. Wrapper for _do_audit_triggers

=cut

sub create_audit_triggers {
    my $conn = shift;
    return _do_audit_triggers( 'create', $conn );
}
    

=head2 delete_audit_triggers

Delete the audit triggers. Wrapper for _do_audit_triggers

=cut

sub delete_audit_triggers {
    my $conn = shift;
    return _do_audit_triggers( 'delete', $conn );
}
    

=head2 reset_mason_dir

Wipe out and re-create the Mason state directory. Returns status object.
Upon success, level will be 'OK' and payload will contain the full path
to the Mason component root.

=cut

sub reset_mason_dir {
    my $status;

    # wipe out
    my $statedir = $site->DOCHAZKA_STATE_DIR;
    die "OUCH!!! DOCHAZKA_STATE_DIR site parameter not defined!" unless $statedir;
    die "OUCH!!! DOCHAZKA_STATE_DIR is not readable by me!" unless -r $statedir;
    die "OUCH!!! DOCHAZKA_STATE_DIR is not writable by me!" unless -w $statedir;
    die "OUCH!!! DOCHAZKA_STATE_DIR is not executable by me!" unless -x $statedir;
    my $masondir = File::Spec->catfile( $statedir, 'Mason' );
    $log->debug( "Mason directory is $masondir" );
    rmtree( $masondir );
    mkpath( $masondir, 0, 0750 );

    # re-create
    my $comp_root = File::Spec->catfile( $masondir, 'comp_root' );
    mkpath( $comp_root, 0, 0750 );
    my $data_dir = File::Spec->catfile( $masondir, 'data_dir' );
    mkpath( $data_dir, 0, 0750 );
    $status = App::Dochazka::REST::Mason::init_singleton( 
        comp_root => $comp_root, 
        data_dir => $data_dir 
    );
    return $status unless $status->ok;
    $status->payload( $comp_root );
    return $status;
}


=head2 initialize_activities_table

Create the activities defined in the site parameter
DOCHAZKA_ACTIVITY_DEFINITIONS

=cut

sub initialize_activities_table {
    my $conn = shift;
    my $status = $CELL->status_ok;
    try {
        $conn->txn( fixup => sub {
            my $sth = $_->prepare( $site->SQL_ACTIVITY_INSERT );
            foreach my $actdef ( @{ $site->DOCHAZKA_ACTIVITY_DEFINITIONS } ) {
                $sth->bind_param( 1, $actdef->{code} );
                $sth->bind_param( 2, $actdef->{long_desc} );
                $sth->bind_param( 3, 'dbinit' );
                $sth->execute;
            }
        } );
    } catch {
        $status = $CELL->status_err( 'DOCHAZKA_DBI_ERR', args => [ $_ ] );
    };
    return $status;
}


=head2 reset_db

Drop and re-create a Dochazka database. Takes superuser credentials as
arguments. 

Be very, _very_, _VERY_ careful with this function.

=cut

sub reset_db {
    my ( $superuser, $superpass ) = @_;

    my $status;
    my $dbname = $site->DOCHAZKA_DBNAME;
    my $dbuser = $site->DOCHAZKA_DBUSER;
    my $dbpass = $site->DOCHAZKA_DBPASS;
    $log->debug( "Entering " . __PACKAGE__ . "::reset_db to (re-)initialize database $dbname with superuser credentials $superuser / $superpass" );

    # PGTZ *must* be set
    $ENV{'PGTZ'} = $site->DOCHAZKA_TIMEZONE;

    my $conn = App::Dochazka::REST::ConnBank::get_arbitrary_dbix_conn(
        'postgres', $superuser, $superpass
    );
    $status = run_sql( 
        $conn,
        "DROP DATABASE IF EXISTS \"$dbname\"",
        "DROP ROLE IF EXISTS $dbuser",
        "CREATE ROLE \"$dbuser\" WITH LOGIN PASSWORD '$dbpass'",
        "CREATE DATABASE \"$dbname\"",
        "REVOKE CONNECT ON DATABASE \"$dbname\" FROM PUBLIC",
    );
    return $status unless $status->ok;

    # create:
    # - audit schema (see config/sql/audit_Config.pm)
    # - public schema (all application-specific tables, functions, triggers, etc.)
    # - the 'root' and 'demo' employees
    # - privhistory record for root
    $conn = App::Dochazka::REST::ConnBank::get_arbitrary_dbix_conn(
        $dbname, $superuser, $superpass
    );
    $status = run_sql(
        $conn,
        @{ $site->DBINIT_AUDIT },
        @{ $site->DBINIT_CREATE },
    );
    return $status unless $status->ok;

    # get EID of root employee that was just created, since
    # we will need it in the second round of SQL statements
    my $eids = get_eid_of( $conn, "root", "demo" );
    $site->set( 'DOCHAZKA_EID_OF_ROOT', $eids->{'root'} );
    $site->set( 'DOCHAZKA_EID_OF_DEMO', $eids->{'demo'} );

    # the second round of SQL statements to make root employee immutable
    # is taken from DBINIT_MAKE_ROOT_IMMUTABLE site param

    # prep DBINIT_MAKE_ROOT_IMMUTABLE
    # (replace ? with EID of root employee in all the statements
    # N.B.: we avoid the /r modifier here because we might be using Perl # 5.012)
    my @root_immutable_statements = map { 
        local $_ = $_; s/\?/$eids->{'root'}/g; $_; 
    } @{ $site->DBINIT_MAKE_ROOT_IMMUTABLE };

    # prep DBINIT_GRANTS (replace the strings '$dbuser' and '$dbpass' with
    # the DOCHAZKA_DBUSER and DOCHAZKA_DBPASS site params, respectively
    my $dbname_search = quotemeta( '$dbname' );
    my $dbuser_search = quotemeta( '$dbuser' );
    my $dbpass_search = quotemeta( '$dbpass' );
    my @grants = map {
        local $_ = $_; 
        s{$dbname_search}{$dbname}g; 
        s{$dbuser_search}{$dbuser}g; 
        s{$dbpass_search}{$dbpass}g; 
        $_; 
    } @{ $site->DBINIT_GRANTS };

    # run the modified statements
    $status = run_sql(
        $conn,
        @root_immutable_statements,
        @grants,
    );
    return $status unless $status->ok;

    # insert initial set of activities
    $status = initialize_activities_table( $conn );
    
    # insert initial set of components
    try {
        $conn->txn( fixup => sub {
            my $sth = $_->prepare( $site->SQL_COMPONENT_INSERT );
            foreach my $actdef ( @{ $site->DOCHAZKA_COMPONENT_DEFINITIONS } ) {
                $actdef->{'validations'} = undef unless exists( $actdef->{'validations'} );
                $sth->bind_param( 1, $actdef->{path} );
                $sth->bind_param( 2, $actdef->{source} );
                $sth->bind_param( 3, $actdef->{acl} );
                $sth->bind_param( 4, $actdef->{validations} );
                $sth->execute;
            }
        } );
    } catch {
        $status = $CELL->status_err( 'DOCHAZKA_DBI_ERR', args => [ $_ ] );
    };
    return $status unless $status->ok;
    
    # if auditing is enabled, create the audit triggers
    if ( $site->DOCHAZKA_AUDITING ) {
        $status = create_audit_triggers( $conn );
        return $status unless $status->ok;
    }
    
    $log->notice( "Database $dbname successfully (re-)initialized" );
    return $status;
}


=head2 get_eid_of

Obtain the EIDs of a list of employee nicks. Returns a reference to a hash
where the keys are the nicks and the values are the corresponding EIDs.

NOTE 1: This routine expects to receive a L<DBIx::Connector> object as its
first argument. It does not use the C<$dbix_conn> singleton.

NOTE 2: The nicks are expected to exist and no provision (other than logging a
DOCHAZKA_DBI_ERR) is made for their non-existence.

=cut

sub get_eid_of {
    my ( $conn, @nicks ) = @_;
    $log->debug( "Entering " . __PACKAGE__ . "::get_eid_of" );
    my ( %eids, $status );
    try {
        $conn->run( fixup => sub { 
            my $sth = $_->prepare( $site->DBINIT_SELECT_EID_OF );
            foreach my $nick ( @nicks ) {
                $sth->bind_param( 1, $nick );
                $sth->execute;
                ( $eids{$nick} ) = $sth->fetchrow_array();
                $log->debug( "EID of $nick is $eids{$nick}" );
            }
        } );
    } catch {
        $CELL->status_err( 'DOCHAZKA_DBI_ERR', args => [ $_ ] );
    };
    return \%eids;
}


=head2 version

Accessor method (to be called like a constructor) providing access to C<$VERSION> variable

=cut

sub version { $VERSION; }



=head1 GLOSSARY OF TERMS

In Dochazka, some commonly-used terms have special meanings:

=over

=item * B<employee> -- 
Regardless of whether they are employees in reality, for the
purposes of Dochazka employees are the folks whose attendance/time is being
tracked.  Employees are expected to interact with Dochazka using the
following functions and commands.

=item * B<administrator> -- 
In Dochazka, administrators are employees with special powers. Certain
REST/CLI functions are available only to administrators.

=item * B<CLI client> --
CLI stands for Command-Line Interface. The CLI client is the Perl script
that is run when an employee types C<dochazka> at the bash prompt.

=item * B<REST server> --
REST stands for ... . The REST server is a collection of Perl modules 
running on a server at the site.

=item * B<site> --
In a general sense, the "site" is the company, organization, or place that
has implemented (installed, configured) Dochazka for attendance/time
tracking. In a technical sense, a site is a specific instance of the
Dochazka REST server that CLI clients connect to.

=back



=head1 AUTHOR

Nathan Cutler, C<< <ncutler@suse.cz> >>




=head1 BUGS

To report bugs or request features, use the GitHub issue tracker at
L<https://github.com/smithfarm/dochazka-rest/issues>.




=head1 SUPPORT

The full documentation comes with the distro, and can be comfortable
perused at metacpan.org:

    https://metacpan.org/pod/App::Dochazka::REST

You can also read the documentation for individual modules using the
perldoc command, e.g.:

    perldoc App::Dochazka::REST
    perldoc App::Dochazka::REST::Model::Activity

Other resources:

=over 4

=item * GitHub issue tracker (report bugs here)

L<https://github.com/smithfarm/dochazka-rest>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/App-Dochazka-REST>

=back




=head1 LICENSE AND COPYRIGHT

Copyright (c) 2014-2015, SUSE LLC
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
this list of conditions and the following disclaimer in the documentation
and/or other materials provided with the distribution.

3. Neither the name of SUSE LLC nor the names of its contributors
may be used to endorse or promote products derived from this software without
specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut

1; # End of App::Dochazka::REST
