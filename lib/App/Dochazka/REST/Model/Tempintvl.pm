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

package App::Dochazka::REST::Model::Tempintvl;

use 5.012;
use strict;
use warnings;
use App::CELL qw( $CELL $log $meta $site );
use App::Dochazka::REST::Model::Shared qw( cud load load_multiple );
use Data::Dumper;
use Params::Validate qw( :all );

# we get 'spawn', 'reset', and accessors from parent
use parent 'App::Dochazka::Common::Model::Tempintvl';




=head1 NAME

App::Dochazka::REST::Model::Tempintvl - tempintvl data model




=head1 SYNOPSIS

    use App::Dochazka::REST::Model::Tempintvl;

    ...


=head1 DESCRIPTION

A description of the tempinvl data model follows.


=head2 Tempintvls in the database

    CREATE TABLE tempintvls (
        int_id  serial PRIMARY KEY,
        tiid    integer NOT NULL,
        intvl   tstzrange NOT NULL
    )



=head1 EXPORTS

This module provides the following exports:

=cut

use Exporter qw( import );
our @EXPORT_OK = qw( 
);



=head1 METHODS


=head2 insert

Instance method. Attempts to INSERT a record. Field values are taken from the
object. Returns a status object.

=cut

sub insert { 
    my $self = shift;
    my ( $context ) = validate_pos( @_, { type => HASHREF } );

    my $status = cud( 
        conn => $context->{'dbix_conn'},
        eid => $context->{'current'}->{'eid'},
        object => $self, 
        sql => $site->SQL_TEMPINTVL_INSERT, 
        attrs => [ 'tiid', 'intvl' ],
    );

    return $status; 
}



=head1 FUNCTIONS


=head1 AUTHOR

Nathan Cutler, C<< <presnypreklad@gmail.com> >>

=cut 

1;


