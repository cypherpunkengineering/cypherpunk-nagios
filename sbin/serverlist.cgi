#!/usr/bin/perl
use warnings;
use strict;
use CGI qw(:standard);
use DBI;

my $region = param("region");
print header(-type => 'text/plain');
my $dbh = DBI->connect("DBI:mysql:database=nagios;host=localhost",
                         "nagios", "engineering",
                         {'RaiseError' => 1});
my $sth = $dbh->prepare("SELECT display_name, address from nagios_hosts");
$sth->execute();
while (my $ref = $sth->fetchrow_hashref()) {
	if ($ref->{display_name} =~ /\.${region}$/) {
		print $ref->{display_name} . " " . $ref->{address} . "\n";
	}
}
