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

note( "spawn a tempintvls object" );
my $tio = App::Dochazka::REST::Model::Tempintvls->spawn;
isa_ok( $tio, 'App::Dochazka::REST::Model::Tempintvls' );

note( 'test that populate() was called and that it did its job' );
ok( $tio->tiid > 0 );

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
        $status = $tio->_vet_tsrange( dbix_conn => $dbix_conn, tsrange => $_ );
        #diag( $status->level . ' ' . $status->text );
        is( $status->level, 'ERR' ); 
    } @$bogus;

note( 'vet a too-long tsrange' );
$status = $tio->_vet_tsrange( dbix_conn => $dbix_conn, tsrange => '[ 2015-1-1, 2016-1-2 )' );
is( $status->level, 'ERR' );
is( $status->code, 'DOCHAZKA_TSRANGE_TOO_BIG' );

note( 'vet a non-bogus tsrange' );
$status = $tio->_vet_tsrange( dbix_conn => $dbix_conn, tsrange => '[ "Jan 1, 2015", 2015-12-31 )' );
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
$status = $tio->_vet_employee( dbix_conn => $dbix_conn, eid => 1 );
is( $status->level, 'ERR' );
is( $status->code, 'DISPATCH_EMPLOYEE_NO_SCHEDULE' );

note( 'vet a non-existent employee' );
$status = $tio->_vet_employee( dbix_conn => $dbix_conn, eid => 0 );
is( $status->level, 'ERR' );
is( $status->code, 'DOCHAZKA_EMPLOYEE_EID_NOT_EXIST' );

note( 'create a testing employee with nick "active"' );
my $active = create_testing_employee( { nick => 'active', password => 'active' } );
push my @eids_to_delete, $active->eid;

note( 'vet active - no privhistory' );
$status = $tio->_vet_employee( dbix_conn => $dbix_conn, eid => $active->eid );
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
$status = $tio->_vet_employee( dbix_conn => $dbix_conn, eid => $active->eid );
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
$status = $tio->_vet_employee( dbix_conn => $dbix_conn, eid => $active->eid );
is( $status->level, "OK" );
is( $status->code, "SUCCESS" );
isa_ok( $tio->{'emp_obj'}, 'App::Dochazka::REST::Model::Employee' );
is( $tio->{'emp_obj'}->eid, $active->eid );
is( $tio->{'emp_obj'}->nick, 'active' );
my $active_obj = $tio->{'emp_obj'};

note( 'vet active using employee object' );
$status = $tio->_vet_employee( dbix_conn => $dbix_conn, emp_obj => $active_obj );
is( $status->level, "OK" );
is( $status->code, "SUCCESS" );

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
$status = $tio->_vet_activity( dbix_conn => $dbix_conn, );
is( $status->level, 'OK' );
is( $status->code, 'SUCCESS' );
isa_ok( $tio->{'act_obj'}, 'App::Dochazka::REST::Model::Activity' ); 
is( $tio->{'act_obj'}->code, 'WORK' );
is( $tio->{'act_obj'}->aid, $activity->aid );
is( $tio->{'aid'}, $activity->aid );

note( 'vet non-existent activity 1' );
$status = $tio->_vet_activity( dbix_conn => $dbix_conn, aid => 'WORBLE' );
is( $status->level, 'ERR' );
is( $status->code, 'DOCHAZKA_DBI_ERR' );

note( 'vet non-existent activity 2' );
$status = $tio->_vet_activity( dbix_conn => $dbix_conn, aid => '-1' );
is( $status->level, 'ERR' );
is( $status->code, 'DOCHAZKA_GENERIC_NOT_EXIST' );
is( $status->text, 'There is no activity with AID ->-1<-' );

my $note = 'vet non-existent activity 3';
note( $note );
$log->info( "*** $note" );
$status = $tio->_vet_activity( dbix_conn => $dbix_conn, aid => '0' );
is( $status->level, 'ERR' );
is( $status->code, 'DOCHAZKA_GENERIC_NOT_EXIST' );
is( $status->text, 'There is no activity with AID ->0<-' );

note( 'vet activity WORK by explicit AID' );
$status = $tio->_vet_activity( dbix_conn => $dbix_conn, aid => $activity->aid );
is( $status->level, 'OK' );
is( $status->code, 'SUCCESS' );
isa_ok( $tio->{'act_obj'}, 'App::Dochazka::REST::Model::Activity' ); 
is( $tio->{'act_obj'}->code, 'WORK' );
is( $tio->{'act_obj'}->aid, $activity->aid );
is( $tio->{'aid'}, $activity->aid );

note( 'vetted now true' );
ok( $tio->vetted );

note( 'change the tsrange' );
$status = $tio->_vet_tsrange( dbix_conn => $dbix_conn, tsrange => '( "May 5, 1998" 10:00, 1998-05-13 10:00 )' );
is( $status->level, 'OK' );
is( $status->code, 'SUCCESS' );

note( 'proceed with fillup' );
$status = $tio->fillup( dbix_conn => $dbix_conn );
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_TEMPINTVLS_INSERT_OK' );
is( scalar( @{ $status->payload->{'intervals'} } ), 24 );

note( 'commit (dry run)' );
$status = $tio->commit( dbix_conn => $dbix_conn, dry_run => 1 );
diag( Dumper $status );
BAIL_OUT(0);
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_RECORDS_FOUND' );
is( $status->{count}, 18 );

#note( 'delete the tempintvls' ); # not necessary; DESTROY() is called automatically
#$status = $tio->DESTROY;
#is( $status->level, 'OK' );
#is( $status->code, 'DOCHAZKA_RECORDS_DELETED' );
#is( $status->{count}, 24 );

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
