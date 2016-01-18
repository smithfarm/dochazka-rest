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
# unit tests for fillup
#

#!perl
use 5.012;
use strict;
use warnings;

#use App::CELL::Test::LogToFile;
use App::CELL qw( $CELL $log $meta $site );
use Data::Dumper;
use App::Dochazka::REST::ConnBank qw( $dbix_conn );
use App::Dochazka::REST::Holiday qw( canon_to_ymd );
use App::Dochazka::REST::Model::Interval qw( delete_intervals_by_eid_and_tsrange );
use App::Dochazka::REST::Fillup;
use App::Dochazka::REST::Model::Tempintvl;
use App::Dochazka::REST::Model::Shared qw( noof );
use App::Dochazka::REST::Model::Schedhistory;
use App::Dochazka::REST::Test;
use Test::More;
use Test::Fatal;

my ( $note, $status );

# given a Fillup object with populated context, reset it
# without clobbering the context
sub reset_obj {
    my $obj = shift;
    my $saved_context = $obj->context;
    $obj->reset;
    $obj->context( $saved_context );
    return;
}

note( $note = 'initialize, connect to database, and set up a testing plan' );
$log->info( "=== $note" );
initialize_regression_test();

note( $note = 'start with a clean slate' );
$log->info( "=== $note" );
$status = delete_all_attendance_data();
BAIL_OUT(0) unless $status->ok;

note( $note = 'tempintvls table should be empty' );
$log->info( "=== $note" );
if ( 0 != noof( $dbix_conn, 'tempintvls') ) {
    diag( "tempintvls table is not empty; bailing out!" );
    BAIL_OUT(0);
}

note( $note = 'make a testing fillup object' );
$log->info( "=== $note" );
my $fo = bless {}, 'App::Dochazka::REST::Fillup';

note( $note = 'test accessors on empty object' );
$log->info( "=== $note" );
{
    no strict 'refs';
    map {
        is( $fo->$_, undef, "$_ property is undef" );
    } keys %App::Dochazka::REST::Fillup::attr;
}

note( $note = 'populate() sets tiid property' );
$log->info( "=== $note" );
$fo->populate();
ok( $fo->tiid > 0 );

note( $note = 'accessors can be used to set values - non-pathological' );
$log->info( "=== $note" );
{
    my %attr_test = (
        act_obj => App::Dochazka::REST::Model::Activity->spawn,
        constructor_status => $CELL->status_ok,
        context => {},
        date_list => [],
        dry_run => 0,
        emp_obj => App::Dochazka::REST::Model::Employee->spawn,
        intervals => [],
        long_desc => '',
        remark => '',
        tiid => '',
        tsrange => '',
        tsranges => [],
    );
    map 
    {
        my $throwaway = $attr_test{ $_ };
        $fo->$_( $throwaway );
        is( $fo->$_, $throwaway );
    } keys %attr_test;
}

note( $note = 'further test inherited accessors pathological' );
$log->info( "=== $note" );
{
    my %attr_test = (
        act_obj => '',
        constructor_status => '',
        context => [],
        date_list => {},
        dry_run => [],
        emp_obj => '',
        intervals => {},
        long_desc => {},
        remark => {},
        tiid => {},
        tsrange => {},
        tsranges => {},
    );
    map 
    {
        my $throwaway = $attr_test{ $_ };
        like(
            exception { $fo->$_( $throwaway ) },
            qr/which is not one of the allowed types:/
        );
    } keys %attr_test;
}

note( $note = 'further test selected accessors non-pathological' );
$log->info( "=== $note" );

my $context = { 'heaven' => 'angel' };
$fo->context( $context  );
is( $fo->context, $context );

my $emp = App::Dochazka::REST::Model::Employee->spawn;
$fo->emp_obj( $emp );
is( $fo->emp_obj, $emp );

my $act = App::Dochazka::REST::Model::Activity->spawn;
$fo->act_obj( $act );
is( $fo->act_obj, $act );

my $dl = [ '2016-01-01', '2016-01-02', '2016-01-03' ];
$fo->date_list( $dl );
is( $fo->date_list, $dl );

$status = $CELL->status_ok( 'DOCHAZKA_ALL_GREEN' );
$fo->constructor_status( $status );
is( $fo->constructor_status, $status );

note( $note = 'further test selected accessors pathological' );
$log->info( "=== $note" );
like( 
    exception { $fo->constructor_status( App::Dochazka::REST::Model::Activity->spawn ) }, 
    qr/was not a.*it is a/
);
like( 
    exception { $fo->act_obj( $CELL->status_ok ) }, 
    qr/was not a.*it is a/
);
like( 
    exception { $fo->emp_obj( $CELL->status_ok ) }, 
    qr/was not a.*it is a/
);

note( $note = "vet empty context" );
$log->info( "=== $note" );
$status = $fo->_vet_context();
ok( $status->not_ok );

note( $note = "populate context attribute" );
$log->info( "=== $note" );
$status = $fo->_vet_context( context => $faux_context );
ok( $status->ok );

note( $note = "context should now be OK" );
$log->info( "=== $note" );
ok( $fo->context );
is( ref( $fo->context ), 'HASH' );
isa_ok( $fo->context->{dbix_conn}, 'DBIx::Connector' );

note( $note = 'quickly test canon_to_ymd' );
$log->info( "=== $note" );
my @ymd = canon_to_ymd( '2015-01-01' );
is( ref( \@ymd ), 'ARRAY' );
is( $ymd[0], '2015' );
is( $ymd[1], '01' );
is( $ymd[2], '01' );

note( $note = 'test the reset method' );
$log->info( "=== $note" );
my $saved_context = $fo->context;
$fo->reset;
my %test_attrs = %App::Dochazka::REST::Fillup::attr;
delete( $test_attrs{tiid} );
map { is( $fo->{ $_ }, undef ); } keys %test_attrs;
$fo->context( $saved_context );
is( $fo->context, $saved_context );

note( $note = 'test the _vet_date_spec method' );
$log->info( "=== $note" );
$status = $fo->_vet_date_spec(
    date_list => [ qw( 2016-01-01 2016-01-02 2016-01-03 ) ],
);
ok( $status->ok );
$status = $fo->_vet_date_spec(
    tsrange => 'bubba', # can be any scalar, not necessarily a valid tsrange
);
ok( $status->ok );
$status = $fo->_vet_date_spec(
    date_list => [ qw( 2016-01-01 2016-01-02 2016-01-03 ) ],
    tsrange => 'bubba', # can be any scalar, not necessarily a valid tsrange
);
ok( $status->not_ok );
$status = $fo->_vet_date_spec();
ok( $status->not_ok );
$status = $fo->_vet_date_spec(
    date_list => undef,
    tsrange => undef,
);
ok( $status->not_ok );
isnt( $fo->context, undef );

note( $note = 'vet some valid date lists' );
$log->info( "=== $note" );

note( $note = 'valid date list #1' );
$log->info( "=== $note" );
reset_obj( $fo );
is( $fo->date_list, undef );
is( $fo->tsrange, undef );
$dl = [ qw( 2016-01-01 2016-01-02 2016-01-03 ) ];
$status = $fo->_vet_date_list( date_list => $dl );
ok( $status->ok );
isnt( $fo->context, undef );
is_deeply( 
    $fo->date_list, 
    [ qw( 2016-01-01 2016-01-02 2016-01-03 ) ], 
    "date_list property initialized" 
);
is( $fo->tsrange, '["2016-01-01 00:00:00+01","2016-01-04 00:00:00+01")' );
is_deeply( 
    $fo->tsranges,
    [ 
        { tsrange => '["2016-01-01 00:00:00+01","2016-01-02 00:00:00+01")' }, 
        { tsrange => '["2016-01-02 00:00:00+01","2016-01-03 00:00:00+01")' }, 
        { tsrange => '["2016-01-03 00:00:00+01","2016-01-04 00:00:00+01")' }, 
    ], 
    "tsrange property initialized"
);

note( $note = 'valid date list #2' );
$log->info( "=== $note" );
reset_obj( $fo );
is( $fo->date_list, undef );
is( $fo->tsrange, undef );
$dl = [ qw( 1892-12-31 ) ];
$status = $fo->_vet_date_list( date_list => $dl );
ok( $status->ok );
is_deeply(
    $fo->date_list,
    [ qw( 1892-12-31 ) ],
    "date_list property initialized"
);
is( $fo->tsrange, '["1892-12-31 00:00:00+01","1893-01-01 00:00:00+01")' );
is_deeply(
    $fo->tsranges,
    [
        { tsrange => '["1892-12-31 00:00:00+01","1893-01-01 00:00:00+01")' },
    ],
    "tsrange property initialized"
);

note( $note = 'demonstrate how _vet_date_list does some limited canonicalizafon' );
$log->info( "=== $note" );
reset_obj( $fo );
is( $fo->date_list, undef );
is( $fo->tsrange, undef );
$dl = [ qw( 2016-1-1 ) ];
$status = $fo->_vet_date_list( date_list => $dl );
ok( $status->ok );
is_deeply( $fo->date_list, [ qw( 2016-01-01 ) ] );

note( $note = 'vet some invalid date lists' );
$log->info( "=== $note" );

note( $note = 'invalid date list #1 - empty list' );
$log->info( "=== $note" );
reset_obj( $fo );
is( $fo->date_list, undef );
is( $fo->tsrange, undef );
$dl = [];
$status = $fo->_vet_date_list( date_list => $dl );
is( $status->level, 'ERR' );
is( $status->code, 'DOCHAZKA_EMPTY_DATE_LIST' );

note( $note = 'invalid date list #2 - list consisting of one bogus value' );
$log->info( "=== $note" );
reset_obj( $fo );
$dl = [ 'bbub' ];
$status = $fo->_vet_date_list( date_list => $dl );
is( $status->level, 'ERR' );
is( $status->code, 'DOCHAZKA_INVALID_DATE_IN_DATE_LIST' );

note( $note = 'invalid date list #3 - list consisting of one bogus and one non-bogus value' );
$log->info( "=== $note" );
reset_obj( $fo );
$dl = [ '2016-01-01', 'bbub' ];
$status = $fo->_vet_date_list( date_list => $dl );
is( $status->level, 'ERR' );
is( $status->code, 'DOCHAZKA_INVALID_DATE_IN_DATE_LIST' );

note( $note = 'attempt to _vet_tsrange bogus tsranges individually' );
$log->info( "=== $note" );
reset_obj( $fo );
isnt( $fo->context, undef );
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
        my $status = $fo->_vet_tsrange( tsrange => $_ );
        #diag( $status->level . ' ' . $status->text );
        is( $status->level, 'ERR', "$_ is a bogus tsrange" ); 
    } @$bogus;

note( $note = 'vet a too-long tsrange' );
$log->info( "=== $note" );
$status = $fo->_vet_tsrange( tsrange => '[ 2015-1-1, 2016-1-2 )' );
is( $status->level, 'ERR' );
is( $status->code, 'DOCHAZKA_TSRANGE_TOO_BIG' );

note( $note = 'vet a non-bogus tsrange' );
$log->info( "=== $note" );
$status = $fo->_vet_tsrange( tsrange => '[ "Jan 1, 2015", 2015-12-31 )' );
is( $status->level, 'OK' );
is( $status->code, 'SUCCESS' );
like( $fo->tsranges->[0]->{'tsrange'}, qr/^\[ 2015-01-01 00:00:00..., 2015-12-31 00:00:00... \)$/ );
is( $fo->tsranges->[0]->{'lower_canon'}, '2014-12-31' );
is( $fo->tsranges->[0]->{'upper_canon'}, '2016-01-01' );
is_deeply( $fo->tsranges->[0]->{'lower_ymd'}, [ 2014, 12, 31 ] );
is_deeply( $fo->tsranges->[0]->{'upper_ymd'}, [ 2016, 1, 1 ] );

note( $note = 'but not fully vetted yet' );
$log->info( "=== $note" );
ok( ! $fo->vetted );

note( $note = 'vet a non-bogus employee (no schedule)' );
$log->info( "=== $note" );
reset_obj( $fo );
$fo->_vet_date_list( date_list => [ '2016-01-01' ] );
$status = App::Dochazka::REST::Model::Employee->load_by_eid( $dbix_conn, 1 );
$status = $fo->_vet_employee( emp_obj => $status->payload );
is( $status->level, 'ERR' );
is( $status->code, 'DISPATCH_EMPLOYEE_NO_SCHEDULE' );

note( $note = 'if employee object lacks an eid property, die' );
$log->info( "=== $note" );
my $bogus_emp = App::Dochazka::REST::Model::Employee->spawn( nick => 'bogus');
like( 
    exception { $fo->_vet_employee( emp_obj => $bogus_emp ); },
    qr/AKLDWW###%AAAAAH!/,
);

note( $note = 'we do not try to vet non-existent employee objects here, because the Tempintvls' );
$log->info( "=== $note" );
note( $note = 'class is designed to be called from Dispatch.pm *after* the employee has been' );
$log->info( "=== $note" );
note( $note = 'determined to exist' );
$log->info( "=== $note" );

note( $note = 'create a testing employee with nick "active"' );
$log->info( "=== $note" );
my $active = create_testing_employee( { nick => 'active', password => 'active' } );
push my @eids_to_delete, $active->eid;

note( $note = 'vet active - no privhistory' );
$log->info( "=== $note" );
$status = $fo->_vet_employee( emp_obj => $active );
is( $status->level, 'ERR' );
is( $status->code, 'DISPATCH_EMPLOYEE_NO_PRIVHISTORY' );

note( $note = 'give active a privhistory' );
$log->info( "=== $note" );
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

note( $note = 'vet active - no schedule' );
$log->info( "=== $note" );
$status = $fo->_vet_employee( emp_obj => $active );
is( $status->level, 'ERR' );
is( $status->code, 'DISPATCH_EMPLOYEE_NO_SCHEDULE' );

note( $note = 'create a testing schedule' );
$log->info( "=== $note" );
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

note( $note = 'give active a schedhistory' );
$log->info( "=== $note" );
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

note( $note = 'vet active - all green' );
$log->info( "=== $note" );
$status = $fo->_vet_employee( emp_obj => $active );
is( $status->level, "OK" );
is( $status->code, "SUCCESS" );
isa_ok( $fo->{'emp_obj'}, 'App::Dochazka::REST::Model::Employee' );
is( $fo->{'emp_obj'}->eid, $active->eid );
is( $fo->{'emp_obj'}->nick, 'active' );
my $active_obj = $fo->{'emp_obj'};

note( $note = 'but not fully vetted yet' );
$log->info( "=== $note" );
ok( ! $fo->vetted );

note( $note = 'get AID of WORK' );
$log->info( "=== $note" );
$status = App::Dochazka::REST::Model::Activity->load_by_code( $dbix_conn, 'WORK' );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_RECORDS_FOUND' );
isa_ok( $status->payload, 'App::Dochazka::REST::Model::Activity' );
my $activity = $status->payload;
#diag( "AID of WORK: " . $activity->aid );

note( $note = 'vet activity (default)' );
$log->info( "=== $note" );
$status = $fo->_vet_activity;
is( $status->level, 'OK' );
is( $status->code, 'SUCCESS' );
isa_ok( $fo->{'act_obj'}, 'App::Dochazka::REST::Model::Activity' ); 
is( $fo->{'act_obj'}->code, 'WORK' );
is( $fo->{'act_obj'}->aid, $activity->aid );
is( $fo->{'aid'}, $activity->aid );

note( $note = 'vet non-existent activity 1' );
$log->info( "=== $note" );
$status = $fo->_vet_activity( aid => 'WORBLE' );
is( $status->level, 'ERR' );
is( $status->code, 'DOCHAZKA_DBI_ERR' );

note( $note = 'vet non-existent activity 2' );
$log->info( "=== $note" );
$status = $fo->_vet_activity( aid => '-1' );
is( $status->level, 'ERR' );
is( $status->code, 'DOCHAZKA_GENERIC_NOT_EXIST' );
is( $status->text, 'There is no activity with AID ->-1<-' );

my $note = 'vet non-existent activity 3';
note( $note = $note );
$log->info( "=== $note" );
$log->info( "*** $note" );
$status = $fo->_vet_activity( aid => '0' );
is( $status->level, 'ERR' );
is( $status->code, 'DOCHAZKA_GENERIC_NOT_EXIST' );
is( $status->text, 'There is no activity with AID ->0<-' );

note( $note = 'vet activity WORK by explicit AID' );
$log->info( "=== $note" );
$status = $fo->_vet_activity( aid => $activity->aid );
is( $status->level, 'OK' );
is( $status->code, 'SUCCESS' );
isa_ok( $fo->{'act_obj'}, 'App::Dochazka::REST::Model::Activity' ); 
is( $fo->{'act_obj'}->code, 'WORK' );
is( $fo->{'act_obj'}->aid, $activity->aid );
is( $fo->{'aid'}, $activity->aid );

note( $note = 'vetted now true' );
$log->info( "=== $note" );
ok( $fo->vetted );

note( $note = 'change the tsrange' );
$log->info( "=== $note" );
$status = $fo->_vet_tsrange( tsrange => '[ "April 28, 1998" 10:00, 1998-05-6 10:00 )' );
is( $status->level, 'OK' );
is( $status->code, 'SUCCESS' );
like( $fo->{'tsrange'}, qr/^\["1998-04-28 10:00:00...","1998-05-06 10:00:00..."\)/ );
BAIL_OUT(0);

note( $note = 'proceed with fillup' );
$log->info( "=== $note" );
$status = $fo->fillup;
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_TEMPINTVLS_INSERT_OK' );

note( $note = 'commit (dry run)' );
$log->info( "=== $note" );
$status = $fo->commit( dry_run => 1 );
is( $status->level, 'OK' );
is( $status->code, 'RESULT_SET' );

note( $note = '1998-05-01 should not appear anywhere, as it is a holiday' );
$log->info( "=== $note" );
my $jumbled_together = join( '', @{ $status->payload} );
ok( ! ( $jumbled_together =~ m/1998-05-01/ ) );

note( $note = 'Check for more-or-less exact deep match' );
$log->info( "=== $note" );
like( $status->payload->[0], qr/^\["1998-04-28 10:00:00...","1998-04-28 12:00:00..."\)$/ );
like( $status->payload->[1], qr/^\["1998-04-28 12:30:00...","1998-04-28 16:30:00..."\)$/ );
like( $status->payload->[2], qr/^\["1998-04-29 08:00:00...","1998-04-29 12:00:00..."\)$/ );
like( $status->payload->[3], qr/^\["1998-04-29 12:30:00...","1998-04-29 16:30:00..."\)$/ );
like( $status->payload->[4], qr/^\["1998-04-30 08:00:00...","1998-04-30 12:00:00..."\)$/ );
like( $status->payload->[5], qr/^\["1998-04-30 12:30:00...","1998-04-30 16:30:00..."\)$/ );
like( $status->payload->[6], qr/^\["1998-05-04 08:00:00...","1998-05-04 12:00:00..."\)$/ );
like( $status->payload->[7], qr/^\["1998-05-04 12:30:00...","1998-05-04 16:30:00..."\)$/ );
like( $status->payload->[8], qr/^\["1998-05-05 08:00:00...","1998-05-05 12:00:00..."\)$/ );
like( $status->payload->[9], qr/^\["1998-05-05 12:30:00...","1998-05-05 16:30:00..."\)$/ );
like( $status->payload->[10], qr/^\["1998-05-06 08:00:00...","1998-05-06 10:00:00..."\)$/ );

note( $note = 'test the new() method' );
$log->info( "=== $note" );
my $fo2 = App::Dochazka::REST::Model::Tempintvls->new(
    context => $faux_context,
    tsrange => '[ 1998-04-28 10:00:00, 1998-05-06 10:00:00 )',
    emp_obj => $active,
);
isa_ok( $fo2, 'App::Dochazka::REST::Model::Tempintvls' );
ok( $fo2->constructor_status );
isa_ok( $fo2->constructor_status, 'App::CELL::Status' );
like( $fo2->tsrange, qr/^\["1998-04-28 10:00:00...","1998-05-06 10:00:00..."\)$/ );

note( $note = 'commit (dry run) on object created without using new()' );
$log->info( "=== $note" );
my $count = 11;
foreach my $obj ( $fo, $fo2 ) {
    $status = $obj->commit( dry_run => 1 );
    is( $status->level, 'OK' );
    is( $status->code, 'RESULT_SET' );
    like( $status->payload->[0], qr/^\["1998-04-28 10:00:00...","1998-04-28 12:00:00..."\)$/ );
    like( $status->payload->[1], qr/^\["1998-04-28 12:30:00...","1998-04-28 16:30:00..."\)$/ );
    like( $status->payload->[2], qr/^\["1998-04-29 08:00:00...","1998-04-29 12:00:00..."\)$/ );
    like( $status->payload->[3], qr/^\["1998-04-29 12:30:00...","1998-04-29 16:30:00..."\)$/ );
    like( $status->payload->[4], qr/^\["1998-04-30 08:00:00...","1998-04-30 12:00:00..."\)$/ );
    like( $status->payload->[5], qr/^\["1998-04-30 12:30:00...","1998-04-30 16:30:00..."\)$/ );
    like( $status->payload->[6], qr/^\["1998-05-04 08:00:00...","1998-05-04 12:00:00..."\)$/ );
    like( $status->payload->[7], qr/^\["1998-05-04 12:30:00...","1998-05-04 16:30:00..."\)$/ );
    like( $status->payload->[8], qr/^\["1998-05-05 08:00:00...","1998-05-05 12:00:00..."\)$/ );
    like( $status->payload->[9], qr/^\["1998-05-05 12:30:00...","1998-05-05 16:30:00..."\)$/ );
    like( $status->payload->[10], qr/^\["1998-05-06 08:00:00...","1998-05-06 10:00:00..."\)$/ );
    is( scalar( @{ $status->payload } ), $count );
    is( $status->{'count'}, $count );
}

note( $note = 'really commit the attendance intervals' );
$log->info( "=== $note" );
is( noof( $dbix_conn, 'intervals' ), 0 );
$status = $fo2->commit;
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_TEMPINTVLS_COMMITTED' );
is( $status->{count}, $count );
is( noof( $dbix_conn, 'intervals' ), $count );

note( $note = 'tear down' );
$log->info( "=== $note" );
$status = delete_all_attendance_data();
BAIL_OUT(0) unless $status->ok;

done_testing;
