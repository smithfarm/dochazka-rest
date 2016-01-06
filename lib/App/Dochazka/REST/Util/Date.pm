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

package App::Dochazka::REST::Util::Date;

use 5.012;
use strict;
use warnings;

use App::CELL qw( $CELL $log );
use Date::Calc qw(
    Add_Delta_Days
    Date_to_Days
);




=head1 NAME

App::Dochazka::REST::Util::Date - module containing miscellaneous date routines




=head1 SYNOPSIS

    use App::Dochazka::REST::Util::Date;

    ...




=head1 EXPORTS

=cut 

use Exporter qw( import );
our @EXPORT_OK = qw( 
    calculate_hours
    canon_date_diff
    canon_to_ymd
    tsrange_to_dates_and_times
    ymd_to_canon
);




=head1 FUNCTIONS


=head2 calculate_hours

Given a canonicalized tsrange, return the number of hours. For example, if
the range is [ 2016-01-06 08:00, 2016-01-06 09:00 ), the return value will
be 1. If the range is [ 2016-01-06 08:00, 2016-01-07 09:00 ), the return
value will 25.

=cut

sub calculate_hours {
    my $tsr = shift;

    my ( $begin_date, $begin_time, $end_date, $end_time ) = 
        $tsr =~ m/(\d{4}-\d{2}-\d{2}).+(\d{2}:\d{2}):\d{2}.+(\d{4}-\d{2}-\d{2}).+(\d{2}:\d{2}):\d{2}/a;

    my $days = canon_date_diff( $begin_date, $end_date );

    if ( $days == 0 ) {
        return single_day_hours( $begin_time, $end_time )
    }
    
    return single_day_hours( $begin_time, '24:00' ) +
           ( ( $days - 1 ) * 24 ) +
           single_day_hours( '00:00', $end_time );
}

=head3 single_day_hours

Given two strings in the format HH:MM representing a starting and an ending
time, calculate and return the number of hours.

=cut

sub single_day_hours {
    my ( $begin, $end ) = @_;
    my ( $bh, $begin_minutes ) = $begin =~ m/(\d+):(\d+)/a;
    my $begin_hours = $bh + $begin_minutes / 60;
    my ( $eh, $end_minutes ) = $end =~ m/(\d+):(\d+)/a;
    my $end_hours = $eh + $end_minutes / 60;
    return $end_hours - $begin_hours;
}


=head2 canon_date_diff

Compute difference (in days) between two canonical dates

=cut

sub canon_date_diff {
    my ( $date, $date1 ) = @_;
    my ( $date_days, $date1_days ) = (
        Date_to_Days( canon_to_ymd( $date ) ),
        Date_to_Days( canon_to_ymd( $date1 ) ),
    );
    return abs( $date_days - $date1_days );
}


=head2 canon_to_ymd

Takes canonical date YYYY-MM-DD and returns $y, $m, $d

=cut

sub canon_to_ymd {
    my ( $date ) = @_;
    return unless $date;

    return ( $date =~ m/(\d+)-(\d+)-(\d+)/ );
}


=head2 tsrange_to_dates_and_times

Takes a string that might be a canonicalized tsrange. Attempts to extract
beginning and ending dates (YYYY-MM-DD) from it. If this succeeds, an OK status
object is returned, the payload of which is a hash suitable for passing to
holidays_and_weekends().

=cut

sub tsrange_to_dates_and_times {
    my ( $tsrange ) = @_;

    my ( $begin_date, $begin_time, $end_date, $end_time ) = 
        $tsrange =~ m/(\d{4}-\d{2}-\d{2}).+(\d{2}:\d{2}):\d{2}.+(\d{4}-\d{2}-\d{2}).+(\d{2}:\d{2}):\d{2}/a;

    # if begin_time is 24:00 convert it to 00:00
    if ( $begin_time eq '24:00' ) {
        my ( $y, $m, $d ) = canon_to_ymd( $begin_date );
        $log->debug( "Before Add_Delta_Days $y $m $d" );
        ( $y, $m, $d ) = Add_Delta_Days( $y, $m, $d, 1 );
        $begin_date = ymd_to_canon( $y, $m, $d );
    }
    # if end_time is 00:00 convert it to 24:00
    if ( $end_time eq '00:00' ) {
        my ( $y, $m, $d ) = canon_to_ymd( $end_date );
        $log->debug( "Before Add_Delta_Days $y-$m-$d" );
        ( $y, $m, $d ) = Add_Delta_Days( $y, $m, $d, -1 );
        $end_date = ymd_to_canon( $y, $m, $d );
    }

    return $CELL->status_ok( 'DOCHAZKA_NORMAL_COMPLETION',
        payload => { begin => [ $begin_date, $begin_time ], 
                     end => [ $end_date, $end_time ] } );
}


=head2 ymd_to_canon

Takes $y, $m, $d and returns canonical date YYYY-MM-DD

=cut

sub ymd_to_canon {
    my ( $y, $m, $d ) = @_;

    if ( $y < 1 or $y > 9999 or $m < 1 or $m > 99 or $d < 1 or $d > 99 ) {
        die "AUCKLANDERS! ymd out of range!!";
    }

    return sprintf( "%04d-%02d-%02d", $y, $m, $d );
}


1;
