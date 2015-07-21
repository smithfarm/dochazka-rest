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

package App::Dochazka::REST::Util::Schedule;

use 5.012;
use strict;
use warnings FATAL => 'all';
use App::CELL qw( $CELL $log );
use Data::Dumper;
use Date::Calc qw(
    Add_Delta_Days
    check_date
    Date_to_Days
    Day_of_Week
);
use Exporter qw( import );
use JSON;




=head1 NAME

App::Dochazka::REST::Util::Schedule - schedule-related utilities 




=head1 SYNOPSIS

Schedule-related utilities

    use App::Dochazka::REST::Util::Schedule;

    ...


=head1 EXPORTS AND PACKAGE VARIABLES

=cut

our @EXPORT_OK = qw( 
    intervals_in_schedule
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





=head1 FUNCTIONS


=head2 sched_entry_to_tsrange

Given a canonical date and a schedule entry (hash with keys "dow_low", etc.)
return a tsrange string for that entry

=cut

sub sched_entry_to_tsrange {
    my ( $canon_lower, $entry ) = @_;
    my ( $ly, $lm, $ld ) = Days_to_Date( $canon_lower );
    # get canonical representation of upper DOW
    my $canon_upper = $canon_lower + 
        ( $dow_to_num{ $entry->{'high_dow'} } - $dow_to_num{ $entry->{'low_dow'} } );
    my ( $uy, $um, $ud ) = Days_to_Date( $canon_upper );
    return "[ $ly-$lm-$ld " . $entry->{'low_time'} . 
           ", $uy-$um-$ud " . $entry->{'high_time'} . " )";
}


=head2 Days_to_Date

Missing function in L<Date::Calc>

=cut

sub Days_to_Date {
    my $canonical = shift;
    my ( $year, $month, $day ) = Add_Delta_Days(1,1,1, $canonical - 1);
    return ( $year, $month, $day );
}


=head2 intervals_in_schedule

Given a schedule (JSON string) and a tsrange, return a status object.
If the status code is OK, the payload will contain the set of scheduled
work intervals that fall completely within the tsrange. Otherwise, there
is some kind of error.

=cut

sub intervals_in_schedule {
    my ( $rest_sched_json, $tsrange ) = @_;
    $log->debug( "Entering " . __PACKAGE__ . "::intervals_in_schedule" );
    $log->debug( "Schedule (JSON): $rest_sched_json" );

    my $rest_sched_hash_lower = _init_lower_sched_hash( $rest_sched_json );
    #$log->debug( "Schedule re-keyed: " . Dumper( $rest_sched_hash_lower ) );

    # deconstruct the tsrange
    my ( $ly, $lm, $ld, $uy, $um, $ud ) = $tsrange =~ m/(\d+)-(\d+)-(\d+).*,.*?(\d+)-(\d+)-(\d+)/;
    $log->debug( "tsrange: $tsrange" );
    $log->debug( "deconstructed: $ly $lm $ld, $uy, $um, $ud" );

    # sanity check
    return $CELL->status_err( 'DOCHAZKA_BAD_TSRANGE', args => [ $tsrange ] )
        unless ( 
            ( $ly && $lm && $ld && $uy && $um && $ud ) and
            ( check_date( $ly, $lm, $ld ) ) and 
            ( check_date( $uy, $um, $ud ) ) 
        );

    # get canonical representations
    my ( $canon_lower, $canon_upper ) = (
        Date_to_Days( $ly, $lm, $ld ),
        Date_to_Days( $uy, $um, $ud ),
    );

    $log->debug( "canon_lower is $canon_lower, canon_upper is $canon_upper" );

    # more sanity: assert upper >= lower, and size of tsrange
    return $CELL->status_err( 'DOCHAZKA_BAD_TSRANGE', args => [ $tsrange ] )
        unless $canon_upper >= $canon_lower;
    return $CELL->status_err( 'DOCHAZKA_TSRANGE_TOO_BIG', args => [ $tsrange ] )
        unless ( $canon_upper - $canon_lower ) <= 365;

    # loop through the date range, incrementing lower by one day each time
    my $payload = [];
    while ( $canon_lower <= $canon_upper ) {
        my ( $y, $m, $d ) = Days_to_Date( $canon_lower );
        my $ndow = Day_of_Week( $y, $m, $d );

        # get schedule entries starting on that DOW, 
        # FIXME: provided the entry does not extend past the end of the date range!
        foreach my $entry ( @{ $rest_sched_hash_lower->{ $ndow } } ) {
            my ( $canon_high_dow, $hy, $hm, $hd );
            # get canonical representation of "high_dow"
            $canon_high_dow = $canon_lower + 
                ( $dow_to_num{ $entry->{'high_dow'} } - $dow_to_num{ $entry->{'low_dow'} } );
            if ( $canon_high_dow <= $canon_upper ) {
                ( $hy, $hm, $hd ) = Days_to_Date( $canon_high_dow );
                push @$payload, "[ $y-$m-$d " . $entry->{'low_time'} . 
                                ", $hy-$hm-$hd " . $entry->{'high_time'} . " )";
            }
        }
        $canon_lower += 1;
    }

    return $CELL->status_ok( 'DOCHAZKA_SCHEDULE_INTERVALS', payload => $payload );
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


1;
