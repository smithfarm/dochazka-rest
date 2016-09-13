#
# REST_SiteConfig.pm
#
# App::Dochazka::REST site configuration parameters that site administrators
# might need to change the default values of.
#
# The first argument to "set()" is the name of the configuration parameter, and
# the second argument is its value. The values shown below are the defaults.
#
# To keep the default value, do nothing.
#
# To override a default, uncomment the "set" call and change the value. 
#

# DOCHAZKA_REST_LOG_FILE
#     full path of log file to log to
#set( 'DOCHAZKA_REST_LOG_FILE', '/var/log/dochazka-rest.log' );

# DOCHAZKA_REST_LOG_FILE_RESET
#     should the logfile be deleted/wiped/unlinked/reset every time the
#     server starts?
#set( 'DOCHAZKA_REST_LOG_FILE_RESET', 0 );

# DOCHAZKA_STATE_DIR
#     full path of Dochazka server state directory
#     (should be created by packaging)
#set( 'DOCHAZKA_STATE_DIR', '/var/lib/dochazka-rest' );

# DOCHAZKA_DBNAME
#    name of PostgreSQL database to use
#set( 'DOCHAZKA_DBNAME', 'dochazka-test' );

# DOCHAZKA_DBUSER
#    name of PostgreSQL username (role) to connect with
#set( 'DOCHAZKA_DBUSER', 'dochazka' );

# DOCHAZKA_DBPASS
#    name of PostgreSQL username (role) to connect with
#set( 'DOCHAZKA_DBPASS', 'dochazka' );

# DOCHAZKA_DBHOST
#    host and domain name of remote PostgreSQL server - set to an empty
#    string to use the default: local domain socket
#set( 'DOCHAZKA_DBHOST', '' );

# DOCHAZKA_DBPORT
#    port where the remote PostgreSQL server is listening - set to an empty
#    string to use the default: local domain socket
#set( 'DOCHAZKA_DBPORT', '' );

# DOCHAZKA_DBSSLMODE
#    setting for the 'sslmode' property sent to DBD::Pg when the database
#    connection is established - see 'perldoc DBD::Pg' - set to the empty
#    string to use the default: (none)
#set( 'DOCHAZKA_DBSSLMODE', '' );

# DOCHAZKA_TIMEZONE
#    used to set the PGTZ environment variable
#set( 'DOCHAZKA_TIMEZONE', 'Europe/Prague' );

# DOCHAZKA_LDAP
#     Enable/disable LDAP authentication
#set( 'DOCHAZKA_LDAP', 0 );

# DOCHAZKA_LDAP_AUTOCREATE
#     Autocreate unknown users if found in LDAP
#set( 'DOCHAZKA_LDAP_AUTOCREATE', 0 );

# DOCHAZKA_LDAP_AUTOCREATE_AS
#     Priv level to assign to LDAP-autocreated users
#set( 'DOCHAZKA_LDAP_AUTOCREATE_AS', 'passerby' );

# DOCHAZKA_LDAP_SERVER
#     LDAP server for LDAP authentication
#     make sure to include either 'ldap://' or 'ldaps://'
#set( 'DOCHAZKA_LDAP_SERVER', 'ldaps://ldap.dochazka.site' );

# DOCHAZKA_LDAP_BASE
#     base DN
#set( 'DOCHAZKA_LDAP_BASE', 'dc=dochazka,dc=site' );

# DOCHAZKA_LDAP_NICK_MAPPING
#     in order for LDAP authentication to work, the Dochazka 'nick' must
#     be mapped to a field in the LDAP database (e.g. 'uid', 'cn', etc.)
#set( 'DOCHAZKA_LDAP_NICK_MAPPING', 'uid' );

# DOCHAZKA_LDAP_FILTER
#     filter
#set( 'DOCHAZKA_LDAP_FILTER', '(EMPLOYEESTATUS=Active)' );

# DOCHAZKA_LDAP_TEST_UID_EXISTENT
#     an existent UID for LDAP testing (t/201-LDAP.t)
#set( 'DOCHAZKA_LDAP_TEST_UID_EXISTENT', 'I_exist_in_local_LDAP' );

# DOCHAZKA_LDAP_TEST_UID_NON_EXISTENT
#     a non-existent UID for LDAP testing (t/201-LDAP.t)
#set( 'DOCHAZKA_LDAP_TEST_UID_NON_EXISTENT', 'I_do_NOT_exist_in_local_LDAP' );

# DOCHAZKA_LDAP_POPULATE_MATRIX
#     set of key => value pairs where key is Employee object property and value
#     is the matching LDAP property; used to populate employee objects with
#     values from LDAP (do *not* include nick mapping here - use
#     DOCHAZKA_LDAP_NICK_MAPPING for that)
#set( 'DOCHAZKA_LDAP_POPULATE_MATRIX', {} );

# DOCHAZKA_REST_SESSION_EXPIRATION_TIME
#     number of seconds after which a session will be considered stale
#set( 'DOCHAZKA_REST_SESSION_EXPIRATION_TIME', 3600 );

# DOCHAZKA_PROFILE_EDITABLE_FIELDS
#     which employee fields can be updated by employees with privlevel 'inactive' and 'active'
#     N.B. 1 administrators can edit all fields, and passerbies can't edit any
#     N.B. 2 if LDAP authentication and LDAP import/sync are being used, it may not 
#            make sense for employees to edit *any* of the fields
#     N.B. 3 this site param affects the functioning of the "POST
#            employee/self" and "POST employee/current" resources
#set( 'DOCHAZKA_PROFILE_EDITABLE_FIELDS', {
#    'inactive' => [ 'password' ],
#    'active' => [ 'password' ],
#});

# DOCHAZKA_INTERVAL_SELECT_LIMIT
#     upper limit on number of intervals fetched (for sanity, to avoid
#     overly huge result sets)
#set( 'DOCHAZKA_INTERVAL_SELECT_LIMIT', undef );

# DOCHAZKA_INTERVAL_DELETE_LIMIT
#     highest possible number of intervals that can be deleted at one time
#set( 'DOCHAZKA_INTERVAL_DELETE_LIMIT', 250 );

# DOCHAZKA_EMPLOYEE_MINIMAL_FIELDS
#     list of fields to include in "GET employee/eid/:eid/minimal" and
#     "GET employee/nick/:nick/minimal" and "GET employee/sec_id/:sec_id/minimal"
#set( 'DOCHAZKA_EMPLOYEE_MINIMAL_FIELDS', [ 
#    qw( sec_id nick fullname email eid supervisor )
#] );

# DOCHAZKA_INTERVAL_FILLUP_LIMIT
#     upper limit (in days) on the fillup tsrange
#set( 'DOCHAZKA_INTERVAL_FILLUP_LIMIT', 365 ); 

# DOCHAZKA_INTERVAL_FILLUP_MAX_DATELIST_ENTRIES
#     upper limit for number of date_list entries
#set( 'DOCHAZKA_INTERVAL_FILLUP_MAX_DATELIST_ENTRIES', 35 );

# -----------------------------------
# DO NOT EDIT ANYTHING BELOW THIS LINE
# -----------------------------------
use strict;
use warnings;

1;
