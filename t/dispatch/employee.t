# ************************************************************************* # Copyright (c) 2014-2015, SUSE LLC
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
# test employee resources
#

#!perl
use 5.012;
use strict;
use warnings FATAL => 'all';
use utf8;

use App::CELL qw( $log $meta $site );
use App::Dochazka::REST::ConnBank qw( $dbix_conn );
use App::Dochazka::REST::Test;
use Data::Dumper;
use JSON;
use Plack::Test;
use Test::JSON;
use Test::More;

# initialize 
my $status = initialize_unit();
plan skip_all => "not configured or server not running" unless $status->ok;
my $app = $status->payload;

# instantiate Plack::Test object
my $test = Plack::Test->create( $app );
isa_ok( $test, 'Plack::Test::MockHTTP' );

my $res;


#=============================
# "employee/count/?:priv" resource
#=============================
my $base = 'employee/count';
docu_check($test, "$base/?:priv");
#
# GET employee/count
#
# - fail 403 as demo
$status = req( $test, 403, 'demo', 'GET', $base );
#
# - succeed as root
$status = req( $test, 200, 'root', 'GET', $base );
is( $status->level, 'OK', "GET $base 2" );
is( $status->code, 'DISPATCH_COUNT_EMPLOYEES', "GET $base 3" );

#
# PUT, POST, DELETE
#
# - fail 405 in all cases
$status = req( $test, 405, 'demo', 'PUT', $base );
$status = req( $test, 405, 'active', 'PUT', $base );
$status = req( $test, 405, 'WOMBAT', 'PUT', $base );
$status = req( $test, 405, 'root', 'PUT', $base );
$status = req( $test, 405, 'demo', 'POST', $base );
$status = req( $test, 405, 'active', 'POST', $base );
$status = req( $test, 405, 'root', 'POST', $base );
$status = req( $test, 405, 'demo', 'DELETE', $base );
$status = req( $test, 405, 'active', 'DELETE', $base );
$status = req( $test, 405, 'root', 'DELETE', $base );


#
# GET
#
# - valid priv strings
foreach my $priv ( qw( 
    passerby
    PASSERBY
    paSsERby
    inactive
    INACTIVE
    inAcTive
    active
    ACTIVE
    actIVe
    admin
    ADMIN
    AdmiN
) ) {
    #diag( "$base/$priv" );
    $status = req( $test, 200, 'root', 'GET', "$base/$priv" );
    is( $status->level, "OK", "GET $base/:priv 2" );
    if( $status->code ne 'DISPATCH_COUNT_EMPLOYEES' ) {
        diag( Dumper $status );
        BAIL_OUT(0);
    }
    is( $status->code, 'DISPATCH_COUNT_EMPLOYEES', "GET $base/:priv 3" );
    ok( defined $status->payload, "GET $base/:priv 4" );
    ok( exists $status->payload->{'priv'}, "GET $base/:priv 5" );
    is( $status->payload->{'priv'}, lc $priv, "GET $base/:priv 6" );
    ok( exists $status->payload->{'count'}, "GET $base/:priv 7" );
    #
    req( $test, 403, 'demo', 'GET', "$base/$priv" );
}
#
# - invalid priv strings
foreach my $priv (
    'nanaan',
    '%^%#$#',
    'Žluťoucký kǔň',
    '      dfdf fifty-five sixty-five',
    'passerbies',
    '///adfd/asdf/asdf',
) {
    req( $test, 400, 'root', 'GET', "$base/$priv" );
    req( $test, 400, 'demo', 'GET', "$base/$priv" );
}

#
# PUT, POST, DELETE
#
# - fail 405 in all cases
$base .= '/admin';
$status = req( $test, 405, 'demo', 'PUT', $base );
$status = req( $test, 405, 'active', 'PUT', $base );
$status = req( $test, 405, 'root', 'PUT', $base );
$status = req( $test, 405, 'demo', 'POST', $base );
$status = req( $test, 405, 'active', 'POST', $base );
$status = req( $test, 405, 'root', 'POST', $base );
$status = req( $test, 405, 'demo', 'DELETE', $base );
$status = req( $test, 405, 'active', 'DELETE', $base );
$status = req( $test, 405, 'root', 'DELETE', $base );


#=============================
# "employee/current" resource
# "employee/self" resource
#=============================

my $ts_eid_inactive = create_inactive_employee( $test );
my $ts_eid_active = create_active_employee( $test );

foreach my $base ( "employee/current", "employee/self" ) {
    docu_check($test, $base);
    #
    # GET employee/current
    #
    $status = req( $test, 200, 'demo', 'GET', $base );
    is( $status->level, 'OK' );
    is( $status->code, 'DISPATCH_EMPLOYEE_CURRENT', "GET $base 3" );
    ok( defined $status->payload, "GET $base 4" );
    is_deeply( $status->payload, {
        'eid' => 2,
        'sec_id' => undef,
        'nick' => 'demo',
        'fullname' => 'Demo Employee',
        'email' => 'demo@dochazka.site',
        'passhash' => '4962cc89c646261a887219795083a02b899ea960cd84a234444b7342e2222eb22dc06f5db9c71681074859469fdc0abd53e3f1f47a381617b59f4b31608e24b1',
        'salt' => '82702be8d9810d8fba774dcb7c9f68f39d0933e8',
        'supervisor' => undef,
        'remark' => 'dbinit',
    }, "GET $base 5");
    #
    $status = req( $test, 200, 'root', 'GET', $base );
    is( $status->level, 'OK' );
    is( $status->code, 'DISPATCH_EMPLOYEE_CURRENT', "GET $base 8" );
    ok( defined $status->payload, "GET $base 9" );
    is_deeply( $status->payload, {
        'eid' => 1,
        'sec_id' => undef,
        'nick' => 'root',
        'fullname' => 'Root Immutable',
        'email' => 'root@site.org',
        'passhash' => '82100e9bd4757883b4627b3bafc9389663e7be7f76a1273508a7a617c9dcd917428a7c44c6089477c8e1d13e924343051563d2d426617b695f3a3bff74e7c003',
        'salt' => '341755e03e1f163f829785d1d19eab9dee5135c0',
        'supervisor' => undef,
        'remark' => 'dbinit',
    }, "GET $base 10" );
    
    #
    # PUT
    #
    $status = req( $test, 405, 'demo', 'PUT', $base );
    $status = req( $test, 405, 'active', 'PUT', $base );
    $status = req( $test, 405, 'root', 'PUT', $base );
    
    #
    # POST
    #
    # - default configuration is that 'active' and 'inactive' can modify their own passhash and salt fields
    # - demo should *not* be authorized to do this
    req( $test, 403, 'demo', 'POST', $base, '{ "password":"saltine" }' );
    foreach my $user ( "active", "inactive" ) {
        #
        #diag( "$user $base " . '{ "password" : "saltine" }' );
        $status = req( $test, 200, $user, 'POST', $base, '{ "password" : "saltine" }' );
        if ( $status->not_ok ) {
            diag( Dumper $status );
            BAIL_OUT(0);
        }
        is( $status->level, 'OK' );
        is( $status->code, 'DOCHAZKA_CUD_OK' ); 
        #
        # - use root to change it back, otherwise the user won't be able to log in and next tests will fail
        $status = req( $test, 200, 'root', 'PUT', "employee/nick/$user", "{ \"password\" : \"$user\" }" );
        is( $status->level, 'OK' );
        is( $status->code, 'DOCHAZKA_CUD_OK' ); 
        #
        # - negative test
        req( $test, 400, $user, 'POST', $base, 0 );
        #
        # - 'salt' is a permitted field, but 'inactive'/$user employees
        # should not, for example, be allowed to change 'nick'
        req( $test, 403, $user, 'POST', $base, '{ "nick": "wanger" }' );
        #
        ## - nor should they be able to change 'email'
        #req( $test, 403, $user, 'POST', $base, '{ "email": "5000thbat@cave.com" }' );
    }
    #
    # root can theoretically update any field, but certain fields of its own
    # profile are immutable
    #
    $status = req( $test, 200, 'root', 'POST', $base, '{ "email": "root@rotoroot.com" }' );
    is( $status->level, 'OK' );
    is( $status->code, 'DOCHAZKA_CUD_OK' );
    #
    $status = req( $test, 200, 'root', 'POST', $base, '{ "email": "root@site.org" }' );
    is( $status->level, 'OK' );
    is( $status->code, 'DOCHAZKA_CUD_OK' );
    #
    dbi_err( $test, 500, 'root', 'POST', $base, '{ "nick": "aaaaazz" }', qr/root employee is immutable/ );
    #

    #
    # DELETE
    #
    $status = req( $test, 405, 'demo', 'DELETE', $base );
    $status = req( $test, 405, 'active', 'DELETE', $base );
    $status = req( $test, 405, 'root', 'DELETE', $base );
}


#=============================
# "employee/current/priv" resource
# "employee/self/priv" resource
#=============================
foreach my $base ( "employee/current/priv", "employee/self/priv" ) {
    docu_check($test, "employee/current/priv");
    #
    # GET employee/current/priv
    #
    $status = req( $test, 200, 'demo', 'GET', $base );
    is( $status->level, 'OK' );
    is( $status->code, 'DISPATCH_EMPLOYEE_CURRENT_PRIV' );
    ok( defined $status->payload );
    ok( exists $status->payload->{'priv'} );
    ok( exists $status->payload->{'schedule'} );
    ok( exists $status->payload->{'current_emp'} );
    is( $status->payload->{'current_emp'}->{'nick'}, 'demo' );
    is( $status->payload->{'priv'}, 'passerby' );
    is( $status->payload->{'schedule'}, undef );
    #
    $status = req( $test, 200, 'root', 'GET', $base );
    is( $status->level, 'OK' );
    is( $status->code, 'DISPATCH_EMPLOYEE_CURRENT_PRIV' );
    ok( defined $status->payload );
    ok( exists $status->payload->{'priv'} );
    ok( exists $status->payload->{'schedule'} );
    ok( exists $status->payload->{'current_emp'} );
    is( $status->payload->{'current_emp'}->{'nick'}, 'root' );
    is( $status->payload->{'priv'}, 'admin' );
    is( $status->payload->{'schedule'}, undef );
    
    #
    # PUT, POST, DELETE
    #
    $status = req( $test, 405, 'demo', 'PUT', $base );
    $status = req( $test, 405, 'active', 'PUT', $base );
    $status = req( $test, 405, 'root', 'PUT', $base );
    $status = req( $test, 405, 'demo', 'POST', $base );
    $status = req( $test, 405, 'active', 'POST', $base );
    $status = req( $test, 405, 'root', 'POST', $base );
    $status = req( $test, 405, 'demo', 'DELETE', $base );
    $status = req( $test, 405, 'active', 'DELETE', $base );
    $status = req( $test, 405, 'root', 'DELETE', $base );
}
    
    
note( '=============================' );
note( '"employee/eid" resource' );
note( '=============================' );
$base = "employee/eid";
note( "docu_check on $base" );
docu_check($test, "employee/eid");

note( "GET, PUT" );
$status = req( $test, 405, 'demo', 'GET', $base );
$status = req( $test, 405, 'active', 'GET', $base );
$status = req( $test, 405, 'root', 'GET', $base );
$status = req( $test, 405, 'demo', 'PUT', $base );
$status = req( $test, 405, 'active', 'PUT', $base );
$status = req( $test, 405, 'root', 'PUT', $base );

note( "POST" );

note( "create a 'mrfu' employee" );
my $mrfu = create_testing_employee( { nick => 'mrfu', password => 'mrfu' } );
my $eid_of_mrfu = $mrfu->eid;

# these tests break when 'email' is added to DOCHAZKA_PROFILE_EDITABLE_FIELDS
## - give Mr. Fu an email address
##req( $test, 403, 'demo', 'POST', $base, '{ "eid": ' . $mrfu->eid . ', "email" : "shake it" }' );
# 
##is( $mrfu->nick, 'mrfu' );
##req( $test, 403, 'mrfu', 'POST', $base, '{ "eid": ' . $mrfu->eid . ', "email" : "shake it" }' );
# fails because mrfu is a passerby

note( "make mrfu an inactive" );
$status = req( $test, 201, 'root', 'POST', "priv/history/eid/" . $mrfu->eid, <<"EOH" );
{ "priv" : "inactive", "effective" : "2004-01-01" }
EOH
is( $status->level, "OK", 'POST employee/eid 3' );
is( $status->code, "DOCHAZKA_CUD_OK", 'POST employee/eid 3' );
ok( exists $status->payload->{'phid'} );
my $mrfu_phid = $status->payload->{'phid'};

# these tests break when 'email' is added to DOCHAZKA_PROFILE_EDITABLE_FIELDS
## - try the operation again - it still fails because inactives can not change their email
##req( $test, 403, 'mrfu', 'POST', $base, '{ "eid": ' . $mrfu->eid . ', "email" : "shake it" }' );

note( "inactive mrfu can change his password" );
$status = req( $test, 200, 'mrfu', 'POST', $base, '{ "eid": ' . $mrfu->eid . ', "password" : "shake it" }' );
is( $status->level, "OK", 'POST employee/eid 3' );
is( $status->code, 'DOCHAZKA_CUD_OK', 'POST employee/eid 4' );

note( "but now mrfu cannot log in, because req assumes password is 'mrfu'" );
req( $test, 401, 'mrfu', 'GET', 'employee/nick/mrfu' );

note( "so, use root powers to change the password back" );
$eid_of_mrfu = $mrfu->eid;
$status = req( $test, 200, 'root', 'POST', $base, <<"EOH" );
{ "eid" : $eid_of_mrfu, "password" : "mrfu" }
EOH
is( $status->level, "OK", 'POST employee/eid 3' );
is( $status->code, "DOCHAZKA_CUD_OK", 'POST employee/eid 3' );

note( "and now mrfu can log in" );
$status = req( $test, 200, 'mrfu', 'GET', 'employee/nick/mrfu' );
is( $status->level, "OK", 'POST employee/eid 3' );
is( $status->payload->{'remark'}, undef );
is( $status->payload->{'sec_id'}, undef );
is( $status->payload->{'nick'}, 'mrfu' );
is( $status->payload->{'email'}, undef );
is( $status->payload->{'fullname'}, undef );

note( "attempt by demo to update mrfu to a different nick" );
#diag("--- POST employee/eid (update with different nick)");
req( $test, 403, 'demo', 'POST', $base, '{ "eid": ' . $mrfu->eid . ', "nick" : "mrsfu" , "fullname":"Dragoness" }' );

note( "use root power to update mrfu to a different nick" ); 
$status = req( $test, 200, 'root', 'POST', $base, '{ "eid": ' . $mrfu->eid . ', "nick" : "mrsfu" , "fullname":"Dragoness" }' );
is( $status->level, 'OK', 'POST employee/eid 8' );
is( $status->code, 'DOCHAZKA_CUD_OK', 'POST employee/eid 9' );
my $mrsfu = App::Dochazka::REST::Model::Employee->spawn( %{ $status->payload } );
my $mrsfuprime = App::Dochazka::REST::Model::Employee->spawn( eid => $mrfu->eid,
    nick => 'mrsfu', fullname => 'Dragoness' );
is( $mrsfu->eid, $mrsfuprime->eid, 'POST employee/eid 10' );
is( $mrsfu->nick, $mrsfuprime->nick, 'POST employee/eid 10' );
is( $mrsfu->fullname, $mrsfuprime->fullname, 'POST employee/eid 10' );
is( $mrsfu->email, $mrsfuprime->email, 'POST employee/eid 10' );
is( $mrsfu->remark, $mrsfuprime->remark, 'POST employee/eid 10' );

note( "attempt as demo and root to update Mr./Mrs. Fu to a non-existent EID" );
#diag("--- POST employee/eid (non-existent EID)");
req( $test, 403, 'demo', 'POST', $base, '{ "eid" : 5442' );
req( $test, 400, 'root', 'POST', $base, '{ "eid" : 5442' );
req( $test, 403, 'demo', 'POST', $base, '{ "eid" : 5442 }' );
req( $test, 404, 'root', 'POST', $base, '{ "eid" : 5442 }' );
req( $test, 404, 'root', 'POST', $base, '{ "eid": 534, "nick": "mrfu", "fullname":"Lizard Scale" }' );

# - missing EID
req( $test, 400, 'root', 'POST', $base, '{ "long-john": "silber" }' );
#
# - incorrigibly attempt to update totally bogus and invalid EIDs
req( $test, 400, 'root', 'POST', $base, '{ "eid" : }' );
req( $test, 400, 'root', 'POST', $base, '{ "eid" : jj }' );
$status = req( $test, 500, 'root', 'POST', $base, '{ "eid" : "jj" }' );
like( $status->text, qr/invalid input syntax for integer/ );
#
# - and give it a bogus parameter (on update, bogus parameters cause REST to
#   vomit 400; on insert, they are ignored)
req( $test, 400, 'root', 'POST', $base, '{ "eid" : 2, "bogus" : "json" }' ); 
#
# - update to existing nick
dbi_err( $test, 500, 'root', 'POST', $base, 
    '{ "eid": ' . $mrfu->eid . ', "nick" : "root" , "fullname":"Tom Wang" }',
    qr/Key \(nick\)=\(root\) already exists/ );
#
# - update nick to null
dbi_err( $test, 500, 'root', 'POST', $base, 
    '{ "eid": ' . $mrfu->eid . ', "nick" : null  }',
    qr/null value in column "nick" violates not-null constraint/ );
# 
# - inactive and active users get a little piece of the action, too:
#   they can operate on themselves (certain fields), but not on, e.g., Mr. Fu
foreach my $user ( qw( demo inactive active ) ) {
    req( $test, 403, $user, 'POST', $base, <<"EOH" );
{ "eid" : $eid_of_mrfu, "passhash" : "HAHAHAHA" }
EOH
}
foreach my $user ( qw( demo inactive active ) ) {
    $status = req( $test, 200, 'root', 'GET', "employee/nick/$user" );
    is( $status->level, 'OK' );
    is( $status->code, 'DISPATCH_EMPLOYEE_FOUND' );
    is( ref( $status->payload ), 'HASH' );
    my $eid = $status->payload->{'eid'};
    req( $test, 403, $user, 'POST', $base, <<"EOH" );
{ "eid" : $eid, "nick" : "tHE gREAT fABULATOR" }
EOH
}
foreach my $user ( qw( inactive active ) ) {
    $status = req( $test, 200, 'root', 'GET', "employee/nick/$user" );
    is( $status->level, 'OK' );
    is( $status->code, 'DISPATCH_EMPLOYEE_FOUND' );
    is( ref( $status->payload ), 'HASH' );
    my $eid = $status->payload->{'eid'};
    $status = req( $test, 200, $user, 'POST', $base, <<"EOH" );
{ "eid" : $eid, "password" : "tHE gREAT fABULATOR" }
EOH
    is( $status->level, 'OK' );
    is( $status->code, 'DOCHAZKA_CUD_OK' );
    # 
    # - can no longer log in because Test.pm expects password to be same as $user
    req( $test, 401, $user, 'GET', "employee/nick/$user" );
    #
    # - use root power to change password back 
    $status = req( $test, 200, 'root', 'POST', $base, <<"EOH" );
{ "eid" : $eid, "password" : "$user" }
EOH
    is( $status->level, 'OK' );
    is( $status->code, 'DOCHAZKA_CUD_OK' );
}



# delete the testing user
# 1. first delete his privhistory entry
$status = req( $test, 200, 'root', 'DELETE', "priv/history/phid/$mrfu_phid" );
ok( $status->ok );
delete_testing_employee( $eid_of_mrfu );

#
# DELETE 
#
req( $test, 405, 'demo', 'DELETE', $base );
req( $test, 405, 'active', 'DELETE', $base );
req( $test, 405, 'root', 'DELETE', $base );


#=============================
# "employee/eid/:eid" resource
#=============================
$base = 'employee/eid';
docu_check($test, "$base/:eid");

my @invalid_eids = (
    '342j',
    '**12',
    'fenestre',
    '1234/123/124/',
);

#
# GET
#
#
# - normal usage: get employee with nick [0], eid [2], fullname [3] as employee
#   with nick [1]
foreach my $params (
    [ 'root', 'root', $site->DOCHAZKA_EID_OF_ROOT, 'Root Immutable' ],
    [ 'demo', 'root', 2, 'Demo Employee' ],
    [ 'active', 'root', $ts_eid_active, undef ],
    [ 'active', 'active', $ts_eid_active, undef ],
    [ 'inactive', 'root', $ts_eid_inactive, undef ],
) {
    $status = req( $test, 200, $params->[1], 'GET', "$base/" . $params->[2] );
    is( $status->level, 'OK' );
    is( $status->code, 'DISPATCH_EMPLOYEE_FOUND' );
    ok( defined $status->payload );
    ok( exists $status->payload->{'eid'} );
    is( $status->payload->{'eid'}, $params->[2] );
    ok( exists $status->payload->{'nick'} );
    is( $status->payload->{'nick'}, $params->[0] );
    ok( exists $status->payload->{'fullname'} );
    is( $status->payload->{'fullname'}, $params->[3] );
}
# 
req( $test, 200, 'demo', 'GET', "$base/2" );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_EMPLOYEE_FOUND' );
#
req( $test, 404, 'root', 'GET', "$base/53432" );
#
req( $test, 403, 'demo', 'GET', "$base/53432" );
#
# - invalid EIDs caught by Path::Router validations clause
foreach my $eid ( @invalid_eids ) {
    foreach my $user ( qw( root demo ) ) {
        req( $test, 400, $user, 'GET', "$base/$eid" );
    }
}
#
# as demonstrated above, an active employee can see his own profile using this
# resource -- demonstrate it again
$status = req( $test, 200, 'active', 'GET', "$base/$ts_eid_active" );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_EMPLOYEE_FOUND' );
#
# an 'inactive' employee can do the same
$status = req( $test, 200, 'inactive', 'GET', "$base/$ts_eid_inactive" );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_EMPLOYEE_FOUND' );
#
# and demo as well
req( $test, 200, 'demo', 'GET', "$base/2" );  # EID 2 is 'demo'
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_EMPLOYEE_FOUND' );
#
# or for unknown users
req( $test, 401, 'unknown', 'GET', "$base/2" );  # EID 2 is 'demo'
#
# and non-administrators cannot use this resource to look at other employees
foreach my $user ( qw( active inactive demo ) ) {
    my $status = req( $test, 403, $user, 'GET', "$base/1" );
}

#
# PUT employee/eid/:eid
#
# create a testing employee by cheating a little
my $emp = create_testing_employee( {
    nick => 'brotherchen',
    email => 'goodbrother@orient.cn',
    fullname => 'Good Brother Chen',
} );
my $eid_of_brchen = $emp->{eid};
is( $eid_of_brchen, $emp->eid );
#
# - insufficient priv
req( $test, 403, 'demo', 'PUT', "$base/$eid_of_brchen",
    '{ "eid": ' . $eid_of_brchen . ', "fullname":"Chen Update Again" }' );
#
# - be nice
req( $test, 403, 'demo', 'PUT', "$base/$eid_of_brchen",
    '{ "fullname":"Chen Update Again", "salt":"tasty" }' );
$status = req( $test, 200, 'root', 'PUT', "$base/$eid_of_brchen",
    '{ "fullname":"Chen Update Again", "salt":"tasty" }' );
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_CUD_OK' );
my $brchen = App::Dochazka::REST::Model::Employee->spawn( %{ $status->payload } );
is( $brchen->eid, $eid_of_brchen );
my $brchenprime = App::Dochazka::REST::Model::Employee->spawn( eid => $eid_of_brchen,
    nick => 'brotherchen', email => 'goodbrother@orient.cn', fullname =>
    'Chen Update Again', salt => 'tasty' );
is_deeply( $brchen, $brchenprime );
# 
# - provide invalid EID in request body -> it will be ignored
$status = req( $test, 200, 'root', 'PUT', "$base/$eid_of_brchen",
    '{ "eid": 99999, "fullname":"Chen Update Again 2" }' );
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_CUD_OK' );
$brchen = App::Dochazka::REST::Model::Employee->spawn( %{ $status->payload } );
isnt( $brchen->eid, 99999 );
is( $brchen->eid, $eid_of_brchen );
$brchenprime = App::Dochazka::REST::Model::Employee->spawn( eid => $eid_of_brchen,
    nick => 'brotherchen', email => 'goodbrother@orient.cn', fullname =>
    'Chen Update Again 2', salt => 'tasty' );
is_deeply( $brchen, $brchenprime );
#
# - change the nick
req( $test, 403, 'demo', 'PUT', "$base/$eid_of_brchen", '{' );
req( $test, 400, 'root', 'PUT', "$base/$eid_of_brchen", '{' );
req( $test, 403, 'demo', 'PUT', "$base/$eid_of_brchen", '{ "nick": "mrfu", "fullname":"Lizard Scale" }' );
$status = req( $test, 200, 'root', 'PUT', "$base/$eid_of_brchen",
    '{ "nick": "mrfu", "fullname":"Lizard Scale", "email":"mrfu@dragon.cn" }' );
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_CUD_OK' );
$mrfu = App::Dochazka::REST::Model::Employee->spawn( %{ $status->payload } );
isnt( $mrfu->nick, 'brotherchen' );
is( $mrfu->nick, 'mrfu' );
my $mrfuprime = App::Dochazka::REST::Model::Employee->spawn( eid => $eid_of_brchen,
    nick => 'mrfu', fullname => 'Lizard Scale', email => 'mrfu@dragon.cn',
    salt => 'tasty' );
is_deeply( $mrfu, $mrfuprime );
$eid_of_mrfu = $mrfu->eid;
is( $eid_of_mrfu, $eid_of_brchen );
#
# - provide non-existent EID
req( $test, 403, 'demo', 'PUT', "$base/5633", '{' );
req( $test, 404, 'root', 'PUT', "$base/5633", '{' );
req( $test, 403, 'demo', 'PUT', "$base/5633",
    '{ "nick": "mrfu", "fullname":"Lizard Scale" }' );
req( $test, 404, 'root', 'PUT', "$base/5633",
    '{ "eid": 534, "nick": "mrfu", "fullname":"Lizard Scale" }' );
#
# - with valid JSON that is not what we are expecting
req( $test, 400, 'root', 'PUT', "$base/2", 0 );
# - another kind of bogus JSON
req( $test, 400, 'root', 'PUT', "$base/2", '{ "legal" : "json" }' );
#
# - invalid EIDs caught by Path::Router validations clause
foreach my $eid ( @invalid_eids ) {
    foreach my $user ( qw( root demo ) ) {
        req( $test, 400, $user, 'PUT', "$base/$eid" );
    }
}

# 
# - inactive and active users get a little piece of the action, too:
#   they can operate on themselves (certain fields), but not on, e.g., Mr. Fu
foreach my $user ( qw( demo inactive active ) ) {
    req( $test, 403, $user, 'PUT', "$base/$eid_of_mrfu", <<"EOH" );
{ "passhash" : "HAHAHAHA" }
EOH
}
foreach my $user ( qw( demo inactive active ) ) {
    $status = req( $test, 200, 'root', 'GET', "employee/nick/$user" );
    is( $status->level, 'OK' );
    is( $status->code, 'DISPATCH_EMPLOYEE_FOUND' );
    is( ref( $status->payload ), 'HASH' );
    my $eid = $status->payload->{'eid'};
    req( $test, 403, $user, 'PUT', "$base/$eid", <<"EOH" );
{ "nick" : "tHE gREAT fABULATOR" }
EOH
}
foreach my $user ( qw( inactive active ) ) {
    $status = req( $test, 200, 'root', 'GET', "employee/nick/$user" );
    is( $status->level, 'OK' );
    is( $status->code, 'DISPATCH_EMPLOYEE_FOUND' );
    is( ref( $status->payload ), 'HASH' );
    my $eid = $status->payload->{'eid'};
    $status = req( $test, 200, $user, 'PUT', "$base/$eid", <<"EOH" );
{ "password" : "tHE gREAT fABULATOR" }
EOH
    is( $status->level, 'OK' );
    is( $status->code, 'DOCHAZKA_CUD_OK' );
    #
    # - so far so good, but now we can't log in because Test.pm assumes password is $user
    req( $test, 401, $user, 'GET', "$base/$eid" );
    #
    # - change it back
    $status = req( $test, 200, 'root', 'PUT', "$base/$eid", "{ \"password\" : \"$user\" }" );
    is( $status->level, 'OK' );
    is( $status->code, 'DOCHAZKA_CUD_OK' );
    #
    $status = req( $test, 200, 'root', 'GET', "employee/nick/$user" );
    is( $status->level, 'OK' );
    is( $status->code, 'DISPATCH_EMPLOYEE_FOUND' );
    is( ref( $status->payload ), 'HASH' );
}


#
# delete the testing user
delete_testing_employee( $eid_of_brchen );

#
# POST employee/eid/:eid
#
req( $test, 405, 'demo', 'POST', "$base/2" );
req( $test, 405, 'active', 'POST', "$base/2" );
req( $test, 405, 'root', 'POST', "$base/2" );

#
# DELETE employee/eid/:eid
#
note( 'create a "cannon fodder" employee' );
my $cf = create_testing_employee( { nick => 'cannonfodder' } );
my $eid_of_cf = $cf->eid;

note( 'employee/eid/:eid - delete cannonfodder' );
req( $test, 403, 'demo', 'DELETE', "$base/$eid_of_cf" );
req( $test, 403, 'active', 'DELETE', "$base/$eid_of_cf" ); 
req( $test, 401, 'unknown', 'DELETE', "$base/$eid_of_cf" ); # 401 because 'unknown' doesn't exist
$status = req( $test, 200, 'root', 'DELETE', "$base/$eid_of_cf" );
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_CUD_OK' );

note( 'attempt to get cannonfodder - not there anymore' );
req( $test, 403, 'demo', 'GET', "$base/$eid_of_cf" );
req( $test, 404, 'root', 'GET', "$base/$eid_of_cf" );

note( 'create another "cannon fodder" employee' );
$cf = create_testing_employee( { nick => 'cannonfodder' } );
ok( $cf->eid > $eid_of_cf ); # EID will have incremented
$eid_of_cf = $cf->eid;

note( 'delete the sucker' );
req( $test, 403, 'demo', 'DELETE', '/employee/nick/cannonfodder' );
$status = req( $test, 200, 'root', 'DELETE', '/employee/nick/cannonfodder' );
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_CUD_OK' );

note( 'attempt to get cannonfodder - not there anymore' );
req( $test, 403, 'demo', 'GET',  "$base/$eid_of_cf" );
req( $test, 404, 'root', 'GET',  "$base/$eid_of_cf" );

note( 'attempt to delete "root the immutable" (won\'t work)' );
dbi_err( $test, 500, 'root', 'DELETE', "$base/1", undef, qr/immutable/i );

note( 'invalid EIDs caught by Path::Router validations clause' );
foreach my $eid ( @invalid_eids ) {
    foreach my $user ( qw( root demo ) ) {
        req( $test, 400, $user, 'GET', "$base/$eid" );
    }
}


#=============================
# "employee/eid/:eid/minimal" resource
#=============================
$base = 'employee/eid';
docu_check($test, "$base/:eid/minimal");

note( 'root attempt to get non-existent EID (minimal)' );
req( $test, 404, 'root', 'GET', "$base/53432/minimal" );

note( 'demo attempt to get non-existent EID (minimal)' );
req( $test, 403, 'demo', 'GET', "$base/53432/minimal" );

note( 'demo attempt to get existent EID (minimal)' );
req( $test, 403, 'demo', 'GET', "$base/" . $site->DOCHAZKA_EID_OF_ROOT . "/minimal" );

note( 'root get active (minimal)' );
$status = req( $test, 200, 'root', 'GET', "$base/$ts_eid_active/minimal" );
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_EMPLOYEE_MINIMAL' );
ok( $status->payload );
is( ref( $status->payload ), 'HASH' );
ok( $status->payload->{'nick'} );
is( $status->payload->{'nick'}, 'active' );
is( $status->payload->{'eid'}, $ts_eid_active );
is( join( '', sort( keys( %{ $status->payload } ) ) ),
    join( '', sort( @{ $site->DOCHAZKA_EMPLOYEE_MINIMAL_FIELDS } ) ) );

#=============================
# "employee/eid/:eid/team" resource
#=============================
$base = "employee/eid";
docu_check($test, "$base/:eid/team" );
# 


#=============================
# "employee/list/?:priv" resource
#=============================
$base = "employee/list";
docu_check($test, "employee/list/?:priv");
#
# GET employee/list/?:priv
#
req( $test, 403, 'demo', 'GET', $base );
$status = req( $test, 200, 'root', 'GET', $base );
test_employee_list( $status, [ 'active', 'demo', 'inactive', 'root' ] );
$status = req( $test, 200, 'root', 'GET', "$base/admin" );
test_employee_list( $status, [ 'root' ] );
$status = req( $test, 200, 'root', 'GET', "$base/active" );
test_employee_list( $status, [ 'active' ] );
$status = req( $test, 200, 'root', 'GET', "$base/inactive" );
test_employee_list( $status, [ 'inactive' ] );
$status = req( $test, 200, 'root', 'GET', "$base/passerby" );
test_employee_list( $status, [ 'demo' ] );

#
# PUT, POST, DELETE employee/list/?:priv
#
req( $test, 405, 'demo', 'PUT', $base );
req( $test, 405, 'root', 'PUT', $base );
req( $test, 405, 'demo', 'POST', $base );
req( $test, 405, 'root', 'POST', $base );
req( $test, 405, 'demo', 'DELETE', $base );
req( $test, 405, 'root', 'DELETE', $base );



note( "=============================" );
note( '"employee/nick" resource' );
note( "=============================" );
$base = "employee/nick";
docu_check($test, "employee/nick");
#
# GET, PUT employee/nick
#
req( $test, 405, 'demo', 'GET', $base );
req( $test, 405, 'root', 'GET', $base );
req( $test, 405, 'demo', 'PUT', $base );
req( $test, 405, 'root', 'PUT', $base );

#
# POST employee/nick
#
# - create a 'mrfu' employee
$mrfu = create_testing_employee( { nick => 'mrfu' } );
my $nick_of_mrfu = $mrfu->nick;
$eid_of_mrfu = $mrfu->eid;
#
# - give Mr. Fu an email address
#diag("--- POST employee/nick (update email)");
my $j = '{ "nick": "' . $nick_of_mrfu . '", "email" : "mrsfu@dragon.cn" }';
req( $test, 403, 'demo', 'POST', $base, $j );
#
$status = req( $test, 200, 'root', 'POST', $base, $j );
is( $status->level, "OK" );
is( $status->code, 'DOCHAZKA_CUD_OK' );
is( $status->payload->{'email'}, 'mrsfu@dragon.cn' );
#
# - non-existent nick (insert new employee)
#diag("--- POST employee/nick (non-existent nick)");
req( $test, 403, 'demo', 'POST', $base, '{ "nick" : 5442' );
req( $test, 400, 'root', 'POST', $base, '{ "nick" : 5442' );
req( $test, 403, 'demo', 'POST', $base, '{ "nick" : 5442 }' );
#
# - attempt to insert new employee with bogus "eid" value
$status = req( $test, 200, 'root', 'POST', $base,
    '{ "eid": 534, "nick": "mrfutra", "fullname":"Rovnou do futer" }' );
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_CUD_OK' );
is( $status->payload->{'nick'}, 'mrfutra' );
is( $status->payload->{'fullname'}, 'Rovnou do futer' );
isnt( $status->payload->{'eid'}, 534 );
my $eid_of_mrfutra = $status->payload->{'eid'};
#
# - bogus property
$status = req( $test, 400, 'root', 'POST', $base, '{ "Nick" : "foobar" }' );
#
# delete the testing user
delete_testing_employee( $eid_of_mrfu );
delete_testing_employee( $eid_of_mrfutra );

# - add a new employee with nick in request body
#diag("--- POST employee/nick (insert)");
req( $test, 403, 'demo', 'POST', $base, '{' );
req( $test, 400, 'root', 'POST', $base, '{' );
req( $test, 403, 'demo', 'POST', $base, 
    '{ "nick":"mrfu", "fullname":"Dragon Scale" }' );
$status = req( $test, 200, 'root', 'POST', $base, 
    '{ "nick":"mrfu", "fullname":"Dragon Scale", "email":"mrfu@dragon.cn" }' );
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_CUD_OK' );
$mrfu = App::Dochazka::REST::Model::Employee->spawn( %{ $status->payload } );
$mrfuprime = App::Dochazka::REST::Model::Employee->spawn( eid => $mrfu->eid, 
    nick => 'mrfu', fullname => 'Dragon Scale', email => 'mrfu@dragon.cn' );
is_deeply( $mrfu, $mrfuprime );
$eid_of_mrfu = $mrfu->eid;
#
# - and give it valid, yet bogus JSON (unknown nick - insert)
$status = req( $test, 200, 'root', 'POST', $base, 
    '{ "nick" : "wombat", "bogus" : "json" }' );
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_CUD_OK' );
my $eid_of_wombat = $status->payload->{'eid'};
#
#
# - get wombat
$status = req( $test, 200, 'root', 'GET', '/employee/nick/wombat' );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_EMPLOYEE_FOUND' );
my $wombat_emp = App::Dochazka::REST::Model::Employee->spawn( $status->payload );

# - and give it valid, yet bogus JSON -- update has nothing to do
$status = req( $test, 400, 'root', 'POST', $base, 
    '{ "nick" : "wombat", "bogus" : "json" }' );

#
delete_testing_employee( $eid_of_wombat );


# - update existing employee
#diag("--- POST employee/nick (update)");
req( $test, 403, 'demo', 'POST', $base, 
    '{ "nick":"mrfu", "fullname":"Dragon Scale Update", "email" : "scale@dragon.org" }' );
$status = req( $test, 200, 'root', 'POST', $base, 
    '{ "nick":"mrfu", "fullname":"Dragon Scale Update", "email" : "scale@dragon.org" }' );
is( $status->level, "OK" );
is( $status->code, 'DOCHAZKA_CUD_OK' );
$mrfu = App::Dochazka::REST::Model::Employee->spawn( %{ $status->payload } );
$mrfuprime = App::Dochazka::REST::Model::Employee->spawn( eid => $eid_of_mrfu,
    nick => 'mrfu', fullname => 'Dragon Scale Update', email => 'scale@dragon.org' );
is_deeply( $mrfu, $mrfuprime );
#
# - create a bogus user with a bogus property
$status = req( $test, 200, 'root', 'POST', $base, 
    '{ "nick":"bogus", "wago":"svorka", "fullname":"bogus user" }' );
is( $status->level, "OK" );
is( $status->code, 'DOCHAZKA_CUD_OK' );
my $eid_of_bogus = $status->payload->{'eid'};

# 
# - inactive and active users get a little piece of the action, too:
#   they can operate on themselves (certain fields), but not on, e.g., Mr. Fu
#foreach my $user ( qw( demo inactive active ) ) {
#    req( $test, 403, $user, 'POST', "$base", '{ "nick" : "mrfu", "passhash" : "HAHAHAHA" }' );
#    foreach my $target ( qw( wombat unknown ) ) {
#        my $entity = <<"EOH";
#{ "nick" : "$target", "passhash" : "HAHAHAHA" }' );
#EOH
#        diag( $entity );
#        req( $test, 403, $user, 'POST', "$base", $entity );
#    }
#}
#foreach my $user ( qw( inactive active ) ) {
#    $status = req( $test, 200, $user, 'POST', "$base", <<"EOH" );
#{ "nick" : "$user", "salt" : "tHE gREAT wOMBAT" }
#EOH
#    is( $status->level, 'OK' );
#    is( $status->code, 'DOCHAZKA_CUD_OK' );
#    $status = req( $test, 200, 'root', 'GET', "employee/nick/$user" );
#    is( $status->level, 'OK' );
#    is( $status->code, 'DISPATCH_RECORDS_FOUND' );
#    is( ref( $status->payload ), 'HASH' );
#    is( $status->payload->{'salt'}, "tHE gREAT wOMBAT" );
#}

map { delete_testing_employee( $_ ); } ( $eid_of_mrfu, $eid_of_bogus );

#
# DELETE employee/nick
#
req( $test, 405, 'demo', 'DELETE', $base );
req( $test, 405, 'root', 'DELETE', $base );


#=============================
# "employee/nick/:nick" resource
#=============================
$base = "employee/nick";
docu_check($test, "employee/nick/:nick");
#
# GET employee/nick/:nick
#
# - with nick == 'root'
$status = req( $test, 200, 'root', 'GET', "$base/root" );
is( $status->level, "OK" );
is( $status->code, 'DISPATCH_EMPLOYEE_FOUND' );
ok( defined $status->payload );
ok( exists $status->payload->{'eid'} );
is( $status->payload->{'eid'}, $site->DOCHAZKA_EID_OF_ROOT );
ok( exists $status->payload->{'nick'} );
is( $status->payload->{'nick'}, 'root' );
ok( exists $status->payload->{'fullname'} );
is( $status->payload->{'fullname'}, 'Root Immutable' );
#
# - with nick == 'demo'
$status = req( $test, 200, 'root', 'GET', "$base/demo" );
is( $status->level, "OK" );
is( $status->code, 'DISPATCH_EMPLOYEE_FOUND' );
ok( defined $status->payload );
ok( exists $status->payload->{'eid'} );
is( $status->payload->{'eid'}, 2 );
ok( exists $status->payload->{'nick'} );
is( $status->payload->{'nick'}, 'demo' );
ok( exists $status->payload->{'fullname'} );
is( $status->payload->{'fullname'}, 'Demo Employee' );
#
req( $test, 200, 'demo', 'GET', "$base/demo" );
is( $status->level, "OK" );
is( $status->code, 'DISPATCH_EMPLOYEE_FOUND' );
#
req( $test, 404, 'root', 'GET', "$base/53432" );
req( $test, 403, 'demo', 'GET', "$base/53432" );
req( $test, 404, 'root', 'GET', "$base/heathledger" );
# 
# this one triggers "wide character in print" warnings
#req( $test, 404, 'root', 'GET', "$base/" . uri_escape_utf8('/employee/nick//////áěěoěščqwšáščšýš..-...-...-..-.00') );

#
# - single-character nicks are allowed
#
$status = req( $test, 404, 'root', 'GET', "$base/4" );


# 
# PUT employee/nick/:nick
#
# - insert and be nice
req( $test, 403, 'demo', 'PUT', "$base/mrsfu", '{' );
req( $test, 400, 'root', 'PUT', "$base/mrsfu", '{' );
req( $test, 403, 'demo', 'PUT', "$base/mrsfu", 
    '{ "fullname":"Dragonness" }' );
$status = req( $test, 200, 'root', 'PUT', "$base/mrsfu", 
    '{ "fullname":"Dragonness" }' );
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_CUD_OK' );
$mrsfu = App::Dochazka::REST::Model::Employee->spawn( %{ $status->payload } );
$mrsfuprime = App::Dochazka::REST::Model::Employee->spawn( eid => $mrsfu->eid, 
    nick => 'mrsfu', fullname => 'Dragonness' );
is_deeply( $mrsfu, $mrsfuprime );
my $eid_of_mrsfu = $mrsfu->eid;

# - insert and be pathological
# - provide conflicting 'nick' property in the content body
req( $test, 403, 'demo', 'PUT', "$base/hapless", '{' );
req( $test, 400, 'root', 'PUT', "$base/hapless", '{' );
req( $test, 403, 'demo', 'PUT', "$base/hapless", 
    '{ "nick":"INVALID", "fullname":"Anders Chen" }' );
$status = req( $test, 200, 'root', 'PUT', "$base/hapless", 
    '{ "nick":"INVALID", "fullname":"Anders Chen" }' );
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_CUD_OK' );
my $hapless = App::Dochazka::REST::Model::Employee->spawn( %{ $status->payload } );
isnt( $hapless->nick, 'INVALID' );
is( $hapless->nick, 'hapless' );
my $haplessprime = App::Dochazka::REST::Model::Employee->spawn( eid => $hapless->eid, 
    nick => 'hapless', fullname => 'Anders Chen' );
is_deeply( $hapless, $haplessprime );
my $eid_of_hapless = $hapless->eid;

# - update and be nice
$status = req( $test, 200, 'root', 'PUT', "$base/hapless", 
    '{ "fullname":"Chen Update", "salt":"none, please" }' );
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_CUD_OK' );
$hapless = App::Dochazka::REST::Model::Employee->spawn( %{ $status->payload } );
is( $hapless->nick, "hapless" );
is( $hapless->fullname, "Chen Update" );
is( $hapless->salt, "none, please" );
$haplessprime = App::Dochazka::REST::Model::Employee->spawn( eid => $eid_of_hapless,
    nick => 'hapless', fullname => 'Chen Update', salt => "none, please" );
is_deeply( $hapless, $haplessprime );

# - update and be nice and also change salt to null
$status = req( $test, 200, 'root', 'PUT', "$base/hapless", 
    '{ "fullname":"Chen Update", "salt":null }' );
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_CUD_OK' );
$hapless = App::Dochazka::REST::Model::Employee->spawn( %{ $status->payload } );
is( $hapless->nick, "hapless" );
is( $hapless->fullname, "Chen Update" );
is( $hapless->salt, undef );
$haplessprime = App::Dochazka::REST::Model::Employee->spawn( eid => $eid_of_hapless,
    nick => 'hapless', fullname => 'Chen Update' );
is_deeply( $hapless, $haplessprime );

# - update and be pathological
# - attempt to set a bogus EID
$status = req( $test, 200, 'root', 'PUT', "$base/hapless",
    '{ "eid": 534, "fullname":"Good Brother Chen", "salt":"" }' );
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_CUD_OK' );
$hapless = App::Dochazka::REST::Model::Employee->spawn( %{ $status->payload } );
is( $hapless->fullname, "Good Brother Chen" );
is( $hapless->eid, $eid_of_hapless );
isnt( $hapless->eid, 534 );
$haplessprime = App::Dochazka::REST::Model::Employee->spawn( eid => $eid_of_hapless,
    nick => 'hapless', fullname => 'Good Brother Chen' );
is_deeply( $hapless, $haplessprime );

# - pathologically attempt to change nick to null
dbi_err( $test, 500, 'root', 'PUT', "$base/hapless",
    '{ "nick":null }', qr/violates not-null constraint/ );

# - feed it more bogusness
req( $test, 400, 'root', 'PUT', "$base/hapless", '{ "legal" : "json" }' );

# 
# - inactive and active users get a little piece of the action, too:
#   they can operate on themselves (certain fields), but not on, e.g., Mrs. Fu or Hapless
foreach my $user ( qw( demo inactive active ) ) {
    foreach my $target ( qw( mrsfu hapless ) ) {
        req( $test, 403, $user, 'PUT', "$base/$target", <<"EOH" );
{ "passhash" : "HAHAHAHA" }
EOH
    }
}

#foreach my $user ( qw( inactive active ) ) {
#    $status = req( $test, 200, $user, 'PUT', "$base/$user", <<"EOH" );
#{ "salt" : "tHE gREAT wOMBAT" }
#EOH
#    is( $status->level, 'OK' );
#    is( $status->code, 'DOCHAZKA_CUD_OK' );
#    $status = req( $test, 200, 'root', 'GET', "employee/nick/$user" );
#    is( $status->level, 'OK' );
#    is( $status->code, 'DISPATCH_RECORDS_FOUND' );
#    is( ref( $status->payload ), 'HASH' );
#    is( $status->payload->{'salt'}, "tHE gREAT wOMBAT" );
#}

# 
delete_testing_employee( $eid_of_mrsfu );
delete_testing_employee( $eid_of_hapless );


#
# POST employee/nick:nick
#
req( $test, 405, 'demo', 'POST', "$base/root" );
req( $test, 405, 'root', 'POST', "$base/root" );

#
# DELETE employee/nick/:nick
#
# create a "cannon fodder" employee
$cf = create_testing_employee( { nick => 'cannonfodder' } );
ok( $cf->eid > 1 );
$eid_of_cf = $cf->eid;

# get cannonfodder - no problem
$status = req( $test, 200, 'root', 'GET', "$base/cannonfodder" );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_EMPLOYEE_FOUND' );

# 'employee/nick/:nick' - delete cannonfodder
req( $test, 403, 'demo', 'DELETE', $base . "/" . $cf->nick );
$status = req( $test, 200, 'root', 'DELETE', $base . "/" . $cf->nick );
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_CUD_OK' );

# attempt to get cannonfodder - not there anymore
req( $test, 404, 'root', 'GET', "$base/cannonfodder" );

# attempt to get in a different way
$status = App::Dochazka::REST::Model::Employee->load_by_nick( $dbix_conn, 'cannonfodder' );
is( $status->level, 'NOTICE' );
is( $status->code, 'DISPATCH_NO_RECORDS_FOUND' );

# create another "cannon fodder" employee
$cf = create_testing_employee( { nick => 'cannonfodder' } );
ok( $cf->eid > $eid_of_cf ); # EID will have incremented
$eid_of_cf = $cf->eid;

# get cannonfodder - again, no problem
$status = req( $test, 200, 'root', 'GET', "$base/cannonfodder" );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_EMPLOYEE_FOUND' );

# - delete with a typo (non-existent nick)
req( $test, 403, 'demo', 'DELETE', "$base/cannonfoddertypo" );
req( $test, 404, 'root', 'DELETE', "$base/cannonfoddertypo" );

# attempt to get cannonfodder - still there
$status = req( $test, 200, 'root', 'GET', "$base/cannonfodder" );
is( $status->level, 'OK' );
is( $status->code, 'DISPATCH_EMPLOYEE_FOUND' );

delete_testing_employee( $eid_of_cf );

# attempt to delete 'root the immutable' (won't work)
dbi_err( $test, 500, 'root', 'DELETE', "$base/root", undef, qr/immutable/i );


#=============================
# "employee/nick/:nick/minimal" resource
#=============================
$base = 'employee/nick';
docu_check($test, "$base/:nick/minimal");

note( 'root attempt to get non-existent nick (minimal)' );
req( $test, 404, 'root', 'GET', "$base/53432/minimal" );

note( 'demo attempt to get non-existent nick (minimal)' );
req( $test, 403, 'demo', 'GET', "$base/53432/minimal" );

note( 'demo attempt to get existent nick (minimal)' );
req( $test, 403, 'demo', 'GET', "$base/root/minimal" );

note( 'root get active (minimal)' );
$status = req( $test, 200, 'root', 'GET', "$base/active/minimal" );
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_EMPLOYEE_MINIMAL' );
ok( $status->payload );
is( ref( $status->payload ), 'HASH' );
ok( $status->payload->{'nick'} );
is( $status->payload->{'nick'}, 'active' );
is( $status->payload->{'eid'}, $ts_eid_active );
is( join( '', sort( keys( %{ $status->payload } ) ) ),
    join( '', sort( @{ $site->DOCHAZKA_EMPLOYEE_MINIMAL_FIELDS } ) ) );


#=============================
# "employee/nick/:nick/team" resource
#=============================
$base = "employee/nick";
docu_check($test, "$base/:nick/team" );
# 


#=============================
# "employee/search/nick/:key" resource
#=============================
$base = "employee/search/nick";
docu_check($test, "$base/:key");
# 
# - with wildcard == 'ro%'
$status = req( $test, 200, 'root', 'GET', "$base/ro%" );
is( $status->level, "OK" );
is( $status->code, 'DISPATCH_RECORDS_FOUND' );
ok( defined $status->payload );
is( ref( $status->payload ), 'ARRAY' );
is( scalar( @{ $status->payload } ), 1 );
is( $status->payload->[0]->{'nick'}, 'root' );
#ok( exists $status->payload->{'count'} );
#ok( exists $status->payload->{'search_key'} );
#ok( exists $status->payload->{'result_set'} );
#ok( ref( $status->payload->{'result_set'} ) eq 'ARRAY' );
#is( $status->payload->{'result_set'}->[0]->{'nick'}, 'root' );

#=============================
# "employee/sec_id/:sec_id" resource
#=============================
$base = "employee/sec_id";
docu_check($test, "$base/:sec_id");
# 
$status = req( $test, 200, 'root', 'PUT', "employee/nick/inactive",
    '{ "sec_id" : 1024 }' );
is( $status->level, "OK" );
is( $status->code, 'DOCHAZKA_CUD_OK' );
#
$status = req( $test, 200, 'root', 'GET', "employee/nick/inactive" ); 
is( $status->level, "OK" );
is( $status->code, 'DISPATCH_EMPLOYEE_FOUND' );
is( $status->payload->{'sec_id'}, 1024 );
my $mustr = $status->payload;
#
$status = req( $test, 200, 'root', 'GET', "employee/sec_id/1024" ); 
is( $status->level, "OK" );
is( $status->code, 'DISPATCH_EMPLOYEE_FOUND' );
is_deeply( $status->payload, $mustr );


#=============================
# "employee/sec_id/:sec_id/minimal" resource
#=============================
$base = 'employee/sec_id';
docu_check($test, "$base/:sec_id/minimal");

note( 'root attempt to get non-existent sec_id (minimal)' );
req( $test, 404, 'root', 'GET', "$base/53432/minimal" );

note( 'demo attempt to get non-existent sec_id (minimal)' );
req( $test, 403, 'demo', 'GET', "$base/53432/minimal" );

note( 'set root\'s sec_id to be foobar' );
my $eid_of_root = $site->DOCHAZKA_EID_OF_ROOT;
$status = req( $test, 200, 'root', 'POST', 'employee/eid', <<"EOS" );
{ "eid" : $eid_of_root, "sec_id" : "foobar" }
EOS
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_CUD_OK' );

note( 'demo attempt to get existent sec_id (minimal)' );
req( $test, 403, 'demo', 'GET', "$base/foobar/minimal" );

note( 'root get itself (minimal)' );
$status = req( $test, 200, 'root', 'GET', "$base/foobar/minimal" );
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_EMPLOYEE_MINIMAL' );
ok( $status->payload );
is( ref( $status->payload ), 'HASH' );
ok( $status->payload->{'nick'} );
is( $status->payload->{'nick'}, 'root' );
is( $status->payload->{'eid'}, $eid_of_root );
is( join( '', sort( keys( %{ $status->payload } ) ) ),
    join( '', sort( @{ $site->DOCHAZKA_EMPLOYEE_MINIMAL_FIELDS } ) ) );

note( 'set root\'s sec_id back to undef' );
$status = req( $test, 200, 'root', 'POST', 'employee/eid', <<"EOS" );
{ "eid" : $eid_of_root, "sec_id" : null }
EOS
is( $status->level, 'OK' );
is( $status->code, 'DOCHAZKA_CUD_OK' );



#=============================
# "employee/team" resource
#=============================
$base = "employee/team";
docu_check($test, "$base");
# 

delete_employee_by_nick( $test, 'inactive' );
delete_employee_by_nick( $test, 'active' );

done_testing;
