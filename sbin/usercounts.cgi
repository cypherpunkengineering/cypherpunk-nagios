#!/usr/bin/perl
use warnings;
use strict;
use CGI qw(:standard);
use DBI;

print header(-type => 'text/plain');
my $dbh = DBI->connect("DBI:mysql:database=nagios;host=localhost",
                         "nagios", "engineering",
                         {'RaiseError' => 1});
my $sth = $dbh->prepare(qq!SELECT nagios_hosts.display_name, nagios_servicestatus.output from nagios_services, nagios_servicestatus, nagios_hosts WHERE nagios_services.service_object_id = nagios_servicestatus.service_object_id and (nagios_services.display_name = "openvpn_users" OR nagios_services.display_name = "strongswan") and nagios_services.host_object_id = nagios_hosts.host_object_id!);
$sth->execute();
my %usercount;
my $total = 0;
while (my $ref = $sth->fetchrow_hashref()) {
	if ($ref->{output} =~ /Total users: (\d+)/) {
		$usercount{$ref->{display_name}} += $1;
		$total += $1;
	} elsif ($ref->{output} =~ /(\d+) total users connected/) {
		$usercount{$ref->{display_name}} += $1;
		$total += $1;
	}
}

foreach my $server (keys %usercount) {
	print $server . " " . $usercount{$server} . "\n"
}

print "\nTotal: $total\n";
