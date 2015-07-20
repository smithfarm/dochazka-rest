# ************************************************************************* 
# Copyright (c) 2014, SUSE LLC
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

#!perl
use 5.012;
use strict;
use warnings FATAL => 'all';

#use App::CELL::Test::LogToFile;
use App::CELL qw( $meta $site );
use Data::Dumper;
use DBI;
use App::Dochazka::REST::Model::Activity;
use App::Dochazka::REST::Model::Employee;
use App::Dochazka::REST::Model::Interval;
use App::Dochazka::REST::Model::Lock;
use App::Dochazka::REST::Model::Schedule;
use App::Dochazka::REST::Model::Shared qw( noof );
use App::Dochazka::REST::Test;
use Test::Fatal;
use Test::More;

# plan tests

#plan skip_all => "Set DOCHAZKA_TEST_MODEL to activate data model tests" if ! defined $ENV{'DOCHAZKA_TEST_MODEL'};


# initialize, connect to database, and set up a testing plan
my $status = initialize_unit();
if ( $status->not_ok ) {
    plan skip_all => "not configured or server not running";
}

my %props_dispatch = (
    'Activity' => {
        aid => undef,
        code => 'BAZZED_BAR',
        long_desc => 'not interesting',
        remark => 'interesting',
        disabled => 0,
    },
    'Employee' => {
        eid => undef,
        sec_id => undef,
        nick => 'missreset',
        fullname => 'Miss Reset Machine',
        email => 'parboiled@reset-pieces.com',
        passhash => 'foo',
        salt => 'bar',
        supervisor => undef,
        remark => 'why me?',
    },
    'Interval' => {
        iid => undef,
        eid => 55,
        aid => 23,
        code => 'NOT_A_CODE',
        intvl => '("1553-02-21 00:15","1557-06-13 17:45")',
        long_desc => 'not really very long',
        remark => 'let this one pass',
    },
    'Lock' => {
        lid => undef,
        eid => 22,
        intvl => '("1653-02-21 00:15","1657-06-13 17:45")', 
        remark => 'bazblat',
    },
    'Privhistory' => {
        phid => undef, 
        eid => 4434,
        priv => 'passerby',
        effective => 'someday',
        remark => 'that\'s not a timestamptz!',
    },
    'Schedhistory' => {
        shid => undef, 
        eid => 44,
        sid => 93432,
        effective => 'some year',
        remark => 'that\'s not a paparazzi!',
    },
    'Schedule' => {
        sid => undef,
        scode => 'GUINEA_PIG',
        schedule => "This is definitely NOT a guinea pig",
        remark => "sure it is",
        disabled => 1,
    },
);

foreach my $cl (
    'Activity',
    'Employee',
    'Interval',
    'Lock',
    'Privhistory',
    'Schedhistory',
    'Schedule',
) {
    my $full_class = 'App::Dochazka::REST::Model::' . $cl;

    # attempt to spawn a hooligan
    like( exception { $full_class->spawn( 'hooligan' => 'sneaking in' ); },
          qr/not listed in the validation options: hooligan/ );

    # spawn testing object
    my $testobj = $full_class->spawn( %{ $props_dispatch{$cl} } );
    
    # reset it
    $testobj->reset;
    
    # verify that we have all the properties right
    foreach my $prop ( @{ $full_class->attrs } ) {
        ok( exists( $props_dispatch{$cl}->{$prop} ) );
    }
    my %attrs;
    map { $attrs{$_} = ''; } @{ $full_class->attrs };
    foreach my $prop ( keys( %{ $props_dispatch{$cl} } ) ) {
        ok( exists( $attrs{$prop} ) );
    }

    # verify that all properties have been set to undef
    foreach my $prop ( @{ $full_class->attrs } ) {
        is( $testobj->{$prop}, undef );
    }
}
    
done_testing;
