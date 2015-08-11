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

# -----------------------------------
# Dochazka-REST
# -----------------------------------
# tempintvls_Config.pm
#
# SQL code related to tempintvls
# -----------------------------------

# SQL_NEXT_TIID
#     SQL to get next value from temp_intvl_seq
#
set( 'SQL_NEXT_TIID', q/
      SELECT nextval('temp_intvl_seq');
      / );

# SQL_TEMPINTVLS_INSERT
#     SQL to insert a single record in the 'tempintvls' table
#
set( 'SQL_TEMPINTVLS_INSERT', q/
      INSERT INTO tempintvls (tiid, eid, aid, intvl)
      VALUES (?, ?, ?, ?)
      / );

# SQL_TEMPINTVLS_DELETE
#     SQL to delete scratch intervals once they are no longer needed
set( 'SQL_TEMPINTVLS_DELETE', q/
      DELETE FROM tempintvls WHERE tiid = ?
      / );

# SQL_TEMPINTVLS_SELECT_EXCLUSIVE
#     SQL to select scratch intervals matching a range - NOT INCLUDING partial
#     intervals (if any) at beginning and end of range
set( 'SQL_TEMPINTVLS_SELECT_EXCLUSIVE', q/
      SELECT eid, aid, intvl, long_desc, remark FROM tempintvls
      WHERE intvl <@ CAST( ? AS tstzrange )
      ORDER BY intvl
      / );

# -----------------------------------
# DO NOT EDIT ANYTHING BELOW THIS LINE
# -----------------------------------
use strict;
use warnings;

1;
