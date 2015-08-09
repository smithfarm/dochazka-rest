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

use App::CELL::Test::LogToFile;
use App::CELL qw( $meta $site );
use Data::Dumper;
#use App::Dochazka::Common qw( $today $yesterday $tomorrow );
use App::Dochazka::REST::ConnBank qw( $dbix_conn );
use App::Dochazka::REST::Model::Tempintvls;
use App::Dochazka::REST::Model::Shared qw( noof );
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
ok( $status->ok );
is( $tio->{'tsrange'}, '[ 2015-01-01 00:00:00+01, 2015-12-31 00:00:00+01 )' );

# CLEANUP: none as this unit test doesn't change the database

done_testing;
