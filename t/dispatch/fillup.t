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
# test 'interval/fillup/...' resources
#

#!perl
use 5.012;
use strict;
use warnings;

#use App::CELL::Test::LogToFile;
use App::CELL qw( $log $meta $site );
use App::Dochazka::REST::Test;
use Data::Dumper;
use JSON;
use Plack::Test;
use Test::JSON;
use Test::More;

note( 'initialize, connect to database, and set up a testing plan' );
my $app = initialize_regression_test();

note( 'instantiate Plack::Test object' );
my $test = Plack::Test->create( $app );

my $note;

note( $note = 'create a testing schedule' );
$log->info( "=== $note" );
my $sid = create_testing_schedule( $test );

note( $note = 'create testing employee \'active\' with \'active\' privlevel' );
$log->info( "=== $note" );
my $eid_active = create_active_employee( $test );

note( $note = 'give \'active\' a schedule as of 1957-01-01 00:00 so it can enter attendance intervals' );
$log->info( "=== $note" );
my @shid_for_deletion;
my $status = req( $test, 201, 'root', 'POST', "schedule/history/nick/active", <<"EOH" );
{ "sid" : $sid, "effective" : "1957-01-01 00:00" }
EOH
is( $status->level, "OK" );
is( $status->code, "DOCHAZKA_CUD_OK" );
ok( $status->{'payload'} );
ok( $status->{'payload'}->{'shid'} );
push @shid_for_deletion, $status->{'payload'}->{'shid'};
#ok( $status->{'payload'}->{'schedule'} );

note( $note = 'create testing employee \'inactive\' with \'inactive\' privlevel' );
$log->info( "=== $note" );
my $eid_inactive = create_inactive_employee( $test );

note( $note = 'create testing employee \'bubba\' with \'active\' privlevel' );
$log->info( "=== $note" );
my $eid_bubba = create_testing_employee( { nick => 'bubba', password => 'bubba' } )->eid;
$status = req( $test, 201, 'root', 'POST', 'priv/history/nick/bubba', <<"EOH" );
{ "eid" : $eid_bubba, "priv" : "active", "effective" : "1967-06-17 00:00" }
EOH
is( $status->level, "OK" );
is( $status->code, "DOCHAZKA_CUD_OK" );
$status = req( $test, 200, 'root', 'GET', 'priv/nick/bubba' );
is( $status->level, "OK" );
is( $status->code, "DISPATCH_EMPLOYEE_PRIV" );
ok( $status->{'payload'} );
is( $status->{'payload'}->{'priv'}, 'active' );

sub create_testing_interval {
    my ( $test ) = @_;
    # get AID of WORK
    my $aid_of_work = get_aid_by_code( $test, 'WORK' );
    
    note( 'in create_testing_interval() function' );
    $status = req( $test, 201, 'root', 'POST', 'interval/new', <<"EOH" );
{ "eid" : $eid_active, "aid" : $aid_of_work, "intvl" : "[2014-10-01 08:00, 2014-10-01 12:00)" }
EOH
    if( $status->level ne 'OK' ) {
        diag( Dumper $status );
        BAIL_OUT(0);
    }
    is( $status->level, 'OK' );
    is( $status->code, 'DOCHAZKA_CUD_OK' );
    ok( $status->{'payload'} );
    is( $status->{'payload'}->{'aid'}, $aid_of_work );
    ok( $status->{'payload'}->{'iid'} );
    return $status->{'payload'}->{'iid'};
}

my $test_iid = create_testing_interval( $test );

my @failing_tsranges = (
    '[]',
    '{asf}',
    '[2014-01-01: 2015-01-01)',
    'wamble wumble womble',
);

note( '=============================' );
note( '"interval/fillup/eid/:eid/:tsrange" resource' );
note( '=============================' );
my $base = "interval/fillup/eid";
docu_check( $test, "$base/:eid/:tsrange" );
    
note( "GET $base/:eid/:tsrange" );

note( $note = 'root has no intervals but these users can\'t find that out' );
$log->info( "=== $note" );
foreach my $user ( qw( demo inactive active ) ) {
    req( $test, 403, $user, 'GET', "$base/1/[,)" );
}

note( $note = 'active has one interval in 2014 - from create_testing_interval()' );
$log->info( "=== $note" );
$status = req( $test, 200, 'root', 'GET',
    "interval/eid/$eid_active/[2014-01-01 00:00, 2014-12-31 24:00)" );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_RECORDS_FOUND' );
is( $status->{'count'}, 1 );
foreach my $tsr ( @failing_tsranges ) {
    note( 'tsranges that fail validations clause' );
    foreach my $user ( qw( demo inactive active root ) ) {
        req( $test, 400, $user, 'GET', "$base/1/$tsr" );
    }
}

note( 'use DELETE interval/eid/:eid/:tsrange on it' );

note( $note = '- bubba cannot do this' );
$log->info( "=== $note" );
$status = req( $test, 403, 'bubba', 'DELETE',
    "interval/eid/$eid_active/[2014-01-01 00:00, 2014-12-31 24:00)" );
is( $status->code, 'DISPATCH_KEEP_TO_YOURSELF' );

note( $note = '- but active can' );
$log->info( "=== $note" );
$status = req( $test, 200, 'active', 'DELETE',
    "interval/eid/$eid_active/[2014-01-01 00:00, 2014-12-31 24:00)" );
is( $status->code, 'DOCHAZKA_CUD_OK' );
is( $status->payload, 1 );

note( $note = "PUT, DELETE $base/:eid/:tsrange" );
$log->info( "=== $note" );
foreach my $method ( qw( PUT DELETE  ) ) {
    note( "Testing method: $method" );
    foreach my $user ( 'demo', 'root', 'WAMBLE owdkmdf 5**' ) {
        req( $test, 405, $user, $method, "$base/2/[,)" );
    }
}

note( 'list fillup intervals as active employee' );
my $aid_of_work = get_aid_by_code( $test, 'WORK' );
$status = req( $test, 200, 'active', 'GET', 'interval/fillup/self/[1958-01-03 23:59, 1958-02-03 08:00)' );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_RECORDS_FOUND' );
my $count = scalar( @{ $status->payload } );
is( $status->{'count'}, $count );
is( $count, 28 );

note( 'fillup dry run over tsrange with no scheduled intervals' );
$status = req( $test, 200, 'active', 'GET', 'interval/fillup/self/[1958-01-01 00:00, 1958-01-02 24:00)' );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_RECORDS_FOUND' );
ok( exists( $status->{'count'} ) );
is( $status->{'count'}, 0 );
ok( ! defined( $status->payload ) );

note( 'fillup dry run over an even shorter tsrange with no scheduled intervals' );
$status = req( $test, 200, 'active', 'GET', 'interval/fillup/self/[1958-01-01 14:00, 1958-01-01 16:00)' );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_RECORDS_FOUND' );
ok( exists( $status->{'count'} ) );
is( $status->{'count'}, 0 );
ok( ! defined( $status->payload ) );

#note( 'fillup dry run over a short tsrange with a scheduled interval' );
#note( 'reproduces bug https://github.com/smithfarm/dochazka-rest/issues/21' );
#$status = req( $test, 200, 'active', 'GET', 'interval/fillup/self/[1958-01-03 14:00, 1958-01-03 16:00)' );
#is( $status->level, 'OK' );
#is( $status->code, 'DISPATCH_RECORDS_FOUND' );
#ok( exists( $status->{'count'} ) );
#is( $status->{'count'}, 0 );
#ok( ! defined( $status->payload ) );

note( 'POST fillup intervals as active employee' );
$status = req( $test, 200, 'active', 'POST', 'interval/fillup/self/[1958-01-03 23:59, 1958-02-03 08:00)' );
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_TEMPINTVLS_COMMITTED' );

note( "let 'active' use GET interval/eid/:eid/:tsrange to list fillup intervals" );
$status = req( $test, 200, 'active', 'GET', "interval/eid/$eid_active/[ 1958-01-01, 1958-12-31 )" );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_RECORDS_FOUND' );
ok( defined( $status->payload ) );
is( ref( $status->payload ), 'ARRAY' );
is( scalar( @{ $status->payload } ), $count, "interval count is $count" );

#note( "let 'active' use GET interval/eid/:eid/:ts/:psqlint to list it" );
#$status = req( $test, 200, 'active', 'GET', "interval/eid/$eid_active/1958-01-01/1 year" );
#is( $status->level, 'OK' );
#is( $status->code, 'DISPATCH_RECORDS_FOUND' );
#ok( defined( $status->payload ) );
#is( ref( $status->payload ), 'ARRAY' );
#is( scalar( @{ $status->payload } ), 1, "interval count is 1" );
#is( ref( $status->payload->[0] ), 'HASH' );
#is( $status->payload->[0]->{'long_desc'}, $iae_interval_long_desc );
#
#note( "let active try to GET interval/eid/:eid/:tsrange on another user\'s intervals" );
#$status = req( $test, 403, 'active', 'GET', "interval/eid/$eid_inactive/[ 1958-01-01, 1958-12-31 )" );
#is( $status->level, 'ERR' );
#is( $status->code, 'DISPATCH_KEEP_TO_YOURSELF' );
#
#foreach my $user ( qw( inactive demo ) ) {
#    note( "let $user try GET interval/eid/:eid/:tsrange and get 403" );
#    req( $test, 403, $user, 'GET', "interval/eid/$eid_active/[ 1958-01-01, 1958-12-31 )" );
#}

note( 'delete the testing intervals' );
$status = req( $test, 200, 'active', 'DELETE', "interval/eid/$eid_active/[ 1958-01-01, 1958-12-31 )" );
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_CUD_OK' );

note( 'delete the testing employees' );
delete_employee_by_nick( $test, 'active' );
delete_employee_by_nick( $test, 'inactive' );
delete_employee_by_nick( $test, 'bubba' );

note( 'delete the testing schedule' );
delete_testing_schedule( $sid );
    
done_testing;
