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

use Date::Calc qw(
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
    canon_date_diff
    canon_to_ymd
    ymd_to_canon
);




=head1 FUNCTIONS


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
