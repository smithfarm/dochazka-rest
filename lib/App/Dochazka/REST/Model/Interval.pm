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

package App::Dochazka::REST::Model::Interval;

use 5.012;
use strict;
use warnings;
use App::CELL qw( $CELL $log $meta $site );
use Data::Dumper;
use App::Dochazka::REST::Model::Lock qw( count_locks_in_tsrange );
use App::Dochazka::REST::Model::Shared qw( 
    canonicalize_tsrange 
    cud 
    cud_generic
    load 
    load_multiple 
    select_single
);
use Params::Validate qw( :all );

# we get 'spawn', 'reset', and accessors from parent
use parent 'App::Dochazka::Common::Model::Interval';



=head1 NAME

App::Dochazka::REST::Model::Interval - activity intervals data model




=head1 SYNOPSIS

    use App::Dochazka::REST::Model::Interval;

    ...


=head1 DESCRIPTION

A description of the activity interval data model follows.


=head2 Intervals in the database

Activity intervals are stored in the C<intervals> database table, which has
the following structure:

    CREATE TABLE intervals (
       iid         serial PRIMARY KEY,
       eid         integer REFERENCES employees (eid) NOT NULL,
       aid         integer REFERENCES activities (aid) NOT NULL,
       intvl       tsrange NOT NULL,
       long_desc   text,
       remark      text,
       EXCLUDE USING gist (eid WITH =, intvl WITH &&)
    );

Note the use of the C<tsrange> operator introduced in PostgreSQL 9.2.

In addition to the Interval ID (C<iid>), which is assigned by PostgreSQL,
the Employee ID (C<eid>), and the Activity ID (C<aid>), which are provided
by the client, an interval can optionally have a long description
(C<long_desc>), which is the employee's description of what she did during
the interval, and an admin remark (C<remark>).


=head2 Intervals in the Perl API

In the data model, individual activity intervals (records in the
C<intervals> table) are represented by "interval objects". All methods
and functions for manipulating these objects are contained in this module.
The most important methods are:

=over

=item * constructor (L<spawn>)

=item * basic accessors (L<iid>, L<eid>, L<aid>, L<intvl>, L<long_desc>,
L<remark>)

=item * L<reset> (recycles an existing object by setting it to desired
state)

=item * L<insert> (inserts object into database)

=item * L<delete> (deletes object from database)

=back

For basic activity interval workflow, see C<t/010-interval.t>.




=head1 EXPORTS

This module provides the following exports:

=cut

use Exporter qw( import );
our @EXPORT_OK = qw( 
    delete_intervals_by_eid_and_tsrange
    fetch_intervals_by_eid_and_tsrange
    iid_exists 
);



=head1 METHODS


=head2 load_by_iid

Boilerplate.

=cut

sub load_by_iid {
    my $self = shift;
    my ( $conn, $iid ) = validate_pos( @_, 
        { isa => 'DBIx::Connector' },
        { type => SCALAR },
    );

    return load( 
        conn => $conn,
        class => __PACKAGE__, 
        sql => $site->SQL_INTERVAL_SELECT_BY_IID,
        keys => [ $iid ],
    );
}
    

=head2 insert

Instance method. Attempts to INSERT a record.
Field values are taken from the object. Returns a status object.

=cut

sub insert {
    my $self = shift;
    my ( $context ) = validate_pos( @_, { type => HASHREF } );

    my $status = cud( 
        conn => $context->{'dbix_conn'},
        eid => $context->{'current'}->{'eid'},
        object => $self,
        sql => $site->SQL_INTERVAL_INSERT,
        attrs => [ 'eid', 'aid', 'intvl', 'long_desc', 'remark' ],
    );

    return $status;
}


=head2 update

Instance method. Attempts to UPDATE a record.
Field values are taken from the object. Returns a status object.

=cut

sub update {
    my $self = shift;
    my ( $context ) = validate_pos( @_, { type => HASHREF } );

    return $CELL->status_err( 'DOCHAZKA_MALFORMED_400' ) unless $self->{'iid'};

    my $status = cud( 
        conn => $context->{'dbix_conn'},
        eid => $context->{'current'}->{'eid'},
        object => $self,
        sql => $site->SQL_INTERVAL_UPDATE,
        attrs => [ qw( eid aid intvl long_desc remark iid ) ],
    );

    return $status;
}


=head2 delete

Instance method. Attempts to DELETE a record.
Field values are taken from the object. Returns a status object.

=cut

sub delete {
    my $self = shift;
    my ( $context ) = validate_pos( @_, { type => HASHREF } );

    my $status = cud( 
        conn => $context->{'dbix_conn'},
        eid => $context->{'current'}->{'eid'},
        object => $self,
        sql => $site->SQL_INTERVAL_DELETE,
        attrs => [ 'iid' ],
    );
    $self->reset( iid => $self->{iid} ) if $status->ok;

    return $status;
}



=head1 FUNCTIONS


=head2 iid_exists

Boolean function

=cut

BEGIN {
    no strict 'refs';
    *{'iid_exists'} = App::Dochazka::REST::Model::Shared::make_test_exists( 'iid' );
}


=head2 fetch_intervals_by_eid_and_tsrange

Given an EID and a tsrange, return all that employee's intervals that 
fall within that tsrange.

Before any records are returned, the tsrange is checked to see if it
overlaps with any privlevel or schedule changes - in which case an error is
returned.  This is so interval report-generators do not have to handle
changes in employee status.

=cut

sub fetch_intervals_by_eid_and_tsrange {
    my ( $conn, $eid, $tsrange ) = validate_pos( @_,
        { isa => 'DBIx::Connector' },
        { type => SCALAR },
        { type => SCALAR, optional => 1 },
    );

    my $status = canonicalize_tsrange( $conn, $tsrange );
    return $status unless $status->ok;
    $tsrange = $status->payload;

    $status = App::Dochazka::REST::Model::Employee->load_by_eid( $conn, $eid );
    return $status unless $status->ok;
    my $emp = $status->payload;
    die "AAGHA!" unless $emp->eid == $eid;

    # check for priv change during tsrange
    my $priv_change = $emp->priv_change_during_range( $conn, $tsrange );
    $log->debug( "fetch_intervals_by_eid_and_tsrange: priv_change_during_range returned " . Dumper( $priv_change ) );
    if ( $priv_change ) {
        return $CELL->status_err( 'DOCHAZKA_EMPLOYEE_PRIV_CHANGED' );
    }

    # check for sched change during tsrange
    my $schedule_change = $emp->schedule_change_during_range( $conn, $tsrange );
    $log->debug( "fetch_intervals_by_eid_and_tsrange: schedule_change_during_range returned " . Dumper($schedule_change ) );
    if ( $schedule_change ) {
        return $CELL->status_err( 'DOCHAZKA_EMPLOYEE_SCHEDULE_CHANGED' );
    }

    return load_multiple(
        conn => $conn,
        class => __PACKAGE__,
        sql => $site->SQL_INTERVAL_SELECT_BY_EID_AND_TSRANGE,
        keys => [ $eid, $tsrange, $site->DOCHAZKA_INTERVAL_SELECT_LIMIT ],
    );
}


=head2 delete_intervals_by_eid_and_tsrange

Given an EID and a tsrange, delete all that employee's intervals that 
fall within that tsrange.

Returns a status object.

=cut

sub delete_intervals_by_eid_and_tsrange {
    my ( $conn, $eid, $tsrange ) = validate_pos( @_,
        { isa => 'DBIx::Connector' },
        { type => SCALAR },
        { type => SCALAR },
    );

    my $status = canonicalize_tsrange( $conn, $tsrange );
    return $status unless $status->ok;
    $tsrange = $status->payload;

    # check for locks
    $status = count_locks_in_tsrange( $conn, $eid, $tsrange );
    return $status unless $status->ok;
    # number of locks is in $status->payload
    if ( $status->payload > 0 ) {
        return $CELL->status_err( 'DOCHAZKA_TSRANGE_LOCKED', args => [ $tsrange, $status->payload ] );
    }

    $status = App::Dochazka::REST::Model::Employee->load_by_eid( $conn, $eid );
    return $status unless $status->ok;
    my $emp = $status->payload;
    die "AAGHA!" unless $emp->eid == $eid;

    # check for priv change during tsrange
    my $search_tsrange = $tsrange;
    $search_tsrange =~ s/^[^\[]*\[/\(/;
    my $priv_change = $emp->priv_change_during_range( $conn, $search_tsrange );
    $log->debug( "delete_intervals_by_eid_and_tsrange: priv_change_during_range returned " . Dumper( $priv_change ) );
    if ( $priv_change ) {
        return $CELL->status_err( 'DOCHAZKA_EMPLOYEE_PRIV_CHANGED' );
    }

    # check for sched change during tsrange
    my $schedule_change = $emp->schedule_change_during_range( $conn, $search_tsrange );
    $log->debug( "delete_intervals_by_eid_and_tsrange: schedule_change_during_range returned " . Dumper($schedule_change ) );
    if ( $schedule_change ) {
        return $CELL->status_err( 'DOCHAZKA_EMPLOYEE_SCHEDULE_CHANGED' );
    }

    # check how many intervals we are talking about here
    $status = select_single(
        conn => $conn,
        sql => $site->SQL_INTERVAL_SELECT_COUNT_BY_EID_AND_TSRANGE,
        keys => [ $eid, $tsrange, $site->DOCHAZKA_INTERVAL_SELECT_LIMIT ],
    );
    return $status unless $status->ok;
    # $status->payload contains [ $count ]
    my $count = $status->payload->[0];

    # if it's more than the limit, no go
    return $CELL->status_err( 'DOCHAZKA_INTERVAL_DELETE_LIMIT_EXCEEDED', args => [ $count ] )
        unless $count <= $site->DOCHAZKA_INTERVAL_DELETE_LIMIT;
    
    # hmm, can we use select_single with a DELETE statement?
    return cud_generic(
        conn => $conn,
        eid => $eid,
        sql => $site->SQL_INTERVAL_DELETE_BY_EID_AND_TSRANGE,
        bind_params => [ $eid, $tsrange ],
    );
}

=head1 AUTHOR

Nathan Cutler, C<< <presnypreklad@gmail.com> >>

=cut 

1;

