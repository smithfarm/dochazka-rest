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

# ------------------------
# This package, which is between Web::MREST and Web::Dochazka::REST::Dispatch
# in the chain of inheritance, provides the 'is_authorized' and 'forbidden'
# methods called by Web::Machine on each incoming HTTP request
# ------------------------

package App::Dochazka::REST::Auth;

use strict;
use warnings;

use App::CELL qw( $CELL $log $meta $site );
use App::Dochazka::Common qw( $today init_timepiece );
use App::Dochazka::REST;
use App::Dochazka::REST::ConnBank qw( $dbix_conn conn_status );
use App::Dochazka::REST::ACL qw( check_acl );
use App::Dochazka::REST::LDAP qw( ldap_exists ldap_search ldap_auth populate_employee );
use App::Dochazka::REST::Model::Employee qw( nick_exists );
use Authen::Passphrase::SaltedDigest;
use Data::Dumper;
use Params::Validate qw(:all);
use Plack::Session;
use Try::Tiny;
use Web::Machine::Util qw( create_header );
use Web::MREST::InitRouter qw( $resources );

# methods/attributes not defined in this module will be inherited from:
use parent 'Web::MREST::Entity';


=head1 NAME

App::Dochazka::REST::Auth - HTTP request authentication and authorization



=head1 SYNOPSIS

To be determined



=head1 DESCRIPTION

To be determined

=cut




=head1 METHODS



=head2 is_authorized

This overrides the L<Web::Machine> method of the same name.

Authenticate the originator of the request, using HTTP Basic Authentication.
Upon successful authentication, check that the user (employee) exists in 
the database (create if necessary) and retrieve her EID. Push the EID and
current privilege level onto the context. Get the user's L<DBIx::Connector>
object and push that onto the context, too.

=cut

sub is_authorized {
    my ( $self, $auth_header ) = @_;
    
    App::Dochazka::REST::ConnBank::init_singleton();

    if ( ! $meta->META_DOCHAZKA_UNIT_TESTING ) {
        return 1 if $self->_validate_session;
    }
    if ( $auth_header ) {
        $log->debug("is_authorized: auth header is $auth_header" );
        my $username = $auth_header->username;
        my $password = $auth_header->password;
        my $auth_status = $self->_authenticate( $username, $password );
        if ( $auth_status->ok ) {
            my $emp = $auth_status->payload;
            $self->push_onto_context( { 
                current => $emp->TO_JSON,
                current_obj => $emp,
                current_priv => $emp->priv( $dbix_conn ),
                dbix_conn => $dbix_conn,
            } );
            $self->_init_session( $emp ) unless $meta->META_DOCHAZKA_UNIT_TESTING;
            return 1;
        }
    }
    return create_header(
        'WWWAuthenticate' => [ 
            'Basic' => ( 
                realm => $site->DOCHAZKA_BASIC_AUTH_REALM 
            ) 
        ]
    ); 
}


=head3 _init_session

Initialize the session. Takes an employee object.

=cut

sub _init_session {
    my $self = shift;
    my ( $emp ) = validate_pos( @_, { type => HASHREF, can => 'eid' } );
    my $session = Plack::Session->new( $self->request->{'env'} );
    $session->set( 'eid', $emp->eid );
    $session->set( 'ip_addr', $self->request->{'env'}->{'REMOTE_ADDR'} );
    $session->set( 'last_seen', time );
    return;
}


=head3 _validate_session

Validate the session

=cut

sub _validate_session {
    my ( $self ) = @_;

    my $r = $self->request;
    my $session = Plack::Session->new( $r->{'env'} );
    my $remote_addr = $$r{'env'}{'REMOTE_ADDR'};

    $self->push_onto_context( { 'session' => $session->dump  } );
    $self->push_onto_context( { 'session_id' => $session->id } );
    $log->debug( "Session ID is " . $session->id );
    #$log->debug( "Remote address is " . $remote_addr );
    $log->debug( "Session EID is " . 
        ( $session->get('eid') ? $session->get('eid') : "not present") );
    #$log->debug( "Session IP address is " . 
    #    ( $session->get('ip_addr') ? $session->get('ip_addr') : "not present" ) );
    #$log->debug( "Session last_seen is " . 
    #    ( $session->get('last_seen') ? $session->get('last_seen') : "not present" ) );

    # validate session:
    if ( $session->get('eid') and 
         $session->get('ip_addr') and 
         $session->get('last_seen') and
         $session->get('ip_addr') eq $remote_addr and
         _is_fresh( $session->get('last_seen') ) ) 
    {
        $log->debug( "Existing session!" );
        my $emp = App::Dochazka::REST::Model::Employee->load_by_eid( $dbix_conn, $session->get('eid') )->payload;
        die "missing employee object in session management" 
            unless $emp->isa( "App::Dochazka::REST::Model::Employee" ); 
        $self->push_onto_context( { 
            current => $emp->TO_JSON, 
            current_obj => $emp,
            current_priv => $emp->priv( $dbix_conn ),
            dbix_conn => $dbix_conn,
        } );
        $session->set('last_seen', time); 
        return 1;
    }

    $session->expire if $session->get('eid');  # invalid session: delete it
    return;
}


=head3 _is_fresh

Takes a single argument, which is assumed to be number of seconds since
epoch when the session was last seen. This is compared to "now" and if the
difference is greater than the DOCHAZKA_REST_SESSION_EXPIRATION_TIME site
parameter, the return value is false, otherwise true.

=cut

sub _is_fresh {
    my ( $last_seen ) = validate_pos( @_, { type => SCALAR } );
    return ( time - $last_seen > $site->DOCHAZKA_REST_SESSION_EXPIRATION_TIME )
        ? 0
        : 1;
}


=head3 _authenticate

Authenticate the nick associated with an incoming REST request.  Takes a nick
and a password (i.e., a set of credentials). Returns a status object, which
will have level 'OK' on success (with employee object in the payload), 'NOT_OK'
on failure. In the latter case, there will be a declared status.

=cut

sub _authenticate {
    my ( $self, $nick, $password ) = @_;
    my ( $status, $emp );

    # empty credentials: fall back to demo/demo
    if ( $nick ) {
        $log->notice( "Login attempt from $nick" );
    } else {
        $log->notice( "Login attempt from (anonymous) -- defaulting to demo/demo" );
        $nick = 'demo'; 
        $password = 'demo'; 
    }

    $log->debug( "\$site->DOCHAZKA_LDAP is " . $site->DOCHAZKA_LDAP );

    # check if LDAP is enabled and if the employee exists in LDAP
    if ( ! $meta->META_DOCHAZKA_UNIT_TESTING and 
         $site->DOCHAZKA_LDAP and
         ldap_exists( $nick ) 
    ) {

        $log->info( "Detected authentication attempt from $nick, a known LDAP user" );

        # - authenticate by LDAP bind
        if ( ldap_auth( $nick, $password ) ) {
            # successful LDAP auth
            # if the employee doesn't exist in the database, possibly autocreate
            if ( ! nick_exists( $dbix_conn, $nick ) ) {
                $log->info( "There is no employee $nick in the database: auto-creating" );
                if ( $site->DOCHAZKA_LDAP_AUTOCREATE ) {
                    my $emp = App::Dochazka::REST::Model::Employee->spawn(
                        nick => $nick,
                        remark => 'LDAP autocreate',
                    );
                    populate_employee( $emp );
                    my $faux_context = { 'dbix_conn' => $dbix_conn, 'current' => { 'eid' => 1 } };
                    $status = $emp->insert( $faux_context );
                    if ( $status->not_ok ) {
                        $log->crit("Could not create $nick as new employee");
                        return $CELL->status_not_ok( 'DOCHAZKA_EMPLOYEE_AUTH' );
                    }
                    $log->notice( "Auto-created employee $nick, who was authenticated via LDAP" );
                    if ( my $priv = $site->DOCHAZKA_LDAP_AUTOCREATE_AS ) {
                        if ( $priv eq 'passerby' ) {
                            # do nothing
                        } elsif ( $priv =~ m/^(inactive)|(active)$/ ) {
                            init_timepiece();
                            my $ph_obj = App::Dochazka::REST::Model::Privhistory->spawn(
                                eid => $emp->eid,
                                priv => $priv,
                                effective => ( $today . ' 00:00' ),
                                remark => 'LDAP autocreate',
                            );
                            $status = $ph_obj->insert( $faux_context );
                            $log->error("Could not add priv history record for LDAP-autocreated " .
                                " employee ->$nick<- ; reason was " . $status->text )
                                if $status->not_ok;
                        } else {
                            $log->error( "Site configuration parameter DOCHAZKA_LDAP_AUTOCREATE_AS " .
                                         "is invalid" );
                        }
                    }
                } else {
                    $log->notice( "Authentication attempt from LDAP user $nick failed " . 
                                  "because the user is not in the database and " . 
                                  "DOCHAZKA_LDAP_AUTOCREATE is not enabled" );
                    return $CELL->status_not_ok( 'DOCHAZKA_EMPLOYEE_AUTH' );
                }
            }
        } else {
            return $CELL->status_not_ok( 'DOCHAZKA_EMPLOYEE_AUTH' );
        }

        # load the employee object
        my $emp = App::Dochazka::REST::Model::Employee->load_by_nick( $dbix_conn, $nick )->payload;
        die "missing employee object in _authenticate" unless ref($emp) eq "App::Dochazka::REST::Model::Employee";
        return $CELL->status_ok( 'DOCHAZKA_EMPLOYEE_AUTH', payload => $emp );
    }

    # if not, authenticate against the password stored in the employee object.
    else {

        $log->notice( "Employee $nick not found in LDAP; reverting to internal auth" );

        # - check if this employee exists in database
        my $emp = nick_exists( $dbix_conn, $nick );

        if ( ! defined( $emp ) or ! $emp->isa( 'App::Dochazka::REST::Model::Employee' ) ) {
            $log->notice( "Rejecting login attempt from unknown user $nick" );
            $self->mrest_declare_status( explanation => "Authentication failed for user $nick", permanent => 1 );
            return $CELL->status_not_ok;
        }

        # - the password might be empty
        $password = '' unless defined( $password );
        my $passhash = $emp->passhash;
        $passhash = '' unless defined( $passhash );

        # - check password against passhash 
        my ( $ppr, $status );
        try {
            $ppr = Authen::Passphrase::SaltedDigest->new(
                algorithm => "SHA-512",
                salt_hex => $emp->salt,
                hash_hex => $emp->passhash,
            );
        } catch {
            $status = $CELL->status_err( 'DOCHAZKA_PASSPHRASE_EXCEPTION', args => [ $_ ] );
        };

        if ( ref( $ppr ) ne 'Authen::Passphrase::SaltedDigest' ) {
            $log->crit( "employee $nick has invalid passhash and/or salt" );
            return $CELL->status_not_ok( 'DOCHAZKA_EMPLOYEE_AUTH' );
        }
        if ( $ppr->match( $password ) ) {
            $log->notice( "Internal auth successful for employee $nick" );
            return $CELL->status_ok( 'DOCHAZKA_EMPLOYEE_AUTH', payload => $emp );
        } else {
            $self->mrest_declare_status( explanation => 
                "Internal auth failed for known employee $nick (mistyped password?)" 
            );
            return $CELL->status_not_ok;
        }
    }
}            


=head2 forbidden

This overrides the L<Web::Machine> method of the same name.

Authorization (ACL check) method.

First, parse the path and look at the method to determine which controller
action the user is asking us to perform. Each controller action has an ACL
associated with it, from which we can determine whether employees of each of
the four different privilege levels are authorized to perform that action.  

Requests for non-existent resources will always pass the ACL check.

=cut

sub forbidden {
    my ( $self ) = @_;
    $log->debug( "Entering " . __PACKAGE__ . "::forbidden" );

    my $method = $self->context->{'method'};
    my $resource_name = $self->context->{'resource_name'};

    # if there is no handler on the context, the URL is invalid so we
    # just pass on the request 
    if ( not exists $self->context->{'handler'} ) {
        $log->debug("forbidden: no handler on context, passing on this request");
        return 0;
    }

    my $resource_def = $resources->{$resource_name}->{$method};

    # now we get the ACL profile.  There are three possibilities: 
    # 1. acl_profile property does not exist => fail
    # 2. single ACL profile for the entire resource
    # 3. separate ACL profiles for each HTTP method
    my ( $acl_profile_prop, $acl_profile );
    SKIP: { 

        # check acl_profile property 
        if ( exists( $resource_def->{'acl_profile'} ) ) {
            $acl_profile_prop = $resource_def->{'acl_profile'};
        } else {
            $log->notice( "Resource $resource_name has no acl_profile property; ACL check will fail" );
            last SKIP;
        } 

        # got the property, process it
        if ( ! ref( $acl_profile_prop ) ) {
            $acl_profile = $acl_profile_prop;
            $log->debug( "ACL profile for all methods is " . ( $acl_profile || "undefined" ) );
        } elsif ( ref( $acl_profile_prop ) eq 'HASH' ) {
            $acl_profile = $acl_profile_prop->{$method};
            $log->debug( "ACL profile for $method requests is " . ( $acl_profile || "undefined" ) );
        } else {
            $self->mrest_declare_status( code => 500, explanation => 
                "Cannot determine ACL profile of resource!!! Path is " . $self->context->{'path'},
                permanent => 1 );
            return 1;
        }
    }
    # push ACL profile onto context
    $self->push_onto_context( { 'acl_profile' => $acl_profile } );

    # determine privlevel of our user
    my $acl_priv = $self->context->{'current_priv'};
    $log->debug( "My ACL level is $acl_priv and the ACL profile of this resource is "
        . ( $acl_profile || "undefined" ) );

    # compare the two
    my $acl_check_passed = check_acl( $acl_profile, $acl_priv );
    if ( $acl_check_passed ) {
        $log->debug( "ACL check passed" );
        $self->push_onto_context( { 'acl_priv' => $acl_priv } );
        return 0;
    }
    $self->mrest_declare_status( explanation => 'DISPATCH_ACL_CHECK_FAILED', 
        args => [ $resource_name ] );
    return 1;
}

1;
