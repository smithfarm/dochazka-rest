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
# test component resources
#

#!perl
use 5.012;
use strict;
use warnings;

#use App::CELL::Test::LogToFile;
use App::CELL qw( $log $meta $site );
use App::Dochazka::REST::Test;
use Data::Dumper;
use JSON;
use Plack::Test;
use Test::JSON;
use Test::More;
use Test::Warnings;

note( 'initialize, connect to database, and set up a testing plan' );
my $app = initialize_regression_test();

note( 'instantiate Plack::Test object' );
my $test = Plack::Test->create( $app );

my $res;


note( '========================' );
note( '"component/cid" resource' );
note( '========================' );
my $base = 'component/cid';
docu_check($test, "$base");

note( "GET, PUT on $base" );
foreach my $method ( 'GET', 'PUT' ) {
    foreach my $user ( 'demo', 'active', 'root', 'WOMBAT5', 'WAMBLE owdkmdf 5**' ) {
        req( $test, 405, $user, $method, $base );
    }
}

note( "POST on $base" );
my $foowop = create_testing_component( path => 'FOOWOP', source => 'nada', acl => 'passerby' );
my $cid_of_foowop = $foowop->cid;

note( 'test if expected behavior behaves as expected (update)' );
my $component_obj = '{ "cid" : ' . $cid_of_foowop . ', "source" : "wop wop ng", "acl" : "inactive" }';
req( $test, 403, 'demo', 'POST', $base, $component_obj );
my $status = req( $test, 200, 'root', 'POST', $base, $component_obj );
is( $status->level, 'OK', "POST $base 4" );
is( $status->code, 'DOCHAZKA_CUD_OK', "POST $base 5" );
ok( defined $status->payload );
is( $status->payload->{'acl'}, 'inactive', "POST $base 6" );
is( $status->payload->{'source'}, 'wop wop ng', "POST $base 7" );

note( 'non-existent cid and also out of range' );
$component_obj = '{ "cid" : 3434342342342, "source" : 3434341, "acl" : "passerby" }';
dbi_err( $test, 500, 'root', 'POST', $base, $component_obj, qr/out of range for type integer/ );

note( 'non-existent cid' );
$component_obj = '{ "cid" : 342342342, "source" : 3434341, "acl" : "passerby" }';
req( $test, 404, 'root', 'POST', $base, $component_obj );

note( 'throw a couple curve balls' );
my $weirded_object = '{ "copious_turds" : 555, "source" : "wang wang wazoo", "acl" : "passerby" }';
req( $test, 400, 'root', 'POST', $base, $weirded_object );

my $no_closing_bracket = '{ "copious_turds" : 555, "source" : "wang wang wazoo", "acl" : "passerby"';
req( $test, 400, 'root', 'POST', $base, $no_closing_bracket );

$weirded_object = '{ "cid" : "!!!!!", "source" : "down it goes" }';
dbi_err( $test, 500, 'root', 'POST', $base, $weirded_object, qr/invalid input syntax for integer/ );

note( 'delete the testing component' );
delete_testing_component( $cid_of_foowop );

note( "DELETE on $base" );
req( $test, 405, 'demo', 'DELETE', $base );
req( $test, 405, 'root', 'DELETE', $base );
req( $test, 405, 'WOMBAT5', 'DELETE', $base );


note( '=============================' );
note( '"component/cid/:cid" resource' );
note( '=============================' );
$base = 'component/cid';
docu_check($test, "$base/:cid");

note( 'insert an component and disable it here' );
my $foobar = create_testing_component( path => 'FOOBAR', source => 'wombat', acl => 'passerby' );
my $cid_of_foobar = $foobar->cid;

note( "GET on $base/:cid" );

note( "fail as demo 403" );
req( $test, 403, 'demo', 'GET', "$base/$cid_of_foobar" );

note( "succeed as root cid_of_foobar" );
$status = req( $test, 200, 'root', 'GET', "$base/$cid_of_foobar" );
ok( $status->ok, "GET $base/:cid 2" );
is( $status->code, 'DISPATCH_COMPONENT_FOUND', "GET $base/:cid 3" );
is_deeply( $status->payload, {
    cid => $cid_of_foobar,
    path => 'FOOBAR',
    source => 'wombat',
    acl => 'passerby',
}, "GET $base/:cid 4" );

note( "fail invalid (non-integer) cid" );
req( $test, 400, 'root', 'GET', "$base/jj" );

note( "fail non-existent cid" );
req( $test, 404, 'root', 'GET', "$base/444" );

note( "PUT on $base/:cid" );
$component_obj = '{ "path" : "FOOBAR", "source" : "The bar of foo", "acl" : "inactive" }';
# - test with demo fail 403
req( $test, 403, 'demo', 'PUT', "$base/$cid_of_foobar", $component_obj );

note( 'test with root success' );
$status = req( $test, 200, 'root', 'PUT', "$base/$cid_of_foobar", $component_obj );
is( $status->level, 'OK', "PUT $base/:cid 3" );
is( $status->code, 'DOCHAZKA_CUD_OK', "PUT $base/:cid 4" );
is( ref( $status->payload ), 'HASH', "PUT $base/:cid 5" );

note( 'make an component object out of the payload' );
$foobar = App::Dochazka::REST::Model::Component->spawn( $status->payload );
is( $foobar->source, "The bar of foo", "PUT $base/:cid 5" );
is( $foobar->acl, "inactive", "PUT $base/:cid 6" );

note( 'test with root no request body' );
req( $test, 400, 'root', 'PUT', "$base/$cid_of_foobar" );

note( 'test with root fail invalid JSON' );
req( $test, 400, 'root', 'PUT', "$base/$cid_of_foobar", '{ asdf' );

note( 'test with root fail invalid cid' );
req( $test, 400, 'root', 'PUT', "$base/asdf", '{ "legal":"json" }' );

note( 'with valid JSON that is not what we are expecting' );
req( $test, 400, 'root', 'PUT', "$base/$cid_of_foobar", '0' );

note( 'with valid JSON that has some bogus properties' );
req( $test, 400, 'root', 'PUT', "$base/$cid_of_foobar", '{ "legal":"json" }' );

note( "POST on $base/:cid" );
req( $test, 405, 'demo', 'POST', "$base/$cid_of_foobar" );
req( $test, 405, 'root', 'POST', "$base/$cid_of_foobar" );

note( "DELETE on $base/:cid" );

note( 'demo fail 403' );
req( $test, 403, 'demo', 'DELETE', "$base/$cid_of_foobar" );

note( 'root success' );
note( "DELETE $base/$cid_of_foobar" );
$status = req( $test, 200, 'root', 'DELETE', "$base/$cid_of_foobar" );
is( $status->level, 'OK', "DELETE $base/:cid 3" );
is( $status->code, 'DOCHAZKA_CUD_OK', "DELETE $base/:cid 4" );

note( 'really gone' );
req( $test, 404, 'root', 'GET', "$base/$cid_of_foobar" );

note( 'root fail invalid cid' );
req( $test, 400, 'root', 'DELETE', "$base/asd" );


note( "=============================" );
note( "'component/path' resource" );
note( "=============================" );
$base = 'component/path';
docu_check($test, "$base");

note( "GET, PUT on $base" );
req( $test, 405, 'demo', 'GET', $base );
req( $test, 405, 'active', 'GET', $base );
req( $test, 405, 'puppy', 'GET', $base );
req( $test, 405, 'root', 'GET', $base );
req( $test, 405, 'demo', 'PUT', $base );
req( $test, 405, 'active', 'PUT', $base );
req( $test, 405, 'puppy', 'GET', $base );
req( $test, 405, 'root', 'PUT', $base );

note( "POST on $base" );

note( "insert: expected behavior" );
$component_obj = '{ "path" : "FOOWANG", "source" : "wang wang wazoo", "acl" : "passerby" }';
req( $test, 403, 'demo', 'POST', $base, $component_obj );
$status = req( $test, 200, 'root', 'POST', $base, $component_obj );
is( $status->level, 'OK', "POST $base 4" );
is( $status->code, 'DOCHAZKA_CUD_OK', "POST $base 5" );
my $cid_of_foowang = $status->payload->{'cid'};

note( "update: expected behavior" );
$component_obj = '{ "path" : "FOOWANG", "source" : "this is only a test", "acl" : "inactive" }';
req( $test, 403, 'demo', 'POST', $base, $component_obj );
$status = req( $test, 200, 'root', 'POST', $base, $component_obj );
is( $status->level, 'OK', "POST $base 4" );
is( $status->code, 'DOCHAZKA_CUD_OK', "POST $base 5" );
is( $status->payload->{'source'}, 'this is only a test', "POST $base 6" );
is( $status->payload->{'acl'}, 'inactive', "POST $base 7" );

note( "throw a couple curve balls" );
$weirded_object = '{ "copious_turds" : 555, "source" : "wang wang wazoo", "disabled" : "f" }';
req( $test, 400, 'root', 'POST', $base, $weirded_object );

$no_closing_bracket = '{ "copious_turds" : 555, "source" : "wang wang wazoo", "disabled" : "f"';
req( $test, 400, 'root', 'POST', $base, $no_closing_bracket );

$weirded_object = '{ "path" : "!!!!!", "source" : "down it goes", "acl" : "inactive" }';
dbi_err( $test, 500, 'root', 'POST', $base, $weirded_object, qr/check constraint "kosher_path"/ );

note( "delete the testing component" );
delete_testing_component( $cid_of_foowang );

note( "DELETE on $base" );
foreach my $user ( qw( demo active puppy root ) ) {
    req( $test, 405, $user, 'DELETE', $base ); 
}


note( "=============================" );
note( "'component/path/:path' resource" );
note( "=============================" );
$base = 'component/path';
docu_check($test, "$base/:path");

note( 'insert an component' );
$foobar = create_testing_component( path => 'FOOBAR', source => 'bazblat', acl => 'passerby' );
$cid_of_foobar = $foobar->cid;

note( "GET on $base/:path" );

note( 'insufficient privlevel' );
req( $test, 403, 'demo', 'GET', "$base/FOOBAR" );

note( 'positive test for FOOBAR component' );
$status = req( $test, 200, 'root', 'GET', "$base/FOOBAR" );
is( $status->level, "OK", "GET $base/:path 2" );
is( $status->code, 'DISPATCH_COMPONENT_FOUND', "GET $base/:path 3" );
is_deeply( $status->payload, {
    cid => $cid_of_foobar,
    path => 'FOOBAR',
    source => 'bazblat',
    acl => 'passerby',
}, "GET $base/:path 4" );

note( 'non-existent path' );
req( $test, 404, 'root', 'GET', "$base/jj" );

note( 'invalid path' );
foreach my $invalid_path ( 
    '!!!! !134@@',
    'whiner*44',
    '@=1337',
    '/ninety/nine/luftbalons//',
) {
    foreach my $user ( qw( root demo ) ) {
        req( $test, 400, $user, 'GET', "$base/$invalid_path" );
    }
}

note( "PUT on $base/:path" );
$component_obj = '{ "path" : "FOOBAR", "source" : "Full of it", "acl" : "inactive" }';

note( 'demo fail 403' );
req( $test, 403, 'demo', 'PUT', "$base/FOOBAR", $component_obj );

note( 'root success' );
$status = req( $test, 200, 'root', 'PUT', "$base/FOOBAR", $component_obj );
is( $status->level, "OK", "PUT $base/:path 3" );
is( $status->code, 'DOCHAZKA_CUD_OK', "PUT $base/:path 4" );

note( 'positive test for FOOBAR component' );
$status = req( $test, 200, 'root', 'GET', "$base/FOOBAR" );
is( $status->level, "OK", "GET $base/:path 2" );
is( $status->code, 'DISPATCH_COMPONENT_FOUND', "GET $base/:path 3" );
is_deeply( $status->payload, {
    cid => $cid_of_foobar,
    path => 'FOOBAR',
    source => 'Full of it',
    acl => 'inactive',
}, "GET $base/:path 4" );

note( 'demo: no content body' );
req( $test, 403, 'demo', 'PUT', "$base/FOOBAR" );
req( $test, 403, 'demo', 'PUT', "$base/FOOBAR_NEW" );

note( 'root: no content body' );
req( $test, 400, 'root', 'PUT', "$base/FOOBAR" );

note( 'root: invalid JSON' );
req( $test, 400, 'root', 'PUT', "$base/FOOBAR", '{ asdf' );

note( 'root: invalid path' );
req( $test, 400, 'root', 'PUT', "$base/!!!!", '{ "legal":"json" }' );

note( 'root: valid JSON that is not what we are expecting' );
req( $test, 400, 'root', 'PUT', "$base/FOOBAR", '0' );
req( $test, 403, 'demo', 'PUT', "$base/FOOBAR_NEW", '0' );

note( 'root: update with combination of valid and invalid properties' );
$status = req( $test, 200, 'root', 'PUT', "$base/FOOBAR", 
    '{ "source":"Nothing much", "nick":"FOOBAR", "sister":123 }' );
is( $status->level, 'OK', "PUT $base/FOOBAR 21" );
is( $status->code, 'DOCHAZKA_CUD_OK', "PUT $base/FOOBAR 22" );
is( $status->payload->{'source'}, "Nothing much", "PUT $base/FOOBAR 23" );
ok( ! exists( $status->payload->{'nick'} ), "PUT $base/FOOBAR 24" );
ok( ! exists( $status->payload->{'sister'} ), "PUT $base/FOOBAR 25" );

note( 'root: insert with combination of valid and invalid properties' );
$status = req( $test, 200, 'root', 'PUT', "$base/FOOBARPUS", 
    '{ "nick":"FOOBAR", "source":"Nothing much", "sister":"willy\'s", "acl":"inactive" }' );
is( $status->level, 'OK', "PUT $base/FOOBAR 27" );
is( $status->code, 'DOCHAZKA_CUD_OK', "PUT $base/FOOBAR 28" );
is( $status->payload->{'path'}, "FOOBARPUS", "PUT $base/FOOBAR 29" );
is( $status->payload->{'source'}, "Nothing much", "PUT $base/FOOBAR 30" );
is( $status->payload->{'acl'}, "inactive", "PUT $base/FOOBAR 31" );
ok( ! exists( $status->payload->{'nick'} ), "PUT $base/FOOBAR 32" );
ok( ! exists( $status->payload->{'sister'} ), "PUT $base/FOOBAR 33" );

note( "POST on $base/:path" );
req( $test, 405, 'demo', 'POST', "$base/FOOBAR" );
req( $test, 405, 'active', 'POST', "$base/FOOBAR" );
req( $test, 405, 'puppy', 'POST', "$base/FOOBAR" );
req( $test, 405, 'root', 'POST', "$base/FOOBAR" );

note( "DELETE on $base/:path" );

note( 'demo fail 403 once' );
req( $test, 403, 'demo', 'DELETE', "$base/FOOBAR1" );

note( 'root fail 404' );
req( $test, 404, 'root', 'DELETE', "$base/FOOBAR1" );

note( 'demo fail 403 a second time' );
req( $test, 403, 'demo', 'DELETE', "$base/FOOBAR" );

note( "root success: DELETE $base/FOOBAR" );
$status = req( $test, 200, 'root', 'DELETE', "$base/FOOBAR" );
is( $status->level, 'OK', "DELETE $base/FOOBAR 3" );
is( $status->code, 'DOCHAZKA_CUD_OK', "DELETE $base/FOOBAR 4" );

note( "really gone" );
req( $test, 404, 'root', 'GET', "$base/FOOBAR" );

note( "root: fail invalid path" );
req( $test, 400, 'root', 'DELETE', "$base/!!!" );

note( "delete FOOBARPUS, too" );
$status = req( $test, 200, 'root', 'DELETE', "$base/FOOBARPUS" );
is( $status->level, 'OK', "DELETE $base/FOOBARPUS 2" );
is( $status->code, 'DOCHAZKA_CUD_OK', "DELETE $base/FOOBARPUS 3" );

done_testing;
