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

    note( 'create LDAP user in database' );
    my $uid = $site->DOCHAZKA_LDAP_TEST_UID_EXISTENT;
    my $emp = App::Dochazka::REST::Model::Employee->spawn(
        'nick' => $uid
    );

    note( "Populate $uid employee object from LDAP" );
    my $throwaway_emp = $emp->clone();
    my $status = $throwaway_emp->sync();
    is( $status->level, 'OK' );

    note( "GET employee/nick/:nick/ldap 1" );
    $uid = $site->DOCHAZKA_LDAP_TEST_UID_NON_EXISTENT;
    req( $test, 404, 'root', 'GET', "employee/nick/$uid/ldap" );

    note( "GET employee/nick/:nick/ldap 2" );
    $uid = $site->DOCHAZKA_LDAP_TEST_UID_EXISTENT;
    $status = req( $test, 200, 'root', 'GET', "employee/nick/$uid/ldap" );
    is( $status->level, 'OK' );

    note( "Make a pristine employee object" );
    my $pristine = App::Dochazka::REST::Model::Employee->spawn(
        'nick' => $uid,
    );
    ok( $uid, "Existing LDAP user $uid is not undef or empty string" );
    is( $pristine->nick, $uid, "Employee we just created has nick $uid" );

    note( "Pristine employee object has non-nick properties unpopulated" );
    my @props = grep( !/^nick/, keys( %{ $site->DOCHAZKA_LDAP_MAPPING } ) );
    foreach my $prop ( @props ) {
        is( $pristine->{$prop}, undef, "$prop property is undef" );
    }

    note( "Populate pristine employee object from LDAP" );
    $status = $pristine->sync();
    ok( $status->ok, "Employee sync operation succeeded" );

    note( "Mapped properties now have values" );
    foreach my $prop ( @props ) {
        ok( $pristine->{$prop}, "$prop property has value " . $pristine->{$prop} );
    }
}

done_testing;
