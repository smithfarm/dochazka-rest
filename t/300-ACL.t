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
# tests for Dispatch/ACL.pm
#

#!perl
use 5.012;
use strict;
use warnings;

#use App::CELL::Test::LogToFile;
use App::CELL qw( $meta $site );
use Data::Dumper;
use App::Dochazka::REST::ACL qw( check_acl );
use App::Dochazka::REST::Test;
use Test::Fatal;
use Test::More;

my $status = initialize_unit();
if ( $status->not_ok ) {
    plan skip_all => "not configured or server not running";
}

# standard functionality

my $profile = 'passerby';
ok( check_acl( $profile, 'passerby' ) );
ok( check_acl( $profile, 'inactive' ) );
ok( check_acl( $profile, 'active' ) );
ok( check_acl( $profile, 'admin' ) );

$profile = 'inactive';
ok( ! check_acl( $profile, 'passerby' ) );
ok( check_acl( $profile, 'inactive' ) );
ok( check_acl( $profile, 'active' ) );
ok( check_acl( $profile, 'admin' ) );

$profile = 'active';
ok( ! check_acl( $profile, 'passerby' ) );
ok( ! check_acl( $profile, 'inactive' ) );
ok( check_acl( $profile, 'active' ) );
ok( check_acl( $profile, 'admin' ) );

$profile = 'admin';
ok( ! check_acl( $profile, 'passerby' ) );
ok( ! check_acl( $profile, 'inactive' ) );
ok( ! check_acl( $profile, 'active' ) );
ok( check_acl( $profile, 'admin' ) );

# slightly non-standard functionality
ok( ! check_acl( undef, 'passerby' ) );
ok( ! check_acl( undef, 'inactive' ) );
ok( ! check_acl( undef, 'active' ) );
ok( ! check_acl( undef, 'admin' ) );

# pathological states
foreach my $p ( qw( passerby inactive active admin ) ) {
    like( exception { check_acl( $p, undef ); }, 
        qr/Parameter #2 \(undef\) to App::Dochazka::REST::ACL::check_acl was an 'undef', which is not one of the allowed types: scalar/
    );
}
like( exception { check_acl( 'passerby', 'passerby', 'foobar' ); }, 
    qr/3 parameters were passed to App::Dochazka::REST::ACL::check_acl but 2 were expected/ );
like( exception { check_acl( 'passerby', 'foobar' ); }, 
    qr/Invalid employee privlevel/ );
like( exception { check_acl( 'passerby' ); }, 
    qr/1 parameter was passed to App::Dochazka::REST::ACL::check_acl but 2 were expected/ );
like( exception { check_acl( { "passergry" => "foobar" } ); }, 
    qr/which is not one of the allowed types/ );
like( exception { check_acl(); },
    qr/0 parameters were passed to App::Dochazka::REST::ACL::check_acl but 2 were expected/ );

done_testing;
