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
use warnings FATAL => 'all';

#use App::CELL::Test::LogToFile;
use App::CELL qw( $meta $site );
use Data::Dumper;
use App::Dochazka::Common qw( $today );
use App::Dochazka::REST::ConnBank qw( $dbix_conn );
use App::Dochazka::REST::Model::Activity;
use App::Dochazka::REST::Model::Employee;
use App::Dochazka::REST::Model::Interval qw( iid_exists );
use App::Dochazka::REST::Model::Lock qw( lid_exists );
use App::Dochazka::REST::Model::Schedule;
use App::Dochazka::REST::Model::Schedhistory;
use App::Dochazka::REST::Model::Shared qw( noof tsrange_equal );
use App::Dochazka::REST::Test;
use Plack::Test;
use Test::More;


# initialize 
my $status = initialize_unit();
plan skip_all => "not configured or server not running" unless $status->ok;
my $app = $status->payload;

# instantiate Plack::Test object
my $test = Plack::Test->create( $app );
isa_ok( $test, 'Plack::Test::MockHTTP' );

my $res;

# spawn interval object
my $int = App::Dochazka::REST::Model::Interval->spawn;
isa_ok( $int, 'App::Dochazka::REST::Model::Interval' );

# to insert an interval, we need an employee, an activity, a schedule, and a schedhistory
# record - but just to trigger the error we will hold off the last two

# insert Mr. Sched
my $emp = App::Dochazka::REST::Model::Employee->spawn(
    nick => 'mrsched',
);
$status = $emp->insert( $faux_context );
diag( $status->text ) unless $status->ok;
ok( $status->ok );
ok( $emp->eid > 0 );
is( noof( $dbix_conn, 'employees'), 3 );

# load 'WORK'
$status = App::Dochazka::REST::Model::Activity->load_by_code( $dbix_conn, 'work' );
is( $status->code, 'DISPATCH_RECORDS_FOUND' );
my $work = $status->payload;
ok( $work->aid > 0 );

# Prep the interval object
$int->{eid} = $emp->eid;
$int->{aid} = $work->aid;
my $intvl = "[$today 08:00, $today 12:00)";
$int->{intvl} = $intvl;
$int->{long_desc} = 'Pencil pushing';
$int->{remark} = 'TEST INTERVAL';
is( $int->iid, undef );

# Insert the interval
$status = $int->insert( $faux_context );
#diag( $status->code . " " . $status->text ) unless $status->ok;
is( $status->level, 'ERR' );
is( $status->code, 'DOCHAZKA_DBI_ERR' );
like( $status->text, qr/insufficient privileges: check employee privhistory/ );

# Hmm - what is Mr. Sched's current privlevel anyway?
is( $emp->priv( $dbix_conn ), 'passerby' );
# ^^^ the reason for this is Mr.Sched has no privhistory

# make him active
my $mrsched_ph = App::Dochazka::REST::Model::Privhistory->spawn(
    eid => $emp->eid,
    priv => 'active',
    effective => '2014-01-01 00:00'
);
$status = $mrsched_ph->insert( $faux_context );
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_CUD_OK' );
is( $emp->priv( $dbix_conn ), 'active');

# Try again to insert the interval
$status = $int->insert( $faux_context );
#diag( $status->code . " " . $status->text ) unless $status->ok;
is( $status->level, 'ERR' );
is( $status->code, 'DOCHAZKA_DBI_ERR' );
like( $status->text, qr/employee schedule for this interval cannot be determined/ );

# so we have to insert a schedule and a schedhistory record as well
#
$status = req( $test, 201, 'root', 'POST', 'schedule/new', <<'EOH' );
{ "eid" : 1, "schedule" : [ "[2014-01-02 08:00, 2014-01-02 12:00)" ] }
EOH
my $test_sid = $status->payload->{'sid'};
#
# - and now the schedhistory record
my $shr = App::Dochazka::REST::Model::Schedhistory->spawn(
    eid => $emp->eid,
    sid => $test_sid,
    effective => "$today 00:00"
);
$status = $shr->insert( $faux_context );
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_CUD_OK' );

# and now we can insert the object
$status = $int->insert( $faux_context );
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_CUD_OK' );
ok( $int->iid > 0 );
my $saved_iid = $int->iid;

# test accessors
ok( $int->iid > 0 );
is( $int->eid, $emp->eid );
is( $int->aid, $work->aid );
ok( tsrange_equal( $dbix_conn, $int->intvl, $intvl ) );
is( $int->long_desc, 'Pencil pushing' );
is( $int->remark, 'TEST INTERVAL' );

# load_by_iid
$status = App::Dochazka::REST::Model::Interval->load_by_iid( $dbix_conn, $saved_iid );
diag( $status->text ) unless $status->ok;
ok( $status->ok );
is( $status->code, 'DISPATCH_RECORDS_FOUND' );
my $newint = $status->payload;
is( $newint->long_desc, "Pencil pushing" );
my $t_iid = $newint->iid;

# insert a lock covering the entire day

# spawn a lock object
my $lock = App::Dochazka::REST::Model::Lock->spawn(
    eid => $emp->eid,
    intvl => "[$today 00:00, $today 24:00)",
    remark => 'TESTING',
);
isa_ok( $lock, 'App::Dochazka::REST::Model::Lock' );
#diag( Dumper( $lock ) );

# insert the lock object
is( noof( $dbix_conn, 'locks' ), 0 );
$status = $lock->insert( $faux_context );
is( noof( $dbix_conn, 'locks' ), 1 );
my $t_lid = $status->payload->lid;

# attept to delete the testing interval
$status = $int->delete( $faux_context );
is( $status->level, 'ERR' );
is( $status->code, 'DOCHAZKA_DBI_ERR' );
like( $status->text, qr/interval is locked/ );

# now test history_policy triggers:
# 1. the interval runs from 08:00 - 12:00 today
# 2. so attempt to insert a privhistory record effective 10:00 today 
#    -- i.e., a clear policy violation
my $vio_ph = App::Dochazka::REST::Model::Privhistory->spawn(
    eid => $emp->eid,
    priv => 'passerby',
    effective => "$today 10:00"
);
$status = $vio_ph->insert( $faux_context );
is( $status->level, 'ERR' );
is( $status->code, 'DOCHAZKA_DBI_ERR' );
like( $status->text, qr/effective timestamp conflicts with existing attendance interval/ );

# do the same with schedhistory
my $vio_sh = App::Dochazka::REST::Model::Schedhistory->spawn(
    eid => $emp->eid,
    sid => $test_sid,
    effective => "$today 10:00"
);
$status = $vio_ph->insert( $faux_context );
is( $status->level, 'ERR' );
is( $status->code, 'DOCHAZKA_DBI_ERR' );
like( $status->text, qr/effective timestamp conflicts with existing attendance interval/ );

# CLEANUP:
# 1. delete the lock
ok( lid_exists( $dbix_conn, $t_lid ) );
is( noof( $dbix_conn, 'locks' ), 1 );
$status = $lock->delete( $faux_context );
ok( $status->ok );
ok( ! lid_exists( $dbix_conn, $t_lid ) );
is( noof( $dbix_conn, 'locks' ), 0 );

# 2. delete the interval
ok( iid_exists( $dbix_conn, $t_iid ) );
is( noof( $dbix_conn, 'intervals' ), 1 );
$status = $int->delete( $faux_context );
ok( $status->ok );
ok( ! iid_exists( $dbix_conn, $t_iid ) );
is( noof( $dbix_conn, 'intervals' ), 0 );

# 3. delete the privhistory record
$status = $mrsched_ph->delete( $faux_context );
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_CUD_OK' );

# 4. delete the schedhistory record
$status = $shr->delete( $faux_context );
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_CUD_OK' );

# 5. delete the schedule
$status = App::Dochazka::REST::Model::Schedule->load_by_sid( $dbix_conn, $test_sid );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_RECORDS_FOUND' );
$status = $status->payload->delete( $faux_context );
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_CUD_OK' );

# 6. delete Mr. Sched himself
is( noof( $dbix_conn, 'employees' ), 3 );
$status = $emp->delete( $faux_context );
ok( $status->ok );
is( noof( $dbix_conn, 'employees' ), 2 );

done_testing;
