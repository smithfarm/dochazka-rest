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

package App::Dochazka::REST::Util::Holiday;

use 5.012;
use strict;
use warnings;

use Date::Holidays::CZ qw( holidays );
use Params::Validate qw( :all );




=head1 NAME

App::Dochazka::REST::Util::Holiday - module containing the holidays_in_daterange
function




=head1 SYNOPSIS

    use App::Dochazka::REST::Util::Holiday qw( holidays_in_daterange );

    my $holidays1 = holidays_in_daterange( 
        begin => '2001-01-02',
        end => '2001-12-24',
    );
    my $holidays2 = holidays_in_daterange( 
        begin => '2001-01-02',
        end => '2002-12-24',
    );

*WARNING*: C<holidays_in_daterange()> makes no attempt to validate the date
range. It assumes this validation has already taken place, and that the dates
are in YYYY-MM-DD format!




=head1 EXPORTS

=cut 

use Exporter qw( import );
our @EXPORT_OK = qw( holidays_in_daterange );




=head1 FUNCTIONS

=head2 holidays_in_daterange

Given two canonicalized dates, extract the from and to dates
and return a status object. Upon success, the payload will contain a list of
holidays between those two dates (inclusive).

If no tsrange is given, defaults to the current year.

=cut

sub holidays_in_daterange {
    my ( %ARGS ) = validate( @_, {
        begin => { type => SCALAR },
        end => { type => SCALAR },
    } );

    my $begin_year = _extract_year( $ARGS{begin} );
    my $end_year = _extract_year( $ARGS{end} );

    # transform daterange into an array of hashes containing "begin", "end"
    # in other words: 
    # INPUT: { begin => '1901-06-30', end => '1903-03-15' } 
    # becomes
    # OUTPUT: [
    #     { begin => '1901-06-30', end => '1901-12-31' },
    #     { begin => '1902-01-01', end => '1902-12-31' },
    #     { begin => '1903-01-01', end => '1903-03-15' },
    # ]
    my $daterange_by_year = _daterange_by_year(
        begin_year => $begin_year,
        end_year => $end_year,
        begin_date => $ARGS{begin},
        end_date => $ARGS{end},
    );
    
    my @retval;

    foreach my $year ( sort( keys %{ $daterange_by_year } ) ) {
        my $holidays = holidays( YEAR => $year, FORMAT => '%Y-%m-%d', WEEKENDS => 0 );
        if ( $year eq $begin_year and $year eq $end_year ) {
            my $tmp_holidays = _eliminate_dates( $holidays, $ARGS{begin}, "before" );
            $holidays = _eliminate_dates( $tmp_holidays, $ARGS{end}, "after" );
            push @retval, @$holidays;
        } elsif ( $year eq $begin_year ) {
            push @retval, @{ _eliminate_dates( $holidays, $ARGS{begin}, "before" ) };
        } elsif ( $year eq $end_year ) {
            push @retval, @{ _eliminate_dates( $holidays, $ARGS{end}, "after" ) };
        } else {
            push @retval, @$holidays;
        }
    }

    return {
        date_range => {
            begin_date => $ARGS{begin},
            end_date => $ARGS{end},
        },
        holidays => \@retval
    };
}

# $inequality can be "before" or "after"
sub _eliminate_dates {
    my ( $holidays, $date, $inequality ) = @_;
    my @retval;
    foreach my $holiday ( @$holidays ) {
        if ( $inequality eq 'before' ) {
            push @retval, $holiday if $holiday ge $date; 
        } elsif ( $inequality eq 'after' ) {
            push @retval, $holiday if $holiday le $date;
        } else {
            die 'AG@D##KDW####!!!';
        }
    }
    return \@retval;
}

sub _extract_year {
    my $date = shift;
    my ( $year ) = $date =~ m/(\d+)-\d+-\d+/;
    return $year;
}

sub _daterange_by_year {
    my ( %ARGS ) = validate( @_, {
        begin_year => { type => SCALAR },
        end_year => { type => SCALAR },
        begin_date => { type => SCALAR },
        end_date => { type => SCALAR },
    } );
    my $year_delta = $ARGS{end_year} - $ARGS{begin_year};
    if ( $year_delta == 0 ) {
        return { $ARGS{begin_year} => { begin => $ARGS{begin}, end => $ARGS{end} } };
    }
    if ( $year_delta == 1 ) {
        return {
            $ARGS{begin_year} => { begin => $ARGS{begin}, end => "$ARGS{begin_year}-12-31" },
            $ARGS{end_year} => { begin => "$ARGS{end_year}-01-01", end => $ARGS{end} },
        };
    }
    my @intervening_years = ( ($ARGS{begin_year}+1)..($ARGS{end_year}-1) );
    my %retval = ( 
        $ARGS{begin_year} => { begin => $ARGS{begin}, end => "$ARGS{begin_year}-12-31" },
        $ARGS{end_year} => { begin => "$ARGS{end_year}-01-01", end => $ARGS{end} },
    );
    foreach my $year ( @intervening_years ) {
        $retval{ $year } = { begin => "$year-01-01", end => "$year-12-31" };
    }
    return \%retval;
}

1;
