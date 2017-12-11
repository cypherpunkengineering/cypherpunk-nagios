#!/usr/bin/perl
use warnings;
use strict;
use CGI qw(:standard);
use DBI;
use Text::TabularDisplay;
use WebService::Slack::IncomingWebHook;

my $tb = Text::TabularDisplay->new(
        "Server", "User Count", "TX Mbit/sec", "RX Mbit/sec"
    );
print header(-type => 'text/plain');
my $dbh = DBI->connect("DBI:mysql:database=nagios;host=localhost",
                         "nagios", "engineering",
                         {'RaiseError' => 1});
my $sth = $dbh->prepare(qq!SELECT nagios_hosts.display_name, nagios_servicestatus.output from nagios_services, nagios_servicestatus, nagios_hosts WHERE nagios_services.service_object_id = nagios_servicestatus.service_object_id and (nagios_services.display_name = "usercount" or nagios_services.display_name = "netio") and nagios_services.host_object_id = nagios_hosts.host_object_id!);
$sth->execute();
my %hosttx;
my %hostrx;
my %usercount;
my %region;
my $total = 0;
while (my $ref = $sth->fetchrow_hashref()) {
	if ($ref->{output} =~ /(\d+) connected users/) {
		$usercount{$ref->{display_name}} += $1;
		if ($ref->{display_name} =~ /.*?\.(.*)/) {
			push @{$region{$1}}, $ref->{display_name};
		}
		$total += $usercount{$ref->{display_name}};
	} elsif ($ref->{output} =~ /TX: (\d+) bps RX: (\d+) bps/) {
		$hosttx{$ref->{display_name}} = sprintf("%.1f", $1 / 1000000);
		$hostrx{$ref->{display_name}} = sprintf("%.1f", $2 / 1000000);
	}
		
}

my $output;
foreach my $r (sort keys %region) {
	foreach my $server (@{$region{$r}}) {
		$tb->add($server, $usercount{$server}, $hosttx{$server}, $hostrx{$server});
	}
}

print $tb->render;
print "\nTotal: $total\n";

$output = $tb->render . "\nTotal: $total\n";
my $client = WebService::Slack::IncomingWebHook->new(
	webhook_url => 'https://hooks.slack.com/services/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',
	channel => '#server-stats',
);
$client->post(
	text => "```$output```",
);


