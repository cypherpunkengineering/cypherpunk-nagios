#!/usr/bin/perl
use warnings;
use strict;
use DBI;

my $file = "/usr/local/nagios/etc/freebsd-packages.conf";
open (my $fh, '<', $file) or die "Couldn't open $file";
my %packages;

foreach my $line (<$fh>) {
	chomp $line;
	my @p = split(/ /, $line);
	$packages{$p[0]} = $p[1];
	
}
close $fh;

my $dbh = DBI->connect("DBI:mysql:database=nagios;host=localhost",
                         "nagios", "engineering",
                         {'RaiseError' => 1});
my $sth = $dbh->prepare(qq!select nagios_hosts.display_name, nagios_servicestatus.output from nagios_services, nagios_servicestatus, nagios_hosts where nagios_services.service_object_id = nagios_servicestatus.service_object_id and nagios_services.display_name = "pkg" and nagios_services.host_object_id = nagios_hosts.host_object_id!);
$sth->execute();
my @output;
while (my $ref = $sth->fetchrow_hashref()) {
	next if $ref->{display_name} =~ /test/;
	unless ($ref->{output} =~ /^OK - /) {
		next;
	}
	$ref->{output} =~ s/^OK - //;
	my @p = split(/: /, $ref->{output});
	foreach my $pkg (@p) {
		my ($packagename, $version) = $pkg =~ /(.*)\-(.*)/;
		if ($packages{$packagename} && $version lt $packages{$packagename}) {
			push (@output, "$ref->{display_name}: $packagename $version < $packages{$packagename}");
		}
	}
}
if (@output) {
	print "WARNING - Packages found that are lower than the required version\n";
	print join ("\n", @output);
	print "\n";
	exit 1;
} else {
	print "OK - All packages up-to-date.";
	exit 0;
}
