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
# test that our model does not allow ID ('eid', 'aid', 'iid', etc.) fields
# to be changed in the database
#

#!perl
use 5.012;
use strict;
use warnings;

#use App::CELL::Test::LogToFile;
use App::CELL qw( $meta $site );
use App::Dochazka::REST::Model::Activity;
use App::Dochazka::REST::Test;
use Test::More;


note( "initialize, connect to database, and set up a testing plan" );
my $status = initialize_unit();
if ( $status->not_ok ) {
    plan skip_all => "not configured or server not running";
}


#
# dispatch map enabling 'gen_...' functions to be called from within the loop
# - these functions are imported automatically from App::Dochazka::REST::Test
#
my %d_map = (
    'activity' => \&gen_activity,
    'employee' => \&gen_employee,
    'interval' => \&gen_interval,
    'lock' => \&gen_lock,
    'privhistory' => \&gen_privhistory,
    'schedhistory' => \&gen_schedhistory,
    'schedule' => \&gen_schedule,
);

#
# the id map enabling the ID property/accessor to be referred to from within the loop
#
my %id_map = (
    'activity' => 'aid',
    'employee' => 'eid',
    'interval' => 'iid',
    'lock' => 'lid',
    'privhistory' => 'phid',
    'schedhistory' => 'shid',
    'schedule' => 'sid',
);

#
# the main testing loop
#
foreach my $cl ( 
    'activity',
    'employee',
#    'interval',
#    'lock',
#    'privhistory',
#    'schedhistory',
#    'schedule',
) {

    #DEBUG
    #diag( "Testing model class: $cl" );
    #DEBUG

    # first, create a test object
    my $testobj = $d_map{$cl}->( 'create' );

    # second, create a pristine clone of that object to compare against
    my $testclone = $testobj->clone;

    # attempt to change ID to a different integer
    ok( $testobj->{$id_map{$cl}} != 2397 );
    $testobj->{$id_map{$cl}} = 2397;
    is( $testobj->{$id_map{$cl}}, 2397 );
    my $status = $testobj->update( $faux_context );
    is( $status->level, 'OK' );
    is( $testobj->{$id_map{$cl}}, 2397 ); # object not restored, even though no records were affected
                           # in other words, the object is no longer in sync with the database
                           # but this is our own fault for changing the ID
    
    # restore object to pristine state
    $testobj->{$id_map{$cl}} = $testclone->{$id_map{$cl}};
    is_deeply( $testobj, $testclone );
    
    # retrieve test object from database and check that it didn't change
    $status = $d_map{$cl}->( 'retrieve' );
    is_deeply( $testclone, $status->payload );
    
    # attempt to change ID to a totally bogus value -- note that this cannot
    # work because the update method plugs the id value into the WHERE clause
    # of the SQL statement
    $testobj->{$id_map{$cl}} = '-153jjj*';
    is( $testobj->{$id_map{$cl}}, '-153jjj*' );
    $status = $testobj->update( $faux_context );
    is( $status->level, 'ERR' );
    is( $status->code, 'DOCHAZKA_DBI_ERR' );
    like( $status->text, qr/invalid input syntax for integer/ );
    is( $testobj->{$id_map{$cl}}, '-153jjj*' );   # EID is set wrong
    
    # restore object to pristine state
    $testobj->{$id_map{$cl}} = $testclone->{$id_map{$cl}};
    is_deeply( $testobj, $testclone );
    
    # attempt to change ID to 'undef'
    $testobj->{$id_map{$cl}} = undef;
    is( $testobj->{$id_map{$cl}}, undef );
    $status = $testobj->update( $faux_context );
    is( $status->level, 'ERR' );
    is( $status->code, 'DOCHAZKA_MALFORMED_400' );
    
    # restore object to pristine state
    $testobj->{$id_map{$cl}} = $testclone->{$id_map{$cl}};
    is_deeply( $testobj, $testclone );
    
    # delete the database record
    $d_map{$cl}->( 'delete' );

    # gone
    $status = $d_map{$cl}->( 'retrieve' );
    is( $status->level, 'NOTICE' );
    is( $status->code, 'DISPATCH_NO_RECORDS_FOUND' );
}

done_testing;
