#!/usr/bin/perl
use warnings;
use strict;

use lib '/usr/local/nagios/libexec/cypherpunk';
use cypherpunk;

my $server = shift @ARGV;
my $server_info = cypherpunk::server_info($server);

my $ip = $server_info->{'httpDefault'}[0];
my ($user, $pass) = cypherpunk::get_creds();
my $argstring = join(' ', @ARGV);
my $result = `/usr/local/nagios/libexec/check_http -b $user:$pass -H $ip $argstring`;
my $status = $? >> 8;
print $result;
exit $status;
