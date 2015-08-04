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
# test functions in Util/Holiday.pm
#
# (does not access the database)

#!perl
use 5.012;
use strict;
use warnings;

#use App::CELL::Test::LogToFile;
use App::CELL qw( $meta $site );
use Data::Dumper;
use App::Dochazka::REST::Util::Holiday qw( get_tomorrow holidays_in_daterange is_weekend );
use Test::More;

my ( %dr, $res, $d );

note( 'convert arbitrary date range into a list of dates' );
%dr = (
    "begin" => '2015-01-01',
    "end" => '2015-01-30'
);
$d = $dr{begin};
while ( $d ne get_tomorrow( $dr{end} ) ) {
    push @$res, $d;
    $d = get_tomorrow( $d );
}
is_deeply( $res, [ 
    '2015-01-01', '2015-01-02', '2015-01-03', '2015-01-04', '2015-01-05', '2015-01-06', 
    '2015-01-07', '2015-01-08', '2015-01-09', '2015-01-10', '2015-01-11', '2015-01-12', 
    '2015-01-13', '2015-01-14', '2015-01-15', '2015-01-16', '2015-01-17', '2015-01-18', 
    '2015-01-19', '2015-01-20', '2015-01-21', '2015-01-22', '2015-01-23', '2015-01-24', 
    '2015-01-25', '2015-01-26', '2015-01-27', '2015-01-28', '2015-01-29', '2015-01-30',
] );

note( 'convert arbitrary date range into a list of dates, adding W for weekend' );
$res = [];
$d = $dr{begin};
while ( $d ne get_tomorrow( $dr{end} ) ) {
    if ( is_weekend( $d ) ) {
        push @$res, ( "${d}W" );
    } else {
        push @$res, "$d";
    }
    $d = get_tomorrow( $d );
}
is_deeply( $res, [
    '2015-01-01', '2015-01-02', '2015-01-03W', '2015-01-04W', '2015-01-05', '2015-01-06',
    '2015-01-07', '2015-01-08', '2015-01-09', '2015-01-10W', '2015-01-11W', '2015-01-12',
    '2015-01-13', '2015-01-14', '2015-01-15', '2015-01-16', '2015-01-17W', '2015-01-18W',
    '2015-01-19', '2015-01-20', '2015-01-21', '2015-01-22', '2015-01-23', '2015-01-24W',
    '2015-01-25W', '2015-01-26', '2015-01-27', '2015-01-28', '2015-01-29', '2015-01-30'
] );

note( 'get holidays in that date range' );
$res = holidays_in_daterange( %dr );
my $holidays = $res->{'holidays'};
is_deeply( $holidays, { '2015-01-01' => '' } );

note( 'walk the date range again, adding W for weekend and H for holiday' );
$res = [];
$d = $dr{begin};
while ( $d ne get_tomorrow( $dr{end} ) ) {
    my $tag = '';
    if ( is_weekend( $d ) ) {
        $tag .= 'W';
    }
    if ( exists( $holidays->{ $d } ) ) {
        $tag .= 'H';
    }
    push @$res, "$d$tag";
    $d = get_tomorrow( $d );
}
is_deeply( $res, [
    '2015-01-01H', '2015-01-02', '2015-01-03W', '2015-01-04W', '2015-01-05', '2015-01-06',
    '2015-01-07', '2015-01-08', '2015-01-09', '2015-01-10W', '2015-01-11W', '2015-01-12',
    '2015-01-13', '2015-01-14', '2015-01-15', '2015-01-16', '2015-01-17W', '2015-01-18W',
    '2015-01-19', '2015-01-20', '2015-01-21', '2015-01-22', '2015-01-23', '2015-01-24W',
    '2015-01-25W', '2015-01-26', '2015-01-27', '2015-01-28', '2015-01-29', '2015-01-30'
] );

done_testing;
