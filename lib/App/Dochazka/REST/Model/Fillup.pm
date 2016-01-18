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

package App::Dochazka::REST::Model::Fillup;

use 5.012;
use strict;
use warnings;
use App::CELL qw( $CELL $log $meta $site );
use App::Dochazka::REST::ConnBank qw( $dbix_conn );
use App::Dochazka::REST::Model::Employee;
use App::Dochazka::REST::Model::Interval qw( 
    fetch_intervals_by_eid_and_tsrange 
);
use App::Dochazka::REST::Model::Shared qw(
    canonicalize_date
    canonicalize_tsrange
    cud_generic
    select_set_of_single_scalar_rows
    select_single
    split_tsrange
);
use App::Dochazka::REST::Holiday qw(
    canon_date_diff
    canon_to_ymd
    get_tomorrow
    holidays_in_daterange
    ymd_to_canon
);
use Data::Dumper;
use Date::Calc qw(
    Add_Delta_Days
    Date_to_Days
    Day_of_Week
    check_date
);
use JSON;
use Params::Validate qw( :all );
use Try::Tiny;

our @attr = qw(
    act_obj
    constructor_status
    context
    date_list
    emp_obj
    intervals
    long_desc
    remark
    tiid
    tsrange
);
my %dow_to_num = (
    'MON' => 1,
    'TUE' => 2,
    'WED' => 3,
    'THU' => 4,
    'FRI' => 5,
    'SAT' => 6,
    'SUN' => 7,
);
my %num_to_dow = reverse %dow_to_num;



=head1 NAME

App::Dochazka::REST::Model::Fillup - object class for "scratch schedules"




=head1 SYNOPSIS

    use App::Dochazka::REST::Model::Fillup;

    ...




=head1 METHODS


=head2 populate

Called automatically when new object is instantiated; assigns next TIID.

=cut

sub populate {
    my $self = shift;
    if ( ! exists( $self->{tiid} ) or ! defined( $self->{tiid} ) or $self->{tiid} == 0 ) {
        my $ss = _next_tiid();
        $log->info( "Got next TIID: $ss" );
        $self->{tiid} = $ss;
    }
    return;
}

=head2 reset

Since we add several (non-scalar) attributes, the inherited version of
C<reset> is not sufficient.

=cut

sub reset {
    # process arguments
    my $self = shift;
    $self->DESTROY;
    my $val_spec;
    map { $val_spec->{$_} = 0; } @attr;
    my %ARGS = validate( @_, $val_spec ) if @_ and defined $_[0];

    # Set attributes to run-time values sent in argument list.
    # Attributes that are not in the argument list will get set to undef.
    map { $self->{$_} = $ARGS{$_}; } @attr;

    # run the populate function, if any
    $self->populate() if $self->can( 'populate' );

    # return an appropriate throw-away value
    return;
}


=head2 Accessors

These accessors must be defined here because the boilerplate
accessors from L<App::Dochazka::Common> take only SCALAR and UNDEF as their
argument.

=cut

sub act_obj {
    my $self = shift;
    validate_pos( @_, { 
        type => HASHREF, 
        isa => 'App::Dochazka::REST::Model::Activity', 
        optional => 1 
    } );
    $self->{'act_obj'} = shift if @_;
    $self->{'act_obj'} = undef unless exists $self->{'act_obj'};
    return $self->{'act_obj'};
}

sub constructor_status {
    my $self = shift;
    validate_pos( @_, { 
        type => HASHREF,
        isa => 'App::CELL::Status',
        optional => 1 
    } );
    $self->{'constructor_status'} = shift if @_;
    $self->{'constructor_status'} = undef unless exists $self->{'constructor_status'};
    return $self->{'constructor_status'};
}

sub context {
    my $self = shift;
    validate_pos( @_, { 
        type => HASHREF, 
        optional => 1 } 
    );
    $self->{'context'} = shift if @_;
    $self->{'context'} = undef unless exists $self->{'context'};
    return $self->{'context'};
}

sub date_list {
    my $self = shift;
    validate_pos( @_, { 
        type => ARRAYREF,
        optional => 1 
    } );
    $self->{'date_list'} = shift if @_;
    $self->{'date_list'} = undef unless exists $self->{'date_list'};
    return $self->{'date_list'};
}

sub emp_obj {
    my $self = shift;
    validate_pos( @_, { 
        type => HASHREF, 
        isa => 'App::Dochazka::REST::Model::Employee', 
        optional => 1 
    } );
    $self->{'emp_obj'} = shift if @_;
    $self->{'emp_obj'} = undef unless exists $self->{'emp_obj'};
    return $self->{'emp_obj'};
}

sub intervals {
    my $self = shift;
    validate_pos( @_, { 
        type => ARRAYREF, 
        optional => 1 
    } );
    $self->{'intervals'} = shift if @_;
    $self->{'intervals'} = undef unless exists $self->{'intervals'};
    return $self->{'intervals'};
}

sub tsranges {
    my $self = shift;
    validate_pos( @_, { 
        type => ARRAYREF,
        optional => 1 
    } );
    $self->{'tsranges'} = shift if @_;
    $self->{'tsranges'} = undef unless exists $self->{'tsranges'};
    return $self->{'tsranges'};
}


=head2 _vet_context

Performs various tests on the C<context> attribute. If the value of that
attribute is not what we're expecting, returns a non-OK status. Otherwise,
returns an OK status.

=cut

sub _vet_context {
    my $self = shift;
    my %ARGS = @_;
    return $CELL->status_not_ok unless $ARGS{context};
    return $CELL->status_not_ok unless $ARGS{context}->{dbix_conn};
    return $CELL->status_not_ok unless $ARGS{context}->{dbix_conn}->isa('DBIx::Connector');
    $self->context( $ARGS{context} );
    $self->{'vetted'}->{'context'} = 1;
    return $CELL->status_ok;
}


=head2 _vet_date_spec

The user can specify fillup dates either as a tsrange or as a list of
individual dates.

One or the other must be given, not neither and not both.

Returns a status object.

=cut

sub _vet_date_spec {
    my $self = shift;
    my %ARGS = @_;
    $log->debug( "Entering " . __PACKAGE__ . "::_vet_date_spec to enforce date specification policy" );

    if ( defined( $ARGS{date_list} ) and defined( $ARGS{tsrange} ) ) {
        return $CELL->status_not_ok;
    }
    if ( ! defined( $ARGS{date_list} ) and ! defined( $ARGS{tsrange} ) ) {
        return $CELL->status_not_ok;
    }
    $self->{'vetted'}->{'date_spec'} = 1;
    return $CELL->status_ok;
}


=head2 _vet_date_list

This function takes one named argument: date_list, the value of which must
be a reference to an array of dates, each in canonical YYYY-MM-DD form. For
example, this

    [ '2016-01-13', '2016-01-27', '2016-01-14' ]

is a legal C<date_list> argument.

This function performs various checks on the date list, sorts it, and
populates the C<tsrange> and C<tsranges> attributes based on it. For the
sample date list given above, the tsrange will be C<[ 2016-01-13 00:00,
2016-01-27 24:00 )>. This is used to make sure the employee's schedule
and priv level did not change during the time period represented by the 
date list.

Returns a status object.

=cut

sub _vet_date_list {
    my $self = shift;
    my ( %ARGS ) = validate( @_, {
        date_list => { type => ARRAYREF|UNDEF },
    } );
    $log->debug( "Entering " . __PACKAGE__ . "::_vet_date_list to vet/populate the date_list property" );

    die "GOPHFQQ! tsrange property must not be populated in _vet_date_list()" if $self->tsrange;

    return $CELL->status_ok if not defined( $ARGS{date_list} );
    return $CELL->status_err( 'DOCHAZKA_EMPTY_DATE_LIST' ) if scalar( @{ $ARGS{date_list} } ) == 0;

    # check that dates are valid and in canonical form
    my @canonicalized_date_list = ();
    foreach my $date ( @{ $ARGS{date_list} } ) {
        my ( $y, $m, $d ) = canon_to_ymd( $date );
        if ( ! check_date( $y, $m, $d ) ) {
            return $CELL->status_err( 
                "DOCHAZKA_INVALID_DATE_IN_DATE_LIST",
                args => [ $date ],
            );
        }
        push @canonicalized_date_list, sprintf( "%04d-%02d-%02d", $y, $m, $d );
    }
    my @sorted_date_list = sort @canonicalized_date_list;
    $self->date_list( \@sorted_date_list );

    # populate tsrange
    if ( scalar @sorted_date_list == 0 ) {
        $self->tsrange( undef );
    } elsif ( scalar @sorted_date_list == 1 ) {
        my $t = "[ $sorted_date_list[0] 00:00, $sorted_date_list[0] 24:00 )";
        my $status = canonicalize_tsrange( $self->context->{dbix_conn}, $t );
        return $status unless $status->ok;
        $self->tsrange( $status->payload );
    } else {
        my $t = "[ $sorted_date_list[0] 00:00, $sorted_date_list[-1] 24:00 )";
        my $status = canonicalize_tsrange( $self->context->{dbix_conn}, $t );
        return $status unless $status->ok;
        $self->tsrange( $status->payload );
    }

    # populate tsranges
    if ( scalar @sorted_date_list == 0 ) {
        $self->tsranges( undef );
    } else {
        my @tsranges = ();
        foreach my $date ( @sorted_date_list ) {
            my $t = "[ $date 00:00, $date 24:00 )";
            my $status = canonicalize_tsrange(
                $self->context->{dbix_conn},
                $t,
            );
            return $status unless $status->ok;
            # push canonicalized tsrange onto result stack
            push @tsranges, { tsrange => $status->payload };
        }
        $self->tsranges( \@tsranges );
    }
 
    $self->{'vetted'}->{'date_list'} = 1;
    return $CELL->status_ok; 
}


=head2 _vet_tsrange

Takes constructor arguments. Checks the tsrange for sanity and populates
the C<tsrange>, C<lower_canon>, C<lower_ymd>, C<upper_canon>, C<upper_ymd>
attributes. Returns a status object.

=cut

sub _vet_tsrange {
    my $self = shift;
    my %ARGS = @_;
    $log->debug( "Entering " . __PACKAGE__ . "::_vet_tsrange to vet the tsrange $ARGS{tsrange}" );

    die "YAHOOEY! No DBIx::Connector in object" unless $self->context->{dbix_conn};

    # if a tsrange property was given in the arguments, that means no
    # date_list was given: convert the tsrange argument into an arrayref
    if ( my $t = $ARGS{tsrange} ) {
        my $status = canonicalize_tsrange(
            $self->context->{dbix_conn},
            $t,
        );
        return $status unless $status->ok;
        $self->tsrange( $status->payload );
        $self->tsranges( [ { tsrange => $status->payload } ] );
    }

    foreach my $t_hash ( @{ $self->tsranges } ) {

        # split the tsrange
        my @parens = $t_hash->{tsrange} =~ m/[^\[(]*([\[(])[^\])]*([\])])/;
        my $status = split_tsrange( $self->context->{'dbix_conn'}, $t_hash->{tsrange} );
        $log->info( "split_tsrange() returned: " . Dumper( $status ) );
        return $status unless $status->ok;
        my $low = $status->payload->[0];
        my $upp = $status->payload->[1];
        $t_hash->{'tsrange'} = "$parens[0] $low, $upp $parens[1]";
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

        $t_hash->{'lower_ymd'} = \@low;
        $t_hash->{'upper_ymd'} = \@upp;
        $t_hash->{'lower_canon'} = $low;
        $t_hash->{'upper_canon'} = $upp;
    }

    $self->{'vetted'}->{'tsrange'} = 1;
    return $CELL->status_ok( 'SUCCESS' );
}


=head2 _vet_employee

Expects to be called *after* C<_vet_tsrange>.

Takes an employee object. First, retrieves
from the database the employee object corresponding to the EID. Second,
checks that the employee's privlevel did not change during the tsrange.
Third, retrieves the prevailing schedule and checks that the schedule does
not change at all during the tsrange. Returns a status object.

=cut

sub _vet_employee {
    my $self = shift;
    my ( %ARGS ) = validate( @_, {
        emp_obj => { 
            type => HASHREF, 
            isa => 'App::Dochazka::REST::Model::Employee', 
        },
    } );
    my $status;

    die 'AKLDWW###%AAAAAH!' unless $ARGS{emp_obj}->eid;
    $self->{'emp_obj'} = $ARGS{emp_obj};

    # check for priv and schedule changes during the tsrange
    if ( $self->{'emp_obj'}->priv_change_during_range( 
        $self->context->{'dbix_conn'}, 
        $self->tsrange,
    ) ) {
        return $CELL->status_err( 'DOCHAZKA_EMPLOYEE_PRIV_CHANGED' ); 
    }
    if ( $self->{'emp_obj'}->schedule_change_during_range(
        $self->context->{'dbix_conn'}, 
        $self->tsrange,
    ) ) {
        return $CELL->status_err( 'DOCHAZKA_EMPLOYEE_SCHEDULE_CHANGED' ); 
    }

    # get privhistory record prevailing at beginning of tsrange
    my $probj = $self->{emp_obj}->privhistory_at_timestamp( 
        $self->context->{'dbix_conn'}, 
        $self->tsrange
    );
    if ( ! $probj->priv ) {
        return $CELL->status_err( 'DISPATCH_EMPLOYEE_NO_PRIVHISTORY' );
    }
    if ( $probj->priv eq 'active' or $probj->priv eq 'admin' ) {
        # all green
    } else {
        return $CELL->status_err( 'DOCHAZKA_INSUFFICIENT_PRIVILEGE', args => [ $probj->priv ] );
    }

    # get schedhistory record prevailing at beginning of tsrange
    my $shobj = $self->{emp_obj}->schedhistory_at_timestamp( 
        $self->context->{'dbix_conn'}, 
        $self->tsrange
    );
    if ( ! $shobj->sid ) {
        return $CELL->status_err( 'DISPATCH_EMPLOYEE_NO_SCHEDULE' );
    }
    my $sched_obj = App::Dochazka::REST::Model::Schedule->load_by_sid(
        $self->context->{'dbix_conn'},
        $shobj->sid,
    )->payload;
    die "AGAHO-NO!" unless ref( $sched_obj) eq 'App::Dochazka::REST::Model::Schedule'
        and $sched_obj->schedule =~ m/high_dow/;
    $self->{'sched_obj'} = $sched_obj;

    $self->{'vetted'}->{'employee'} = 1;
    return $CELL->status_ok( 'SUCCESS' );
}


=head2 _vet_activity

Takes a C<DBIx::Connector> object and an AID. Verifies that the AID exists
and populates the C<activity_obj> attribute.

=cut

sub _vet_activity {
    my $self = shift;
    my ( %ARGS ) = validate( @_, {
        aid => { type => SCALAR|UNDEF, optional => 1 },
    } );
    my $status;

    if ( exists( $ARGS{aid} ) and defined( $ARGS{aid} ) ) {
        # load activity object from database into $self->{act_obj}
        $status = App::Dochazka::REST::Model::Activity->load_by_aid( 
            $self->context->{'dbix_conn'}, 
            $ARGS{aid}
        );
        if ( $status->ok and $status->code eq 'DISPATCH_RECORDS_FOUND' ) {
            # all green; fall thru to success
            $self->{'act_obj'} = $status->payload;
            $self->{'aid'} = $status->payload->aid;
        } elsif ( $status->level eq 'NOTICE' and $status->code eq 'DISPATCH_NO_RECORDS_FOUND' ) {
            # non-existent activity
            return $CELL->status_err( 'DOCHAZKA_GENERIC_NOT_EXIST', args => [ 'activity', 'AID', $ARGS{aid} ] );
        } else {
            return $status;
        }
    } else {
        # if no aid given, try to look up "WORK"
        $status = App::Dochazka::REST::Model::Activity->load_by_code( 
            $self->context->{'dbix_conn'},
            'WORK'
        );
        if ( $status->ok and $status->code eq 'DISPATCH_RECORDS_FOUND' ) {
            # all green; fall thru to success
            $self->{'act_obj'} = $status->payload;
            $self->{'aid'} = $status->payload->aid;
        } elsif ( $status->level eq 'NOTICE' and $status->code eq 'DISPATCH_NO_RECORDS_FOUND' ) {
            return $CELL->status_err( 'DOCHAZKA_GENERIC_NOT_EXIST', args => [ 'activity', 'code', 'WORK' ] );
        } else {
            return $status;
        }
    }

    $self->{'vetted'}->{'activity'} = 1;
    return $CELL->status_ok( 'SUCCESS' );
}


=head2 vetted

Returns boolean true if object has been completely vetted. Otherwise false.

=cut

sub vetted {
    my $self = shift;
    ( 
        $self->{'vetted'}->{'tsrange'} and 
        $self->{'tsrange'} and
        $self->{'vetted'}->{'employee'} and 
        $self->emp_obj and
        ref( $self->emp_obj ) eq 'App::Dochazka::REST::Model::Employee' and
        $self->{'vetted'}->{'activity'} and
        $self->act_obj and
        ref( $self->act_obj ) eq 'App::Dochazka::REST::Model::Activity'
    ) ? 1 : 0;
}


=head2 fillup

This method takes no arguments and expects to be called on a fully vetted
object (see C<vetted>, above).

This method attempts to INSERT records into the Fillup table according to
the tsrange and the employee's schedule.  Returns a status object.

Note that this method does not create any attendance intervals. If the fillup
operation is successful, the payload will contain a list of attendance
intervals that will be created if the C<commit> method is called.

=cut

sub fillup {
    my $self = shift;

    die "ARG_NOT_VETTED" unless $self->vetted;

    my $rest_sched_hash_lower = _init_lower_sched_hash( $self->{sched_obj}->schedule );

    my $status;
    my @pushed_intervals;
    foreach my $t_hash ( @{ $self->tsranges } ) {

        my $holidays = holidays_in_daterange(
            'begin' => $t_hash->{lower_canon},
            'end' => $t_hash->{upper_canon},
        );

        # the insert operation needs to take place within a transaction
        # so we don't leave a mess behind if there is a problem
        try {
            $self->context->{'dbix_conn'}->txn( fixup => sub {
                my $sth = $_->prepare( $site->SQL_Fillup_INSERT );
                my $intvls;

                # the next sequence value is already in $self->tiid
                $sth->bind_param( 1, $self->tiid );

                # execute SQL_Fillup_INSERT for each fillup interval
                my $d = $t_hash->{'lower_canon'};
                my $days_upper = Date_to_Days( @{ $t_hash->{upper_ymd} } );
                WHILE_LOOP: while ( $d ne get_tomorrow( $t_hash->{'upper_canon'} ) ) {
                    if ( _is_holiday( $d, $holidays ) ) {
                        $d = get_tomorrow( $d );
                        next WHILE_LOOP;
                    }
                    my ( $ly, $lm, $ld ) = canon_to_ymd( $d );
                    my $days_lower = Date_to_Days( $ly, $lm, $ld );
                    my $ndow = Day_of_Week( $ly, $lm, $ld );

                    # get schedule entries starting on that DOW
                    foreach my $entry ( @{ $rest_sched_hash_lower->{ $ndow } } ) {
                        my ( $days_high_dow, $hy, $hm, $hd );
                        # convert "high_dow" into a number of days
                        $days_high_dow = $days_lower + 
                            ( $dow_to_num{ $entry->{'high_dow'} } - $dow_to_num{ $entry->{'low_dow'} } );
                        if ( $days_high_dow <= $days_upper ) {
                            ( $hy, $hm, $hd ) = Days_to_Date( $days_high_dow );
                            my $payl = "[ " . ymd_to_canon( $ly,$lm,$ld ) . " " . $entry->{'low_time'} . 
                                       ", " . ymd_to_canon( $hy,$hm,$hd ) . " ". $entry->{'high_time'} . " )";
                            $sth->bind_param( 2, $payl );
                            $sth->execute;
                            push @$intvls, $payl;
                        }
                    }
                    $d = get_tomorrow( $d );
                }

                $status = $CELL->status_ok( 
                    'DOCHAZKA_Fillup_INSERT_OK', 
                    payload => $intvls,
                );
            } );
        } catch {
            $status = $CELL->status_err( 'DOCHAZKA_DBI_ERR', args => [ $_ ] );
        };
        return $status unless $status->ok;
        push @pushed_intervals, @{ $status->payload };
    }
    $status = $CELL->status_ok( 
        'DOCHAZKA_Fillup_INSERT_OK', 
        payload => {
            intervals => \@pushed_intervals,
            tiid => $self->tiid,
        }
    );

    return $status;
}


=head2 new

Constructor method. Returns an C<App::Dochazka::REST::Model::Fillup>
object.

The constructor method does everything up to C<fillup>. It also populates the
C<constructor_status> attribute with an C<App::CELL::Status> object.

=cut

sub new {
    my $class = shift;
    my ( %ARGS ) = validate( @_, {
        context => { type => HASHREF },
        emp_obj => { 
            type => HASHREF,
            isa => 'App::Dochazka::REST::Model::Employee', 
        },
        aid => { type => SCALAR|UNDEF, optional => 1 },
        code => { type => SCALAR|UNDEF, optional => 1 },
        tsrange => { type => SCALAR|UNDEF, optional => 1 },
        date_list => { type => SCALAR|UNDEF, optional => 1 },
        long_desc => { type => SCALAR|UNDEF, optional => 1 },
        remark => { type => SCALAR|UNDEF, optional => 1 },
        clobber => { type => BOOLEAN, default => 0 },
        dry_run => { type => BOOLEAN, default => 0 },
    } );
    my ( $self, $status );

    # (re-)initialize $self
    if ( $class eq __PACKAGE__ ) {
        $self = bless {}, $class;
        $self->populate();
    } else {
        die "AGHOOPOWDD@! Constructor must be called like this App::Dochazka::REST::Model::Fillup->new()";
    }
    die "AGHOOPOWDD@! No tiid in Fillup object!" unless $self->tiid;

    # the order of the following checks is significant!
    $self->constructor_status( $self->_vet_context( context => $ARGS{context} ) );
    return $self unless $self->constructor_status->ok;
    $self->constructor_status( $self->_vet_date_spec( %ARGS ) );
    return $self unless $self->constructor_status->ok;
    $self->constructor_status( $self->_vet_date_list( date_list => $ARGS{date_list} ) );
    return $self unless $self->constructor_status->ok;
    $self->constructor_status( $self->_vet_tsrange( %ARGS ) );
    return $self unless $self->constructor_status->ok;
    $self->constructor_status( $self->_vet_employee( emp_obj => $ARGS{emp_obj} ) );
    return $self unless $self->constructor_status->ok;
    $self->constructor_status( $self->_vet_activity( aid => $ARGS{aid} ) );
    return $self unless $self->constructor_status->ok;
    die "AGHGCHKFSCK! should be vetted by now!" unless $self->vetted;

    $self->constructor_status( $self->fillup );
    return $self unless $self->constructor_status->ok;

    return $self;
}


=head2 dump

Takes a PARAMHASH containing a C<DBIx::Connector> object and a C<tiid> 
property. Returns all intervals matching that C<tiid>.

=cut

sub dump {
    my $self = shift;
    my ( %ARGS ) = validate( @_, {
        tiid => { type => SCALAR },
    } );
    my $status;

    $status = select_set_of_single_scalar_rows(
        conn => $self->context->{'dbix_conn'},
        sql => $site->SQL_Fillup_SELECT,
        keys => [ $ARGS{tiid} ],
    );
    return $status;
}


=head2 commit

Optionally takes a PARAMHASH containing, optionally, a C<dry_run> boolean value
that defaults to 0.

If C<dry_run> is true, merely SELECTs intervals from the Fillup table
corresponding to the tsrange (already vetted and stored in the object by
calling C<_vet_tsrange>). This SELECT includes partial intervals (if any) at
the beginning and end of the tsrange (using PostgreSQL intersection operator).

If C<dry_run> is false, all the intervals from the SELECT are INSERTed into the
intervals table.

=cut

sub commit {
    my $self = shift;
    my ( %ARGS ) = validate( @_, {
        dry_run => { type => SCALAR|UNDEF, default => 0 },
    } );
    my $status;
    my $dry_run = $ARGS{dry_run} ? 1 : 0;
    my $next = App::Dochazka::REST::Model::Fillup->spawn;
    die 'AGCKDSWQ#$L! newly spawned Fillup object has no TIID?' unless $next->tiid;

    # write the rows
    $status = cud_generic(
        conn => $self->context->{'dbix_conn'},
        eid => $self->emp_obj->eid,
        sql => $site->SQL_Fillup_COMMIT,
        bind_params => [ 
            $next->tiid, $self->tiid, $self->{tsrange},
            $next->tiid, $self->tiid, $self->{tsrange},
            $next->tiid, $self->tiid, $self->{tsrange},
        ],
    );
    goto WRAPUP unless $status->ok;

    # get the rows we just wrote
    $status = select_set_of_single_scalar_rows(
        conn => $self->context->{'dbix_conn'},
        sql => $site->SQL_Fillup_SELECT_COMMITTED,
        keys => [ $next->tiid ],
    );
    my $fillup_intervals = $status->payload;
    my $count = defined( $fillup_intervals )
        ? @$fillup_intervals
        : 0;
    if ( $dry_run ) {
        $status->{'count'} = $count;
        return $status;
    }
    goto WRAPUP unless $status->ok;
    
    # write intervals to database
    $status = undef;
    try {
        $self->context->{'dbix_conn'}->txn( fixup => sub {
            map {
                my $int = App::Dochazka::REST::Model::Interval->spawn(
                    eid => $self->emp_obj->eid,
                    aid => $self->act_obj->aid,
                    intvl => $_,
                    remark => 'fillup',
                );
                $status = $int->insert( $self->context );
                die $status->text unless $status->ok;
            } @{ $fillup_intervals };
        } );
    } catch {
        $status = $CELL->status_err( 'DOCHAZKA_DBI_ERR', args => [ $_ ] );
    };

WRAPUP:
    # cleanup internal working object $next
    $next->DESTROY;
    return $status unless $status->ok;
    return $CELL->status_ok( 'DOCHAZKA_Fillup_COMMITTED', count => $count );
}


=head2 update

There is no update method for Fillup. Instead, delete and re-create.


=head2 DESTROY

Instance destructor. Once we are done with the scratch intervals, they can be deleted.
Returns a status object.

=cut

sub DESTROY {
    my $self = shift;

    my $status;
    try {
        $dbix_conn->run( fixup => sub {
            my $sth = $_->prepare( $site->SQL_Fillup_DELETE );
            $sth->bind_param( 1, $self->tiid );
            $sth->execute;
            my $rows = $sth->rows;
            if ( $rows > 0 ) {
                $status = $CELL->status_ok( 'DOCHAZKA_RECORDS_DELETED', args => [ $rows ], count => $rows );
            } elsif ( $rows == 0 ) {
                $status = $CELL->status_warn( 'DOCHAZKA_RECORDS_DELETED', args => [ $rows ], count => $rows );
            } else {
                die( "\$sth->rows returned a weird value $rows" );
            }
        } );
    } catch {
        $status = $CELL->status_err( 'DOCHAZKA_DBI_ERR', args => [ $_ ] );
    };
    $log->notice( "Fillup destructor says " . $status->level . ": " . $status->text );
    return;
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


=head2 Days_to_Date

Missing function in L<Date::Calc>

=cut

sub Days_to_Date {
    my $canonical = shift;
    my ( $year, $month, $day ) = Add_Delta_Days(1,1,1, $canonical - 1);
    return ( $year, $month, $day );
}


=head2 _init_lower_sched_hash 

Given schedule hash (JSON string from database), return schedule
hash keyed on the "low_dow" property. In other words, convert the
schedule to hash format keyed on numeric form of "low_dow" i.e. 1 for
MON, 2 for TUE, etc. The values are references to arrays containing
the entries beginning on the given DOW.

=cut

sub _init_lower_sched_hash {
    my $rest_sched_json = shift;

    # initialize
    my $rest_sched_hash_lower = {};
    foreach my $ndow ( 1 .. 7 ) {
        $rest_sched_hash_lower->{ $ndow } = [];
    }

    # fill up
    foreach my $entry ( @{ decode_json $rest_sched_json } ) {
        my $ndow = $dow_to_num{ $entry->{'low_dow'} };
        push @{ $rest_sched_hash_lower->{ $ndow } }, $entry;
    }

    return $rest_sched_hash_lower;
}


=head2 _is_holiday

Takes a date and a C<$holidays> hashref.  Returns true or false.

=cut

sub _is_holiday {
    my ( $datum, $holidays ) = @_;
    return exists( $holidays->{ $datum } );
}


=head2 fetch_intervals_by_tsranges

Return a set of intervals that fall within the tsranges.

=cut

sub fetch_intervals_by_tsranges {
    my $self = shift;

    my $status;
    my @result_set = ();

    for my $t_hash ( @{ $self->tsranges } ) {

        my $tsr = $t_hash->{'tsrange'};

        $status = load_multiple(
            conn => $self->context->{'dbix_conn'},
            class => 'App::Dochazka::REST::Model::Tempintvl',
            sql => $site->SQL_TEMPINTVL_SELECT_BY_TIID_AND_TSRANGE,
            keys => [ $self->tiid, $tsr, $site->DOCHAZKA_INTERVAL_SELECT_LIMIT ],
        );
        return $status unless 
            ( $status->ok and $status->code eq 'DISPATCH_RECORDS_FOUND' ) or
            ( $status->level eq 'NOTICE' and $status->code eq 'DISPATCH_NO_RECORDS_FOUND' );
        my $whole_intervals = $status->payload;

        $status = load_multiple(
            conn => $self->context->{'dbix_conn'},
            class => 'App::Dochazka::REST::Model::Tempintvl',
            sql => $site->SQL_TEMPINTVL_SELECT_BY_TIID_AND_TSRANGE_PARTIAL_INTERVALS,
            keys => [ $self->tiid, $tsr, $self->tiid, $tsr ],
        );
        return $status unless 
            ( $status->ok and $status->code eq 'DISPATCH_RECORDS_FOUND' ) or
            ( $status->level eq 'NOTICE' and $status->code eq 'DISPATCH_NO_RECORDS_FOUND' );
        my $partial_intervals = $status->payload;

        #map { $_->partial( 0 ) } ( @$whole_intervals );
        #foreach my $int ( @$partial_intervals ) {
        #    $int->partial( 1 );
        #    $int->intvl( tsrange_intersection( $self->context->{'dbix_conn'}, $tsrange, $int->intvl ) );
        #}
    
        my @result_set = @$whole_intervals;
        push @result_set, @$partial_intervals;
    }

    # But now the intervals are out of order
    my @sorted_results = sort { $a->intvl cmp $b->intvl } @result_set;

    if ( my $count = scalar @result_set ) {
        return $CELL->status_ok( 'DISPATCH_RECORDS_FOUND', 
            payload => \@sorted_results, count => $count, args => [ $count ] );
    }
    return $CELL->status_notice( 'DISPATCH_NO_RECORDS_FOUND' );
}


=head1 AUTHOR

Nathan Cutler, C<< <presnypreklad@gmail.com> >>

=cut 

1;

