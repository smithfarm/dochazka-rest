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
# unit tests for scratch fillup intervals
#

#!perl
use 5.012;
use strict;
use warnings;

#use App::CELL::Test::LogToFile;
use App::CELL qw( $log $meta $site );
use Data::Dumper;
#use App::Dochazka::Common qw( $today $yesterday $tomorrow );
use App::Dochazka::REST::ConnBank qw( $dbix_conn );
use App::Dochazka::REST::Model::Activity;
use App::Dochazka::REST::Model::Interval qw( delete_intervals_by_eid_and_tsrange );
use App::Dochazka::REST::Model::Tempintvls;
use App::Dochazka::REST::Model::Shared qw( noof );
use App::Dochazka::REST::Model::Schedhistory;
use App::Dochazka::REST::Test;
use App::Dochazka::REST::Util::Date qw( canon_to_ymd );
use Test::More;


note( 'initialize, connect to database, and set up a testing plan' );
my $status = initialize_unit();
if ( $status->not_ok ) {
    plan skip_all => "not configured or server not running";
}

note( 'tempintvls table should be empty' );
if ( 0 != noof( $dbix_conn, 'tempintvls') ) {
    diag( "tempintvls table is not empty; bailing out!" );
    BAIL_OUT(0);
}

note( "spawn a tempintvls object" );
my $tio = App::Dochazka::REST::Model::Tempintvls->spawn;
isa_ok( $tio, 'App::Dochazka::REST::Model::Tempintvls' );

note( 'test that populate() was called and that it did its job' );
ok( $tio->tiid > 0 );

note( "populate context" );
is( ref( $faux_context ), 'HASH', "\$faux_context is a HASHREF" );
isa_ok( $faux_context->{dbix_conn}, 'DBIx::Connector' );
$tio->context( $faux_context );
isa_ok( $tio->context->{dbix_conn}, 'DBIx::Connector' );
isa_ok( $tio->dbix_conn, 'DBIx::Connector' );

note( 'quickly test canon_to_ymd' );
my @ymd = canon_to_ymd( '2015-01-01' );
is( ref( \@ymd ), 'ARRAY' );
is( $ymd[0], '2015' );
is( $ymd[1], '01' );
is( $ymd[2], '01' );

note( 'attempt to _vet_tsrange bogus tsranges individually' );
my $bogus = [
        "[)",
        "[,)",
        "[ ,)",
        "(2014-07-34 09:00, 2014-07-14 17:05)",
        "[2014-07-14 09:00, 2014-07-14 25:05]",
        "( 2014-07-34 09:00, 2014-07-14 17:05)",
        "[2014-07-14 09:00, 2014-07-14 25:05 ]",
	"[,2014-07-14 17:00)",
	"[ ,2014-07-14 17:00)",
        "[2014-07-14 17:15,)",
        "[2014-07-14 17:15, )",
        "[ infinity, infinity)",
	"[ infinity,2014-07-14 17:00)",
        "[2014-07-14 17:15,infinity)",
    ];
map {
        $status = $tio->_vet_tsrange( tsrange => $_ );
        #diag( $status->level . ' ' . $status->text );
        is( $status->level, 'ERR', "$_ is a bogus tsrange" ); 
    } @$bogus;

note( 'vet a too-long tsrange' );
$status = $tio->_vet_tsrange( tsrange => '[ 2015-1-1, 2016-1-2 )' );
is( $status->level, 'ERR' );
is( $status->code, 'DOCHAZKA_TSRANGE_TOO_BIG' );

note( 'vet a non-bogus tsrange' );
$status = $tio->_vet_tsrange( tsrange => '[ "Jan 1, 2015", 2015-12-31 )' );
is( $status->level, 'OK' );
is( $status->code, 'SUCCESS' );
is( $tio->{'tsrange'}, '[ 2015-01-01 00:00:00+01, 2015-12-31 00:00:00+01 )' );
is( $tio->{'lower_canon'}, '2014-12-31' );
is( $tio->{'upper_canon'}, '2016-01-01' );
is_deeply( $tio->{'lower_ymd'}, [ 2014, 12, 31 ] );
is_deeply( $tio->{'upper_ymd'}, [ 2016, 1, 1 ] );

note( 'but not fully vetted yet' );
ok( ! $tio->vetted );

note( 'vet a non-bogus employee (no schedule)' );
$status = App::Dochazka::REST::Model::Employee->load_by_eid( $dbix_conn, 1 );
$status = $tio->_vet_employee( emp_obj => $status->payload );
is( $status->level, 'ERR' );
is( $status->code, 'DISPATCH_EMPLOYEE_NO_SCHEDULE' );

note( 'we do not try to vet non-existent employee objects here, because the Tempintvls' );
note( 'class is designed to be called from Dispatch.pm *after* the employee has been' );
note( 'determined to exist' );
##my $throwaway_obj = App::Dochazka::REST::Model::Employee->spawn( eid => 0);
##$status = $tio->_vet_employee( dbix_conn => $dbix_conn, emp_obj => $throwaway_obj );
##is( $status->level, 'ERR' );
##is( $status->code, 'DOCHAZKA_EMPLOYEE_EID_NOT_EXIST' );

note( 'create a testing employee with nick "active"' );
my $active = create_testing_employee( { nick => 'active', password => 'active' } );
push my @eids_to_delete, $active->eid;

note( 'vet active - no privhistory' );
$status = $tio->_vet_employee( emp_obj => $active );
is( $status->level, 'ERR' );
is( $status->code, 'DISPATCH_EMPLOYEE_NO_PRIVHISTORY' );

note( 'give active a privhistory' );
my $ins_eid = $active->eid;
my $ins_priv = 'active';
my $ins_effective = "1892-01-01";
my $ins_remark = 'TESTING';
my $priv = App::Dochazka::REST::Model::Privhistory->spawn(
              eid => $ins_eid,
              priv => $ins_priv,
              effective => $ins_effective,
              remark => $ins_remark,
          );
is( $priv->phid, undef, "phid undefined before INSERT" );
$status = $priv->insert( $faux_context );
diag( Dumper $status->text ) if $status->not_ok;
ok( $status->ok, "Post-insert status ok" );
ok( $priv->phid > 0, "INSERT assigned an phid" );
is( $priv->remark, $ins_remark, "remark survived INSERT" );
push my @phids_to_delete, $priv->phid;

note( 'vet active - no schedule' );
$status = $tio->_vet_employee( emp_obj => $active );
is( $status->level, 'ERR' );
is( $status->code, 'DISPATCH_EMPLOYEE_NO_SCHEDULE' );

note( 'create a testing schedule' );
my $schedule = test_schedule_model( [ 
    '[ 1998-05-04 08:00, 1998-05-04 12:00 )',
    '[ 1998-05-04 12:30, 1998-05-04 16:30 )',
    '[ 1998-05-05 08:00, 1998-05-05 12:00 )',
    '[ 1998-05-05 12:30, 1998-05-05 16:30 )',
    '[ 1998-05-06 08:00, 1998-05-06 12:00 )',
    '[ 1998-05-06 12:30, 1998-05-06 16:30 )',
    '[ 1998-05-07 08:00, 1998-05-07 12:00 )',
    '[ 1998-05-07 12:30, 1998-05-07 16:30 )',
    '[ 1998-05-08 08:00, 1998-05-08 12:00 )',
    '[ 1998-05-08 12:30, 1998-05-08 16:30 )',
] );
push my @sids_to_delete, $schedule->sid;

note( 'give active a schedhistory' );
my $schedhistory = App::Dochazka::REST::Model::Schedhistory->spawn(
    eid => $active->eid,
    sid => $schedule->sid,
    effective => "1892-01-01",
    remark => 'TESTING',
);
isa_ok( $schedhistory, 'App::Dochazka::REST::Model::Schedhistory', "schedhistory object is an object" );
$status = $schedhistory->insert( $faux_context );
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_CUD_OK' );
push my @shids_to_delete, $schedhistory->shid;

note( 'vet active - all green' );
$status = $tio->_vet_employee( emp_obj => $active );
is( $status->level, "OK" );
is( $status->code, "SUCCESS" );
isa_ok( $tio->{'emp_obj'}, 'App::Dochazka::REST::Model::Employee' );
is( $tio->{'emp_obj'}->eid, $active->eid );
is( $tio->{'emp_obj'}->nick, 'active' );
my $active_obj = $tio->{'emp_obj'};

note( 'but not fully vetted yet' );
ok( ! $tio->vetted );

note( 'get AID of WORK' );
$status = App::Dochazka::REST::Model::Activity->load_by_code( $dbix_conn, 'WORK' );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_RECORDS_FOUND' );
isa_ok( $status->payload, 'App::Dochazka::REST::Model::Activity' );
my $activity = $status->payload;
#diag( "AID of WORK: " . $activity->aid );

note( 'vet activity (default)' );
$status = $tio->_vet_activity;
is( $status->level, 'OK' );
is( $status->code, 'SUCCESS' );
isa_ok( $tio->{'act_obj'}, 'App::Dochazka::REST::Model::Activity' ); 
is( $tio->{'act_obj'}->code, 'WORK' );
is( $tio->{'act_obj'}->aid, $activity->aid );
is( $tio->{'aid'}, $activity->aid );

note( 'vet non-existent activity 1' );
$status = $tio->_vet_activity( aid => 'WORBLE' );
is( $status->level, 'ERR' );
is( $status->code, 'DOCHAZKA_DBI_ERR' );

note( 'vet non-existent activity 2' );
$status = $tio->_vet_activity( aid => '-1' );
is( $status->level, 'ERR' );
is( $status->code, 'DOCHAZKA_GENERIC_NOT_EXIST' );
is( $status->text, 'There is no activity with AID ->-1<-' );

my $note = 'vet non-existent activity 3';
note( $note );
$log->info( "*** $note" );
$status = $tio->_vet_activity( aid => '0' );
is( $status->level, 'ERR' );
is( $status->code, 'DOCHAZKA_GENERIC_NOT_EXIST' );
is( $status->text, 'There is no activity with AID ->0<-' );

note( 'vet activity WORK by explicit AID' );
$status = $tio->_vet_activity( aid => $activity->aid );
is( $status->level, 'OK' );
is( $status->code, 'SUCCESS' );
isa_ok( $tio->{'act_obj'}, 'App::Dochazka::REST::Model::Activity' ); 
is( $tio->{'act_obj'}->code, 'WORK' );
is( $tio->{'act_obj'}->aid, $activity->aid );
is( $tio->{'aid'}, $activity->aid );

note( 'vetted now true' );
ok( $tio->vetted );

note( 'change the tsrange' );
$status = $tio->_vet_tsrange( tsrange => '[ "April 28, 1998" 10:00, 1998-05-6 10:00 )' );
is( $status->level, 'OK' );
is( $status->code, 'SUCCESS' );
is( $tio->tsrange, '[ 1998-04-28 10:00:00+02, 1998-05-06 10:00:00+02 )' );

note( 'proceed with fillup' );
$status = $tio->fillup;
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_TEMPINTVLS_INSERT_OK' );

note( 'commit (dry run)' );
$status = $tio->commit( dry_run => 1 );
is( $status->level, 'OK' );
is( $status->code, 'RESULT_SET' );

note( '1998-05-01 should not appear anywhere, as it is a holiday' );
my $jumbled_together = join( '', @{ $status->payload} );
ok( ! ( $jumbled_together =~ m/1998-05-01/ ) );

note( 'Check for exact deep match' );
is_deeply( $status->payload, [
    '["1998-04-28 10:00:00+02","1998-04-28 12:00:00+02")',
    '["1998-04-28 12:30:00+02","1998-04-28 16:30:00+02")',
    '["1998-04-29 08:00:00+02","1998-04-29 12:00:00+02")',
    '["1998-04-29 12:30:00+02","1998-04-29 16:30:00+02")',
    '["1998-04-30 08:00:00+02","1998-04-30 12:00:00+02")',
    '["1998-04-30 12:30:00+02","1998-04-30 16:30:00+02")',
    '["1998-05-04 08:00:00+02","1998-05-04 12:00:00+02")',
    '["1998-05-04 12:30:00+02","1998-05-04 16:30:00+02")',
    '["1998-05-05 08:00:00+02","1998-05-05 12:00:00+02")',
    '["1998-05-05 12:30:00+02","1998-05-05 16:30:00+02")',
    '["1998-05-06 08:00:00+02","1998-05-06 10:00:00+02")'
] );

note( 'test the new() method' );
my $tio2 = App::Dochazka::REST::Model::Tempintvls->new(
    context => $faux_context,
    tsrange => '[ 1998-04-28 10:00:00+02, 1998-05-06 10:00:00+02 )',
    emp_obj => $active,
);
isa_ok( $tio2, 'App::Dochazka::REST::Model::Tempintvls' );
ok( $tio2->constructor_status );
isa_ok( $tio2->constructor_status, 'App::CELL::Status' );
is( $tio2->tsrange, '[ 1998-04-28 10:00:00+02, 1998-05-06 10:00:00+02 )' );

note( 'commit (dry run) on object created without using new()' );
my $count = 11;
foreach my $obj ( $tio, $tio2 ) {
    $status = $obj->commit( dry_run => 1 );
    is( $status->level, 'OK' );
    is( $status->code, 'RESULT_SET' );
    is_deeply( $status->payload, [
        '["1998-04-28 10:00:00+02","1998-04-28 12:00:00+02")',
        '["1998-04-28 12:30:00+02","1998-04-28 16:30:00+02")',
        '["1998-04-29 08:00:00+02","1998-04-29 12:00:00+02")',
        '["1998-04-29 12:30:00+02","1998-04-29 16:30:00+02")',
        '["1998-04-30 08:00:00+02","1998-04-30 12:00:00+02")',
        '["1998-04-30 12:30:00+02","1998-04-30 16:30:00+02")',
        '["1998-05-04 08:00:00+02","1998-05-04 12:00:00+02")',
        '["1998-05-04 12:30:00+02","1998-05-04 16:30:00+02")',
        '["1998-05-05 08:00:00+02","1998-05-05 12:00:00+02")',
        '["1998-05-05 12:30:00+02","1998-05-05 16:30:00+02")',
        '["1998-05-06 08:00:00+02","1998-05-06 10:00:00+02")'
    ] );
    is( scalar( @{ $status->payload } ), $count );
    is( $status->{'count'}, $count );
}

note( 'really commit the attendance intervals' );
is( noof( $dbix_conn, 'intervals' ), 0 );
$status = $tio2->commit;
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_TEMPINTVLS_COMMITTED' );
is( $status->{count}, $count );
is( noof( $dbix_conn, 'intervals' ), $count );

note( 'delete the tempintvls not necessary; DESTROY() is called automatically' );

sub _vet_cleanup {
    my $status = shift;
    is( $status->level, 'OK' );
    is( $status->code, 'DISPATCH_RECORDS_FOUND' ); 
    my $obj = $status->payload;
    $status = $obj->delete( $faux_context );
    is( $status->level, 'OK' );
    is( $status->code, 'DOCHAZKA_CUD_OK' ); 
}

# CLEANUP
isa_ok( $dbix_conn, 'DBIx::Connector' );
$status = delete_intervals_by_eid_and_tsrange( $tio2->dbix_conn, $tio2->eid, $tio2->tsrange );
is( $status->level, 'OK' );
map {
    _vet_cleanup( App::Dochazka::REST::Model::Schedhistory->load_by_shid( $dbix_conn, $_ ) );
} @shids_to_delete;
map {
    _vet_cleanup( App::Dochazka::REST::Model::Schedule->load_by_sid( $dbix_conn, $_ ) );
} @sids_to_delete;
map {
    _vet_cleanup( App::Dochazka::REST::Model::Privhistory->load_by_phid( $dbix_conn, $_ ) );
} @phids_to_delete;
map {
    _vet_cleanup( App::Dochazka::REST::Model::Employee->load_by_eid( $dbix_conn, $_ ) );
} @eids_to_delete;

done_testing;
