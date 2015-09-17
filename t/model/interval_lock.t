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
# basic unit tests for activity intervals
#

#!perl
use 5.012;
use strict;
use warnings;

#use App::CELL::Test::LogToFile;
use App::CELL qw( $meta $site );
use Data::Dumper;
use Date::Calc qw( Add_Delta_Days );
use App::Dochazka::Common qw( $yesterday $today $tomorrow );
use App::Dochazka::REST::ConnBank qw( $dbix_conn );
use App::Dochazka::REST::Model::Activity;
use App::Dochazka::REST::Model::Employee;
use App::Dochazka::REST::Model::Interval qw( 
    delete_intervals_by_eid_and_tsrange
    iid_exists 
);
use App::Dochazka::REST::Model::Lock qw( 
    count_locks_in_tsrange
    lid_exists 
);
use App::Dochazka::REST::Model::Schedule;
use App::Dochazka::REST::Model::Schedhistory;
use App::Dochazka::REST::Model::Shared qw( noof tsrange_equal );
use App::Dochazka::REST::Test;
use App::Dochazka::REST::Util::Holiday qw( get_tomorrow );
use Plack::Test;
use Test::More;


note( 'initialize unit' );
my $status = initialize_unit();
plan skip_all => "not configured or server not running" unless $status->ok;
my $app = $status->payload;

note( 'instantiate Plack::Test object' );
my $test = Plack::Test->create( $app );
isa_ok( $test, 'Plack::Test::MockHTTP' );

my $res;
my @locks_to_delete;

note( 'spawn interval object' );
my $int = App::Dochazka::REST::Model::Interval->spawn;
isa_ok( $int, 'App::Dochazka::REST::Model::Interval' );

note( 'to insert an interval, we need an employee, an activity, a schedule, and' );
note( 'a schedhistory record - but just to trigger the error we will hold off' );
note( 'the last two' );

note( 'insert Mr. Sched' );
my $emp = App::Dochazka::REST::Model::Employee->spawn(
    nick => 'mrsched',
);
$status = $emp->insert( $faux_context );
diag( $status->text ) unless $status->ok;
ok( $status->ok );
ok( $emp->eid > 0 );
is( noof( $dbix_conn, 'employees'), 3 );

note( 'load WORK activity' );
$status = App::Dochazka::REST::Model::Activity->load_by_code( $dbix_conn, 'work' );
is( $status->code, 'DISPATCH_RECORDS_FOUND' );
my $work = $status->payload;
ok( $work->aid > 0 );

note( 'prep the interval object' );
$int->eid( $emp->eid );
$int->aid( $work->aid );
my $intvl = "[$today 08:00, $today 12:00)";
$int->intvl( $intvl );
$int->long_desc( 'Pencil pushing' );
$int->remark( 'TEST INTERVAL' );
is( $int->iid, undef );

note( 'Insert the interval' );
$status = $int->insert( $faux_context );
#diag( $status->code . " " . $status->text ) unless $status->ok;
is( $status->level, 'ERR' );
is( $status->code, 'DOCHAZKA_DBI_ERR' );
like( $status->text, qr/insufficient privileges: check employee privhistory/ );

note( 'Hmm - what is Mr. Sched\'s current privlevel anyway?' );
is( $emp->priv( $dbix_conn ), 'passerby' );
# ^^^ the reason for this is Mr.Sched has no privhistory

note( 'make him active' );
my $mrsched_ph = App::Dochazka::REST::Model::Privhistory->spawn(
    eid => $emp->eid,
    priv => 'active',
    effective => '2014-01-01 00:00'
);
$status = $mrsched_ph->insert( $faux_context );
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_CUD_OK' );
is( $emp->priv( $dbix_conn ), 'active');

note( 'Try again to insert the interval' );
$status = $int->insert( $faux_context );
#diag( $status->code . " " . $status->text ) unless $status->ok;
is( $status->level, 'ERR' );
is( $status->code, 'DOCHAZKA_DBI_ERR' );
like( $status->text, qr/employee schedule for this interval cannot be determined/ );

note( 'so we have to insert a schedule and a schedhistory record as well' );
$status = req( $test, 201, 'root', 'POST', 'schedule/new', <<'EOH' );
{ "eid" : 1, "schedule" : [ "[2014-01-02 08:00, 2014-01-02 12:00)" ] }
EOH
my $test_sid = $status->payload->{'sid'};

note( 'and now the schedhistory record' );
my $shr = App::Dochazka::REST::Model::Schedhistory->spawn(
    eid => $emp->eid,
    sid => $test_sid,
    effective => "$today 00:00"
);
$status = $shr->insert( $faux_context );
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_CUD_OK' );

note( 'and now we can insert the object' );
$status = $int->insert( $faux_context );
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_CUD_OK' );
ok( $int->iid > 0 );
my $saved_iid = $int->iid;

note( 'test accessors' );
ok( $int->iid > 0 );
is( $int->eid, $emp->eid );
is( $int->aid, $work->aid );
ok( tsrange_equal( $dbix_conn, $int->intvl, $intvl ) );
is( $int->long_desc, 'Pencil pushing' );
is( $int->remark, 'TEST INTERVAL' );

note( 'load_by_iid' );
$status = App::Dochazka::REST::Model::Interval->load_by_iid( $dbix_conn, $saved_iid );
diag( $status->text ) unless $status->ok;
ok( $status->ok );
is( $status->code, 'DISPATCH_RECORDS_FOUND' );
my $newint = $status->payload;
is( $newint->long_desc, "Pencil pushing" );
my $t_iid = $newint->iid;

note( 'insert a lock covering the entire day' );

note( 'spawn a lock object' );
my $lock = App::Dochazka::REST::Model::Lock->spawn(
    eid => $emp->eid,
    intvl => "[$today 00:00, $today 24:00)",
    remark => 'TESTING',
);
isa_ok( $lock, 'App::Dochazka::REST::Model::Lock' );
#diag( Dumper( $lock ) );

note( 'insert the lock object' );
is( noof( $dbix_conn, 'locks' ), 0 );
$status = $lock->insert( $faux_context );
is( noof( $dbix_conn, 'locks' ), 1 );
push @locks_to_delete, $lock;

note( 'attept to delete the testing interval' );
$status = $int->delete( $faux_context );
is( $status->level, 'ERR' );
is( $status->code, 'DOCHAZKA_DBI_ERR' );
like( $status->text, qr/interval is locked/ );

note( 'now test history_policy triggers:' );
note( '1. the interval runs from 08:00 - 12:00 today' );
note( '2. so attempt to insert a privhistory record effective 10:00 today' );
note( '   -- i.e., a clear policy violation' );
my $vio_ph = App::Dochazka::REST::Model::Privhistory->spawn(
    eid => $emp->eid,
    priv => 'passerby',
    effective => "$today 10:00"
);
$status = $vio_ph->insert( $faux_context );
is( $status->level, 'ERR' );
is( $status->code, 'DOCHAZKA_DBI_ERR' );
like( $status->text, qr/effective timestamp conflicts with existing attendance interval/ );

note( 'do the same with schedhistory' );
my $vio_sh = App::Dochazka::REST::Model::Schedhistory->spawn(
    eid => $emp->eid,
    sid => $test_sid,
    effective => "$today 10:00"
);
$status = $vio_ph->insert( $faux_context );
is( $status->level, 'ERR' );
is( $status->code, 'DOCHAZKA_DBI_ERR' );
like( $status->text, qr/effective timestamp conflicts with existing attendance interval/ );

note( 'test count_locks_in_tsrange()' );
note( 'the lock interval is [$today 00:00, $today 24:00)' );
note( 'so the answer should be resoundingly 1' );
$status = count_locks_in_tsrange( $dbix_conn, $emp->eid, "[$today 00:00, $today 24:00)" );
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_NUMBER_OF_LOCKS' );
is( ref( $status->payload ), '' );
is( $status->payload, 1 );

note( 'yesterday should contain 0 locks' );
$status = count_locks_in_tsrange( $dbix_conn, $emp->eid, "[$yesterday 00:00, $yesterday 24:00)" );
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_NUMBER_OF_LOCKS' );
is( ref( $status->payload ), '' );
is( $status->payload, 0 );

note( 'same for tomorrow' );
$status = count_locks_in_tsrange( $dbix_conn, $emp->eid, "[$tomorrow 00:00, $tomorrow 24:00)" );
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_NUMBER_OF_LOCKS' );
is( ref( $status->payload ), '' );
is( $status->payload, 0 );

note( 'try a tsrange just for the heck of it' );
$status = count_locks_in_tsrange( $dbix_conn, $emp->eid, "[$today 23:00, $tomorrow 1:00)" );
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_NUMBER_OF_LOCKS' );
is( ref( $status->payload ), '' );
is( $status->payload, 1 );

note( 'add another lock' );

note( 'spawn a lock object for tomorrow' );
$lock = App::Dochazka::REST::Model::Lock->spawn(
    eid => $emp->eid,
    intvl => "[$tomorrow 00:00, $tomorrow 24:00)",
    remark => 'TESTING',
);
isa_ok( $lock, 'App::Dochazka::REST::Model::Lock' );
#diag( Dumper( $lock ) );

note( 'insert the lock object for tomorrow' );
is( noof( $dbix_conn, 'locks' ), 1 );
$status = $lock->insert( $faux_context );
is( noof( $dbix_conn, 'locks' ), 2 );
push @locks_to_delete, $lock;

note( 'number of locks from today to tomorrow should be two' );
$status = count_locks_in_tsrange( $dbix_conn, $emp->eid, "[$today 00:00, $tomorrow 24:00)" );
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_NUMBER_OF_LOCKS' );
is( ref( $status->payload ), '' );
is( $status->payload, 2 );

note( 'attempt to delete all intervals in the tsrange [$today 08:00, $today 12:00)' );
$status = delete_intervals_by_eid_and_tsrange( 
    $dbix_conn, 
    $emp->eid, 
    "[$today 00:00, $tomorrow 24:00)",
);
is( $status->level, 'ERR' );
is( $status->code, 'DOCHAZKA_TSRANGE_LOCKED' );
like( $status->text, qr/The tsrange .+ intersects with 2 locks/ );

note( 'delete the locks' );
foreach my $lock ( @locks_to_delete ) {
    ok( lid_exists( $dbix_conn, $lock->lid ) );
    $status = $lock->delete( $faux_context );
    ok( $status->ok );
    ok( ! lid_exists( $dbix_conn, $lock->lid ) );
}
is( noof( $dbix_conn, 'locks' ), 0 );

note( 'second attempt to delete all intervals in the tsrange' );
$status = delete_intervals_by_eid_and_tsrange( 
    $dbix_conn, 
    $emp->eid, 
    "[$today 00:00, $tomorrow 24:00)",
);
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_CUD_OK' );
# payload contains number of records deleted
is( $status->payload, 1 );

note( 'create a 80 intervals' );
my $d = $today;
my ( $by, $bm, $bd ) = $d =~ m/(\d+)-(\d+)-(\d+)/;
my ( $ey, $em, $ed ) = Add_Delta_Days( $by, $bm, $bd, 40 );
my $end_date = sprintf( "%04d-%02d-%02d", $ey, $em, $ed );
my $count = 0;
while ( $d ne $end_date ) {
    foreach my $intvl ( "[ $d 08:00, $d 12:00 )", "[ $d 12:30, $d 16:30 )" ) {
        $count += 1;
        $int->iid( undef );
        $int->intvl( $intvl );
        $status = $int->insert( $faux_context );
        is( $status->level, 'OK' );
        is( $status->code, 'DOCHAZKA_CUD_OK' );
        ok( $int->iid > 0 );
    }
    $d = get_tomorrow( $d );
}
is( $count, 80 );

note( 'and promptly delete them all' );
$status = delete_intervals_by_eid_and_tsrange( 
    $dbix_conn, 
    $emp->eid, 
    "[$today 00:00, $d 24:00)",
);
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_CUD_OK' );
# payload contains number of records deleted
is( $status->payload, 80 );

note( 'create a 260 intervals' );
$d = $today;
( $by, $bm, $bd ) = $d =~ m/(\d+)-(\d+)-(\d+)/;
( $ey, $em, $ed ) = Add_Delta_Days( $by, $bm, $bd, 65 );
$end_date = sprintf( "%04d-%02d-%02d", $ey, $em, $ed );
$count = 0;
while ( $d ne $end_date ) {
    foreach my $intvl ( "[ $d 08:00, $d 10:00 )", "[ $d 10:00, $d 12:00 )", "[ $d 12:30, $d 14:30 )", "[ $d 14:30, $d 16:30 )" ) {
        $count += 1;
        $int->iid( undef );
        $int->intvl( $intvl );
        $status = $int->insert( $faux_context );
        if( $status->not_ok ) {
            diag( "Count: $count" );
            diag( Dumper $status );
            BAIL_OUT(0);
        }
        is( $status->level, 'OK' );
        is( $status->code, 'DOCHAZKA_CUD_OK' );
        ok( $int->iid > 0 );
    }
    $d = get_tomorrow( $d );
}
is( $count, 260 );

note( 'and try to delete them all, but fail because limit is 250 intervals deleted at one time' );
$status = delete_intervals_by_eid_and_tsrange( 
    $dbix_conn, 
    $emp->eid, 
    "[$today 00:00, $d 24:00)",
);
is( $status->level, 'ERR' );
is( $status->code, 'DOCHAZKA_INTERVAL_DELETE_LIMIT_EXCEEDED' );

note( 'delete them in two batches' );
my ( $my, $mm, $md ) = $d =~ m/(\d+)-(\d+)-(\d+)/;
( $my, $mm, $md ) = Add_Delta_Days( $my, $mm, $md, -30 );
my $mid_d = sprintf( "%04d-%02d-%02d", $my, $mm, $md );

note( 'first batch' );
$status = delete_intervals_by_eid_and_tsrange( 
    $dbix_conn, 
    $emp->eid, 
    "[$today 00:00, $mid_d 24:00)",
);
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_CUD_OK' );
## payload contains number of records deleted
#diag( "Batch 1: " . $status->payload . " deleted" );
is( $status->payload, 144 );

note( 'second batch' );
$status = delete_intervals_by_eid_and_tsrange( 
    $dbix_conn, 
    $emp->eid, 
    "[$mid_d 00:00, $d 24:00)",
);
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_CUD_OK' );
## payload contains number of records deleted
#diag( "Batch 2: " . $status->payload . " deleted" );
is( $status->payload, 116 );

note( 'delete the privhistory record' );
$status = $mrsched_ph->delete( $faux_context );
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_CUD_OK' );

note( 'delete the schedhistory record' );
$status = $shr->delete( $faux_context );
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_CUD_OK' );

note( 'delete the schedule' );
$status = App::Dochazka::REST::Model::Schedule->load_by_sid( $dbix_conn, $test_sid );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_RECORDS_FOUND' );
$status = $status->payload->delete( $faux_context );
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_CUD_OK' );

note( 'delete Mr. Sched himself' );
is( noof( $dbix_conn, 'employees' ), 3 );
$status = $emp->delete( $faux_context );
ok( $status->ok );
is( noof( $dbix_conn, 'employees' ), 2 );

done_testing;
