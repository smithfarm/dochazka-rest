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
# test the canonicalize_ts and canonicalize_tsrange utility functions
#

#!perl
use 5.012;
use strict;
use warnings;

#use App::CELL::Test::LogToFile;
use App::CELL qw( $meta $site );
use Data::Dumper;
use App::Dochazka::REST::ConnBank qw( $dbix_conn );
use App::Dochazka::REST::Model::Shared qw( 
    canonicalize_date
    canonicalize_ts 
    canonicalize_tsrange 
    split_tsrange 
);
use App::Dochazka::REST::Test;
use Test::More;


note( 'initialize, connect to database, and set up a testing plan' );
my $status = initialize_unit();
if ( $status->not_ok ) {
    plan skip_all => "not configured or server not running";
}

note( 'canonicalize a legal timestamp' );
$status = canonicalize_ts( $dbix_conn, '2015-01-1' );
is( $status->level, 'OK' );
like( $status->payload, qr/^2015-01-01 00:00:00/ );

note( 'attempt to canonicalize an illegal timestamp' );
$status = canonicalize_ts( $dbix_conn, '2015-01-99' );
is( $status->level, 'ERR' );
is( $status->code, 'DOCHAZKA_DBI_ERR' );
like( $status->text, qr/date\/time field value out of range/ );

note( 'canonicalize a legal tsrange' );
$status = canonicalize_tsrange( $dbix_conn, '[ 2015-01-1, 2015-02-1 )' );
is( $status->level, 'OK' );
like( $status->payload, qr/^\[.*2015-01-01 00:00:00.*2015-02-01 00:00:00.*\)/ );

note( 'split a legal tsrange' );
$status = split_tsrange( $dbix_conn, '[ 2015-01-1, 2015-02-1 )' );
is( $status->level, 'OK' );
is_deeply( $status->payload, [
           '2015-01-01 00:00:00+01',
           '2015-02-01 00:00:00+01'
         ] );

note( 'attempt to canonicalize an illegal timestamp' );
$status = canonicalize_ts( $dbix_conn, '[2015-01-99, 2015-02-1)' );
is( $status->level, 'ERR' );
is( $status->code, 'DOCHAZKA_DBI_ERR' );
like( $status->text, qr/invalid input syntax for type timestamp with time zone/ );

note( 'attempt to canonicalize an illegal timestamp' );
$status = canonicalize_tsrange( $dbix_conn, '[2015-02-13, 2015-02-1)' );
is( $status->level, 'ERR' );
is( $status->code, 'DOCHAZKA_DBI_ERR' );
like( $status->text, qr/range lower bound must be less than or equal to range upper bound/ );

note( 'attempt to split an illegal tsrange' );
$status = split_tsrange( $dbix_conn, '[2015-01-99, 2015-02-1)' );
is( $status->level, 'ERR' );
is( $status->code, 'DOCHAZKA_DBI_ERR' );
like( $status->text, qr#date/time field value out of range: "2015-01-99"# );

note( 'attempt to canonicalize an innocent-looking date' );
$status = canonicalize_date( $dbix_conn, 'May 1, 2015' );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_RECORDS_FOUND' );
is( $status->payload, '2015-05-01' );

note( 'attempt to canonicalize an out-of-range date' );
$status = canonicalize_date( $dbix_conn, 'Jan 99, 2015' );
is( $status->level, 'ERR' );
is( $status->code, 'DOCHAZKA_DBI_ERR' );
like( $status->text, qr#date/time field value out of range: "Jan 99, 2015"# );

# attempt to split_tsrange bogus tsranges individually
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
        $status = split_tsrange( $dbix_conn, $_ );
        #diag( $status->level . ' ' . $status->text );
        is( $status->level, 'ERR' ); 
    } @$bogus;

done_testing;
