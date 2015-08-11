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

#!perl
use 5.012;
use strict;
use warnings FATAL => 'all';

#use App::CELL::Test::LogToFile;
use App::CELL qw( $meta $site );
use Data::Dumper;
use DBI;
use App::Dochazka::REST::ConnBank qw( $dbix_conn );
use App::Dochazka::REST::Model::Shared qw( split_tsrange );
use App::Dochazka::REST::Test;
use Test::Fatal;
use Test::More;

note( 'initialize, connect to database, and set up a testing plan' );
my $status = initialize_unit();
if ( $status->not_ok ) {
    plan skip_all => "not configured or server not running";
}

sub test_is_ok {
    my ( $status, $deep ) = @_;
    is( $status->level, 'OK' );
    is( $status->code, 'DISPATCH_RECORDS_FOUND' );
    is_deeply( $status->payload, $deep );
}

note( 'split boring tsrange' );
$status = split_tsrange( $dbix_conn, '[ 1957-01-01 00:00, 1957-01-02 00:00 )' );
test_is_ok( $status, [
   '1957-01-01 00:00:00+01',
   '1957-01-02 00:00:00+01'
] );

note( 'split a less boring tsrange' );
$status = split_tsrange( $dbix_conn, '( 2000-1-9, 2100-12-1 ]' );
test_is_ok( $status, [
    '2000-01-09 00:00:00+01',
    '2100-12-01 00:00:00+01'
] );

note( 'split a seemingly illegal tsrange' );
$status = split_tsrange( $dbix_conn, '( 1979-4-002 1:1, 1980-4-11 1:2 )' );
test_is_ok( $status, [
    '1979-04-02 01:01:00+02',
    '1980-04-11 01:02:00+02'
] );

note( 'split a half-undefined tsrange (1)' );
$status = split_tsrange( $dbix_conn, '(1979-4-02, )' );
is( $status->level, 'ERR' );
is( $status->code, 'DOCHAZKA_DBI_ERR' );

note( 'split a half-undefined tsrange (2)' );
$status = split_tsrange( $dbix_conn, '(1979-4-02,)' );
is( $status->level, 'ERR' );
is( $status->code, 'UNBOUNDED_TSRANGE' );

note( 'split a half-undefined tsrange (3)' );
$status = split_tsrange( $dbix_conn, '( , 1979-4-02 )' );
is( $status->level, 'ERR' );
is( $status->code, 'DOCHAZKA_DBI_ERR' );

note( 'split a half-undefined tsrange (4)' );
$status = split_tsrange( $dbix_conn, '(,1979-4-02)' );
is( $status->level, 'ERR' );
is( $status->code, 'UNBOUNDED_TSRANGE' );

note( 'split a half-undefined tsrange (5)' );
$status = split_tsrange( $dbix_conn, '[ 1979-4-02,  ]' );
is( $status->level, 'ERR' );
is( $status->code, 'DOCHAZKA_DBI_ERR' );

note( 'split a half-undefined tsrange (6)' );
$status = split_tsrange( $dbix_conn, '[ 1979-4-02,]' );
is( $status->level, 'ERR' );
is( $status->code, 'UNBOUNDED_TSRANGE' );

note( 'split a half-undefined tsrange (7)' );
$status = split_tsrange( $dbix_conn, '[ , 1979-4-02 ]' );
is( $status->level, 'ERR' );
is( $status->code, 'DOCHAZKA_DBI_ERR' );

note( 'split a half-undefined tsrange (8)' );
$status = split_tsrange( $dbix_conn, '[,1979-4-02]' );
is( $status->level, 'ERR' );
is( $status->code, 'UNBOUNDED_TSRANGE' );

note( 'split several completely undefined tsranges' );
my @non_ranges = ( 
    '[,]',
    '[ , ]',
    '[,)',
    '[, )',
    '(,]',
    '( ,]',
    '(,)',
    '( , )',
    '[infinity,]',
    '[ ,infinity ]',
    '[,infinity)',
    '[infinity, )',
    '(,infinity]',
    '( infinity ,infinity]',
    '(infinity,)',
    '( ,infinity )',
);
foreach my $non_range ( @non_ranges ) {
    $status = split_tsrange( $dbix_conn, '[,]' );
    is( $status->level, 'ERR' );
    is( $status->code, 'UNBOUNDED_TSRANGE' );
}

done_testing;
