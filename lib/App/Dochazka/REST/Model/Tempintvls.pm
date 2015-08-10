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

package App::Dochazka::REST::Model::Tempintvls;

use 5.012;
use strict;
use warnings FATAL => 'all';
use App::CELL qw( $CELL $log $meta $site );
use App::Dochazka::REST::ConnBank qw( $dbix_conn );
use App::Dochazka::REST::Model::Employee;
use App::Dochazka::REST::Model::Shared qw(
    split_tsrange
);
use App::Dochazka::REST::Util::Date qw(
    canon_date_diff
    canon_to_ymd
    ymd_to_canon
);
use App::Dochazka::REST::Util::Holiday qw(
    get_tomorrow
    holidays_in_daterange
);
use Data::Dumper;
use Date::Calc qw(
    Add_Delta_Days
    Day_of_Week
);
use JSON;
use Params::Validate qw( :all );
use Try::Tiny;

# we get 'spawn', 'reset', and accessors from parent
use parent 'App::Dochazka::Common::Model::Tempintvls';




=head1 NAME

App::Dochazka::REST::Model::Tempintvls - object class for "scratch schedules"




=head1 SYNOPSIS

    use App::Dochazka::REST::Model::Tempintvls;

    ...




=head1 METHODS


=head2 populate

Populate the tempintvls object (called automatically by 'reset' method
which is, in turn, called automatically by 'spawn')

=cut

sub populate {
    my $self = shift;

    my $ss = _next_tiid();
    $log->debug( "Got next TIID: $ss" );
    $self->{'tiid'} = $ss;
    return;
}


=head2 _vet_tsrange

Takes a C<DBIx::Connector> object and a tsrange.  Checks the tsrange for sanity
and populates the C<tsrange>, C<lower_canon>, C<lower_ymd>, C<upper_canon>,
C<upper_ymd> attributes. Returns a status object.

The algorithm for generating fillup intervals takes lower and upper date 
bounds - it does not know about timestamps or tsranges

=cut

sub _vet_tsrange {
    my $self = shift;
    my ( %ARGS ) = validate( @_, {
        dbix_conn => { isa => 'DBIx::Connector' },
        tsrange => { type => SCALAR },
    } );
    $log->debug( "Entering " . __PACKAGE__ . "::_vet_tsrange to vet the tsrange $ARGS{tsrange}" );

    # split the tsrange
    my @parens = $ARGS{tsrange} =~ m/[^\[(]*([\[(])[^\])]*([\])])/;
    my $status = split_tsrange( $ARGS{dbix_conn}, $ARGS{tsrange} );
    $log->info( "split_tsrange() returned: " . Dumper( $status ) );
    return $status unless $status->ok;
    my $low = $status->payload->[0];
    my $upp = $status->payload->[1];
    $self->{'tsrange'} = "$parens[0] $low, $upp $parens[1]";
    my @low = canon_to_ymd( $low );
    my @upp = canon_to_ymd( $upp );

    # lower date bound = tsrange:begin_date minus one day
    @low = Add_Delta_Days( @low, -1 );
    $low = ymd_to_canon( @low );

    # upper date bound = tsrange:begin_date plus one day
    @upp = Add_Delta_Days( @upp, 1 );
    $upp = ymd_to_canon( @upp );

    # check DOCHAZKA_INTERVAL_FILLUP_LIMIT
    # - add two days to the limit to account for how we just stretched $low and $upp
    my $fillup_limit = $site->DOCHAZKA_INTERVAL_FILLUP_LIMIT + 2;
    if ( $fillup_limit < canon_date_diff( $low, $upp ) ) {
        return $CELL->status_err( 'DOCHAZKA_TSRANGE_TOO_BIG', args => [ $ARGS{tsrange} ] )
    }

    $self->{'lower_canon'} = \@low;
    $self->{'upper_canon'} = \@upp;
    $self->{'lower_ymd'} = $low;
    $self->{'upper_ymd'} = $upp;

    return $CELL->status_ok( 'SUCCESS' );
}


=head2 _vet_employee

Expects to be called *after* C<_vet_tsrange>.

Takes a C<DBIx::Connector> object and an EID. First, retrieves from the
database the employee object corresponding to that EID. Second, checks that
the employee's privlevel did not change during the tsrange. Third, retrieves
the prevailing schedule and checks that the schedule does not change at all
during the tsrange. Returns a status object.

=cut

sub _vet_employee {
    my $self = shift;
    my ( %ARGS ) = validate( @_, {
        dbix_conn => { isa => 'DBIx::Connector' },
        eid => { type => SCALAR },
    } );
    my $status;

    # load employee object from database into $self->{emp_obj}
    $status = App::Dochazka::REST::Model::Employee->load_by_eid( $ARGS{dbix_conn}, $ARGS{eid} );
    if ( $status->ok and $status->code eq 'DISPATCH_RECORDS_FOUND' ) {
        # all green
        $self->{'emp_obj'} = $status->payload;
        $self->eid( $status->payload->eid );
    } elsif ( $status->level eq 'NOTICE' and $status->code eq 'DISPATCH_NO_RECORDS_FOUND' ) {
        # non-existent employee
        return $CELL->status_err( 'DOCHAZKA_EMPLOYEE_EID_NOT_EXIST', args => [ $ARGS{eid} ] );
    } else {
        return $status;
    }

    # check for priv and schedule changes during the tsrange
    if ( $self->{'emp_obj'}->priv_change_during_range( $ARGS{dbix_conn}, $self->{tsrange} ) ) {
        return $CELL->status_err( 'DOCHAZKA_EMPLOYEE_PRIV_CHANGED' ); 
    }
    if ( $self->{'emp_obj'}->schedule_change_during_range( $ARGS{dbix_conn}, $self->{tsrange} ) ) {
        return $CELL->status_err( 'DOCHAZKA_EMPLOYEE_SCHEDULE_CHANGED' ); 
    }

    # get privhistory record prevailing at beginning of tsrange
    my $probj = $self->{emp_obj}->privhistory_at_timestamp( $ARGS{dbix_conn}, $self->{tsrange} );
    if ( ! $probj->priv ) {
        return $CELL->status_err( 'DISPATCH_EMPLOYEE_NO_PRIVHISTORY' );
    }
    if ( $probj->priv eq 'active' or $probj->priv eq 'admin' ) {
        # all green
    } else {
        return $CELL->status_err( 'DOCHAZKA_INSUFFICIENT_PRIVILEGE', args => [ $probj->priv ] );
    }

    # get schedhistory record prevailing at beginning of tsrange
    my $shobj = $self->{emp_obj}->schedhistory_at_timestamp( $ARGS{dbix_conn}, $self->{tsrange} );
    if ( ! $shobj->sid ) {
        return $CELL->status_err( 'DISPATCH_EMPLOYEE_NO_SCHEDULE' );
    }
    my $sched_obj = App::Dochazka::REST::Model::Schedule->load_by_sid(
        $ARGS{dbix_conn},
        $shobj->sid
    )->payload;
    die "AGAHO-NO!" unless ref( $sched_obj) eq 'App::Dochazka::REST::Model::Schedule'
        and $sched_obj->schedule =~ m/high_dow/;
    $self->{'sched_obj'} = $sched_obj;

    return $CELL->status_ok( 'SUCCESS' );
}


=head2 _vet_activity

Takes a C<DBIx::Connector> object and an AID. Verifies that the AID exists
and populates the C<activity_obj> attribute.

=cut

sub _vet_activity {
    my $self = shift;
    my ( %ARGS ) = validate( @_, {
        dbix_conn => { isa => 'DBIx::Connector' },
        aid => { type => SCALAR, optional => 1 },
    } );
    my $status;

    if ( exists( $ARGS{aid} ) ) {
        # load activity object from database into $self->{act_obj}
        $status = App::Dochazka::REST::Model::Activity->load_by_aid( $ARGS{dbix_conn}, $ARGS{aid} );
        if ( $status->ok and $status->code eq 'DISPATCH_RECORDS_FOUND' ) {
            # all green; fall thru to success
            $self->{'act_obj'} = $status->payload;
            $self->aid( $status->payload->aid );
        } elsif ( $status->level eq 'NOTICE' and $status->code eq 'DISPATCH_NO_RECORDS_FOUND' ) {
            # non-existent activity
            return $CELL->status_err( 'DOCHAZKA_GENERIC_NOT_EXIST', args => [ 'activity', 'AID', $ARGS{aid} ] );
        } else {
            return $status;
        }
    } else {
        # if no aid given, try to look up "WORK"
        $status = App::Dochazka::REST::Model::Activity->load_by_code( $ARGS{dbix_conn}, 'WORK' );
        if ( $status->ok and $status->code eq 'DISPATCH_RECORDS_FOUND' ) {
            # all green; fall thru to success
            $self->{'act_obj'} = $status->payload;
            $self->aid( $status->payload->aid );
        } elsif ( $status->level eq 'NOTICE' and $status->code eq 'DISPATCH_NO_RECORDS_FOUND' ) {
            return $CELL->status_err( 'DOCHAZKA_GENERIC_NOT_EXIST', args => [ 'activity', 'code', 'WORK' ] );
        } else {
            return $status;
        }
    }

    return $CELL->status_ok( 'SUCCESS' );
}


=head2 _fillup

Takes a C<DBIx::Connector> object. In
addition, it optionally takes an C<include_holidays> boolean flag, which
defaults to 0. This method expects to be called after C<_vet_tsrange>. 

This method attempts to INSERT records into the tempintvls table according to
the tsrange and the employee's schedule.  Returns a status object.

=cut

sub _fillup {
    my $self = shift;
    my ( %ARGS ) = validate( @_, {
        conn => { isa => 'DBIx::Connector' },
        eid => { type => SCALAR },
        aid => { type => SCALAR },
        tsrange => { type => SCALAR },
        include_holidays => { type => SCALAR, default => 0 },
    } );
    my $status;
    my $holidays;
    if ( ! $ARGS{'include_holidays'} ) {
        $holidays = holidays_in_daterange( 
            begin => $self->{low},
            end => $self->{upp},
        );
    }

    # the insert operation needs to take place within a transaction
    # so we don't leave a mess behind if there is a problem
    try {
        $ARGS{conn}->txn( fixup => sub {
            my $sth = $_->prepare( $site->SQL_TEMPINTVLS_INSERT );
            my $intvls;

            # the next sequence value is already in $self->{ssid}
            $sth->bind_param( 1, $self->{ssid} );

            # execute SQL_TEMPINTVLS_INSERT for each element of $self->{intvls}
            map {
                $sth->bind_param( 2, $_ );
                $sth->execute;
                push @$intvls, $_;
            } @{ $self->{intvls} };
            $status = $CELL->status_ok( 
                'DOCHAZKA_TEMPINTVLS_INSERT_OK', 
                payload => {
                    intervals => $intvls,
                    ssid => $self->{ssid},
                }
            );
        } );
    } catch {
        $status = $CELL->status_err( 'DOCHAZKA_DBI_ERR', args => [ $_ ] );
    };
    return $status;
}


=head2 update

There is no update method for tempintvls. Instead, delete and re-create.


=head2 delete

Instance method. Once we are done with the scratch intervals, they can be deleted.
Returns a status object.

=cut

sub delete {
    my $self = shift;
    my ( $conn ) = validate_pos( @_,
        { isa => 'DBIx::Connector' }
    );

    my $status;
    try {
        $conn->run( fixup => sub {
            my $sth = $_->prepare( $site->SQL_TEMPINTVLS_DELETE );
            $sth->bind_param( 1, $self->ssid );
            $sth->execute;
            my $rows = $sth->rows;
            if ( $rows > 0 ) {
                $status = $CELL->status_ok( 'DOCHAZKA_RECORDS_DELETED', args => [ $rows ] );
            } elsif ( $rows == 0 ) {
                $status = $CELL->status_warn( 'DOCHAZKA_RECORDS_DELETED', args => [ $rows ] );
            } else {
                die( "\$sth->rows returned a weird value $rows" );
            }
        } );
    } catch {
        $status = $CELL->status_err( 'DOCHAZKA_DBI_ERR', args => [ $_ ] );
    };
    return $status;
}





=head1 FUNCTIONS

=head2 _next_tiid

Get next value from the temp_intvl_seq sequence

=cut

sub _next_tiid {
    my $val;
    my $status;
    try {
        $dbix_conn->run( fixup => sub {
            ( $val ) = $_->selectrow_array( $site->SQL_NEXT_TIID );
        } );    
    } catch {
        $status = $CELL->status_err( 'DOCHAZKA_DBI_ERR', args => [ $_ ] );
    };
    if ( $status ) {
        $log->crit( $status->text );
        return;
    }
    return $val;
}



=head1 AUTHOR

Nathan Cutler, C<< <presnypreklad@gmail.com> >>

=cut 

1;

