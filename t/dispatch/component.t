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


note( '=============================' );
note( '"component/all" resource' );
note( '=============================' );
my $base = 'component/all';
docu_check($test, $base);

note( 'insert an component' );
my $foobar = create_testing_component( 
    path => 'FOOBAR', 
    source => 'source code of FOOBAR', 
    acl => 'passerby' 
);
my $cid_of_foobar = $foobar->cid;

note( "GET on $base" );
req( $test, 403, 'demo', 'GET', $base );
my $status = req( $test, 200, 'root', 'GET', $base );
is( $status->level, 'OK', "GET $base 2" );
is( $status->code, 'DISPATCH_RECORDS_FOUND', "GET $base 3" );
is( $status->{count}, 2, "GET $base 4" );
ok( exists $status->{payload}, "GET $base 5" );
is( scalar @{ $status->payload }, 2, "GET $base 6" );

note( 'testing component is present' );
ok( scalar( grep { $_->{path} eq 'FOOBAR'; } @{ $status->payload } ), "GET $base 7" );

note( 'delete the testing component' );
delete_testing_component( $cid_of_foobar );

note( "PUT, POST, DELETE on $base" );
req( $test, 405, 'demo', 'PUT', $base );
req( $test, 405, 'active', 'PUT', $base );
req( $test, 405, 'piggy', 'PUT', $base );
req( $test, 405, 'root', 'PUT', $base );
req( $test, 405, 'demo', 'POST', $base );
req( $test, 405, 'active', 'POST', $base );
req( $test, 405, 'piggy', 'PUT', $base );
req( $test, 405, 'root', 'POST', $base );
req( $test, 405, 'demo', 'DELETE', $base );
req( $test, 405, 'active', 'DELETE', $base );
req( $test, 405, 'piggy', 'PUT', $base );
req( $test, 405, 'root', 'DELETE', $base );


note( '========================' );
note( '"component/cid" resource' );
note( '========================' );
$base = 'component/cid';
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
$status = req( $test, 200, 'root', 'POST', $base, $component_obj );
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
$foobar = create_testing_component( path => 'FOOBAR', source => 'wombat', acl => 'passerby' );
$cid_of_foobar = $foobar->cid;

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

done_testing;
