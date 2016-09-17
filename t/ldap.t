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
#
# LDAP authentication unit - runs only if $site->DOCHAZKA_LDAP is true
#

#!perl
use 5.012;
use strict;
use warnings;

#use App::CELL::Test::LogToFile;
use App::CELL qw( $meta $site );
use Data::Dumper;
use App::Dochazka::REST::ConnBank qw( $dbix_conn );
use App::Dochazka::REST::Model::Employee qw( nick_exists );
use App::Dochazka::REST::Test;
use Plack::Test;
use Test::More;
use Test::Warnings;


note( 'initialize, connect to database, and set up a testing plan' );
my $app = initialize_regression_test();

note( 'instantiate Plack::Test object' );
my $test = Plack::Test->create( $app );
isa_ok( $test, 'Plack::Test::MockHTTP' );

SKIP: {
    skip "LDAP testing disabled", 2 unless $site->DOCHAZKA_LDAP;
    diag( "DOCHAZKA_LDAP is " . $site->DOCHAZKA_LDAP );

    note( 'known existent LDAP user exists in LDAP' );
    ok( App::Dochazka::REST::LDAP::ldap_exists( 
        $site->DOCHAZKA_LDAP_TEST_UID_EXISTENT
    ) );

    note( 'known non-existent LDAP user does not exist in LDAP' );
    ok( ! App::Dochazka::REST::LDAP::ldap_exists( 
        $site->DOCHAZKA_LDAP_TEST_UID_NON_EXISTENT
    ) );

    note( 'create object for LDAP user' );
    my $uid = $site->DOCHAZKA_LDAP_TEST_UID_EXISTENT;
    my $emp = App::Dochazka::REST::Model::Employee->spawn(
        'nick' => $uid,
        'sync' => 1,
    );

    note( "Populate $uid employee object from LDAP" );
    my $throwaway_emp = $emp->clone();
    my $status = $throwaway_emp->ldap_sync();
    is( $status->level, 'OK' );

    note( "Make a pristine employee object" );
    my $pristine = App::Dochazka::REST::Model::Employee->spawn(
        'nick' => 'root',
        'sync' => 1,
    );
    is( $pristine->nick, 'root', "Employee we just created has nick root" );

    note( "Pristine employee object has non-nick properties unpopulated" );
    my @props = grep( !/^nick/, keys( %{ $site->DOCHAZKA_LDAP_MAPPING } ) );
    foreach my $prop ( @props ) {
        is( $pristine->{$prop}, undef, "$prop property is undef" );
    }

    note( "System users cannot be synced from LDAP" );
    $status = $pristine->ldap_sync();
    ok( $status->not_ok, "Employee sync operation failed" );
    is( $status->code, 'DOCHAZKA_LDAP_SYSTEM_USER_NOSYNC', "and for the right reason" );

    note( "Change nick to $uid" );
    $pristine->nick( $uid );

    note( "Populate pristine employee object from LDAP: succeed" );
    $status = $pristine->ldap_sync();
    diag( Dumper $status ) unless $status->ok;
    ok( $status->ok, "Employee sync operation succeeded" );
    is( $status->code, 'DOCHAZKA_LDAP_SYNC_SUCCESS' );

    note( "Mapped properties now have values" );
    foreach my $prop ( @props ) {
        ok( $pristine->{$prop}, "$prop property has value " . $pristine->{$prop} );
    }

    note( "GET employee/nick/:nick/ldap 1" );
    $uid = $site->DOCHAZKA_LDAP_TEST_UID_NON_EXISTENT;
    req( $test, 404, 'root', 'GET', "employee/nick/$uid/ldap" );

    note( "GET employee/nick/:nick/ldap 2" );
    $uid = $site->DOCHAZKA_LDAP_TEST_UID_EXISTENT;
    $status = req( $test, 200, 'root', 'GET', "employee/nick/$uid/ldap" );
    is( $status->level, 'OK' );

    note( "PUT employee/nick/:nick/ldap 1" );
    $uid = $site->DOCHAZKA_LDAP_TEST_UID_NON_EXISTENT;
    req( $test, 404, 'root', 'PUT', "employee/nick/$uid/ldap" );

    note( 'LDAP user does not exist in Dochazka database' );
    $emp->delete( $faux_context );
    $status = App::Dochazka::REST::Model::Employee->load_by_nick( $dbix_conn, $uid ); 
    is( $status->level, 'NOTICE' );
    is( $status->code, 'DISPATCH_NO_RECORDS_FOUND', "nick doesn't exist" );
    is( $status->{'count'}, 0, "nick doesn't exist" );
    ok( ! exists $status->{'payload'} );
    ok( ! defined( $status->payload ) );

    note( "PUT employee/nick/:nick/ldap 2" );
    $uid = $site->DOCHAZKA_LDAP_TEST_UID_EXISTENT;
    $status = req( $test, 200, 'root', 'PUT', "employee/nick/$uid/ldap" );
    is( $status->level, 'OK' );

    note( 'Employee now exists in Dochazka database' );
    $status = $emp->load_by_nick( $dbix_conn, $uid );
    is( $status->code, 'DISPATCH_RECORDS_FOUND', "Nick $uid exists" );
    $emp = $status->payload;
    is( $emp->nick, $uid, "Nick is the right string" );

    note( "Mapped properties have values" );
    foreach my $prop ( @props ) {
        ok( $pristine->{$prop}, "$prop property has value " . $emp->{$prop} );
    }

    note( "Employee $uid is a passerby" );
    is( $emp->nick, $uid );
    is( $emp->priv( $dbix_conn ), 'passerby' );
    my $eid = $emp->eid;
    ok( $eid > 0 );

    note( "Make $uid an active employee" );
    $status = req( $test, 201, 'root', 'POST', "priv/history/eid/$eid", 
        "{ \"effective\":\"1892-01-01\", \"priv\":\"active\" }" );
    ok( $status->ok, "New privhistory record created for $uid" );
    is( $status->code, 'DOCHAZKA_CUD_OK', "Status code is as expected" );

    note( "Employee $uid is an active" );
    is( $emp->priv( $dbix_conn ), 'active' );

    note( "Depopulate fullname field" );
    my $saved_fullname = $emp->fullname;
    $emp->fullname( undef );
    is( $emp->fullname, undef );
    $status = $emp->update( $faux_context );
    ok( $status->ok );

    note( "GET employee/nick/:nick 2" );
    $status = req( $test, 200, 'root', 'GET', "employee/nick/$uid" );
    is( $status->level, 'OK' );
    is( $status->payload->{fullname}, undef );

    note( "Set password of employee $uid to $uid" );
    $status = req( $test, 200, 'root', 'PUT', "employee/nick/$uid", 
        "{\"password\":\"$uid\"}" );
    is( $status->level, 'OK' );

    note( "PUT employee/nick/:nick/ldap 1" );
    $uid = $site->DOCHAZKA_LDAP_TEST_UID_EXISTENT;
    $status = req( $test, 200, $uid, 'PUT', "employee/nick/$uid/ldap" );
    is( $status->level, 'OK' );

    note( "GET employee/nick/:nick 2" );
    $status = req( $test, 200, 'root', 'GET', "employee/nick/$uid" );
    is( $status->level, 'OK' );
    is( $status->payload->{fullname}, $saved_fullname );

    note( "Cleanup" );
    $status = delete_all_attendance_data();
    BAIL_OUT(0) unless $status->ok;
}

done_testing;
