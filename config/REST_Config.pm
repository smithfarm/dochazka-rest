# ************************************************************************* 
# Copyright (c) 2014, SUSE LLC
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

# -------------------------------------------
# App::Dochazka::REST
# -------------------------------------------
#
# REST_Config.pm - Top-level configuration file
# providing default values for various site
# configuration parameters. Any or all of these
# parameters can be overrided in your site
# configuration file(s).
#
# WARNING: THIS FILE MAY CONTAIN PASSWORDS
# (restrictive permissions may be warranted)
# -------------------------------------------


# DOCHAZKA_URI
#    the bare URI where the server listens (no trailing '/') -- this
#    information is used in the various "help" (or "default") resources. If
#    this parameter is not set, the URI is obtained from the HTTP request
#    itself.
#set( 'DOCHAZKA_URI', 'http://dochazka.site' );

# DOCHAZKA_HOST
#    the hostname (vhost) where REST server will listen on a part
set( 'DOCHAZKA_HOST', 'localhost' );

# DOCHAZKA_PORT
#    the port where the REST server will listen
set( 'DOCHAZKA_PORT', 5000 );

# DOCHAZKA_REST_LOG_FILE
#     full path of log file to log to
set( 'DOCHAZKA_REST_LOG_FILE', '/var/log/dochazka-rest.log' );

# DOCHAZKA_REST_LOG_FILE_RESET
#     should the logfile be deleted/wiped/unlinked/reset before each use
set( 'DOCHAZKA_REST_LOG_FILE_RESET', 0 );

# DOCHAZKA_DOCUMENTATION_URI
#    used in the "help"/"default" resources
set( 'DOCHAZKA_DOCUMENTATION_URI', 'https://metacpan.org/pod/App::Dochazka::REST' );

# DOCHAZKA_REPORT_BUGS_TO
#    this should be an ordinary string like "bugs@dochazka.com" or
#    "http://bugs.dochazka.com"
set( 'DOCHAZKA_REPORT_BUGS_TO', 'bug-App-Dochazka-REST@rt.cpan.org' );

# DOCHAZKA_URI_MAX_LENGTH
#    maximum length of a URI -- see Resource.pm->uri_too_long
set( 'DOCHAZKA_URI_MAX_LENGTH', 1000 );

# DOCHAZKA_APPNAME
#    name of application (for logging) -- this can be set to any string, with
#    the proviso that it should not contain ':' characters
set( 'DOCHAZKA_APPNAME', 'App-Dochazka-REST' );

# DOCHAZKA_DBNAME
#    name of PostgreSQL database to use
set( 'DOCHAZKA_DBNAME', 'dochazka-test' );

# DOCHAZKA_DBUSER
#    name of PostgreSQL username (role) to connect with
set( 'DOCHAZKA_DBUSER', 'dochazka' );

# DOCHAZKA_DBPASS
#    name of PostgreSQL username (role) to connect with
set( 'DOCHAZKA_DBPASS', 'dochazka' );

# DOCHAZKA_DBHOST
#    host and domain name of remote PostgreSQL server - set to an empty
#    string to use the default: local domain socket
set( 'DOCHAZKA_DBHOST', '' );

# DOCHAZKA_DBPORT
#    port where the remote PostgreSQL server is listening - set to an empty
#    string to use the default: local domain socket
set( 'DOCHAZKA_DBPORT', '' );

# DOCHAZKA_DBSSLMODE
#    setting for the 'sslmode' property sent to DBD::Pg when the database
#    connection is established - see 'perldoc DBD::Pg' - set to the empty
#    string to use the default: (none)
#set( 'DOCHAZKA_DBSSLMODE', 'require' );
set( 'DOCHAZKA_DBSSLMODE', '' );

# DOCHAZKA_AUDITING
#    enable/disable auditing - note that if this is disabled at the beginning
#    when the database is initialized, there is no easy way to enable it later
set( 'DOCHAZKA_AUDITING', 1 );

# DOCHAZKA_AUDIT_TABLES
#    list of tables to audit (to disable auditing, set this parameter to [] in
#    your SiteConfig.pm and call 'delete_audit_triggers')
set( 'DOCHAZKA_AUDIT_TABLES', [ 
    qw( activities employees intervals locks privhistory schedhistory schedules ) 
] );

# DOCHAZKA_EID_OF_ROOT
#    Employee ID of the root employee -- set at initialization time (in
#    REST.pm) -- do not set here
#!! DO NOT SET HERE !!

# DOCHAZKA_EID_OF_DEMO
#    Employee ID of the demo employee -- set at initialization time (in
#    REST.pm) -- do not set here
#!! DO NOT SET HERE !!

# DOCHAZKA_ACTIVITY_DEFINITIONS
#    Initial set of activity definitions - sample only - override this 
#    with _your_ site's activities in Dochazka_SiteConfig.pm
set( 'DOCHAZKA_ACTIVITY_DEFINITIONS', [
        { code => 'WORK', long_desc => 'Work' },
        { code => 'OVERTIME_WORK', long_desc => 'Overtime work' },
        { code => 'PAID_VACATION', long_desc => 'Paid vacation' },
        { code => 'UNPAID_LEAVE', long_desc => 'Unpaid leave' },
        { code => 'DOCTOR_APPOINTMENT', long_desc => 'Doctor appointment' },
        { code => 'CTO', long_desc => 'Compensation Time Off' },
        { code => 'SICK_DAY', long_desc => 'Discretionary sick leave' },
        { code => 'MEDICAL_LEAVE', long_desc => 'Statutory medical leave' },
    ] );   

# DOCHAZKA_ADVANCE_INTERVALS_MAX_DAYS
#     Some employees may try to enter attendance intervals days, weeks, 
#     or even months in advance. This sets the maximum number of days
#     in advance that Dochazka will accept an activity interval.
set( 'DOCHAZKA_MAX_FUTURE_DAYS', 45 );

# DOCHAZKA_BASIC_AUTH_REALM
#     message displayed to user when she is asked to enter her credentials
set( 'DOCHAZKA_BASIC_AUTH_REALM', 
     'ENTER YOUR DOCHAZKA CREDENTIALS (e.g., demo/demo)' );

# DOCHAZKA_LDAP
#     Enable/disable LDAP authentication
set( 'DOCHAZKA_LDAP', 0 );

# DOCHAZKA_LDAP_AUTOCREATE
#     Autocreate unknown users if found in LDAP
set( 'DOCHAZKA_LDAP_AUTOCREATE', 0 );

# DOCHAZKA_LDAP_AUTOCREATE_AS
#     Priv level to assign to LDAP-autocreated users
set( 'DOCHAZKA_LDAP_AUTOCREATE_AS', 'passerby' );

# DOCHAZKA_LDAP_SERVER
#     LDAP server for LDAP authentication
#     make sure to include either 'ldap://' or 'ldaps://'
set( 'DOCHAZKA_LDAP_SERVER', 'ldaps://ldap.dochazka.site' );

# DOCHAZKA_LDAP_BASE
#     base DN
set( 'DOCHAZKA_LDAP_BASE', 'dc=dochazka,dc=site' );

# DOCHAZKA_LDAP_NICK_MAPPING
#     in order for LDAP authentication to work, the Dochazka 'nick' must
#     be mapped to a field in the LDAP database (e.g. 'uid', 'cn', etc.)
set( 'DOCHAZKA_LDAP_NICK_MAPPING', 'uid' );

# DOCHAZKA_LDAP_FILTER
#     filter
set( 'DOCHAZKA_LDAP_FILTER', '(EMPLOYEESTATUS=Active)' );

# DOCHAZKA_LDAP_TEST_UID_EXISTENT
#     an existent UID for LDAP testing (t/201-LDAP.t)
set( 'DOCHAZKA_LDAP_TEST_UID_EXISTENT', 'I_exist_in_local_LDAP' );

# DOCHAZKA_LDAP_TEST_UID_NON_EXISTENT
#     a non-existent UID for LDAP testing (t/201-LDAP.t)
set( 'DOCHAZKA_LDAP_TEST_UID_NON_EXISTENT', 'I_do_NOT_exist_in_local_LDAP' );

# DOCHAZKA_REST_SESSION_EXPIRATION_TIME
#     number of seconds after which a session will be considered stale
set( 'DOCHAZKA_REST_SESSION_EXPIRATION_TIME', 3600 );

# DOCHAZKA_REST_DEBUG_MODE
#     whether or not debug- and trace-level messages are logged
set( 'DOCHAZKA_REST_DEBUG_MODE', 0 );

# DOCHAZKA_PROFILE_EDITABLE_FIELDS
#     which employee fields can be updated by employees with privlevel 'inactive' and 'active'
#     N.B. 1 administrators can edit all fields, and passerbies can't edit any
#     N.B. 2 if LDAP authentication and LDAP import/sync are being used, it may not 
#            make sense for employees to edit *any* of the fields
#     N.B. 3 this site param affects the functioning of the "POST employee/self" and "POST employee/current" resources
set( 'DOCHAZKA_PROFILE_EDITABLE_FIELDS', {
    'inactive' => [ 'password' ],
    'active' => [ 'password' ],
});

# DOCHAZKA_INTERVAL_SELECT_LIMIT
#     upper limit on number of intervals fetched (for sanity, to avoid
#     overly huge result sets)
set( 'DOCHAZKA_INTERVAL_SELECT_LIMIT', undef );

# -----------------------------------
# DO NOT EDIT ANYTHING BELOW THIS LINE
# -----------------------------------
use strict;
use warnings;

1;
