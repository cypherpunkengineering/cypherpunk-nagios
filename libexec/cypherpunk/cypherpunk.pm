#!/usr/bin/perl
package cypherpunk;
use warnings;
use strict;

use WWW::Curl::Easy;
use JSON::XS;
use Data::Dumper;

sub server_info {
	my ($server) = @_;
	$server =~ s/freebsd1.tokyo/devtokyo1/;
	$server =~ s/freebsd\d\.//;
	$server =~ s/vpn3/devhonolulu/;
	$server =~ s/freebsd-test.tokyo/devtokyo3/;
	my $curl = WWW::Curl::Easy->new;
        
	my $response_body;
	$curl->setopt(CURLOPT_URL, 'https://cypherpunk.privacy.network/api/v1/location/list/developer');
	$curl->setopt(CURLOPT_USERAGENT, "Nagios Ninja/1.0");
	$curl->setopt(CURLOPT_WRITEDATA,\$response_body);
	my $retcode = $curl->perform;
	if ($retcode == 0) {
		my $response_code = $curl->getinfo(CURLINFO_HTTP_CODE);
		my $json = decode_json $response_body;
	
		return $json->{$server};
	} else {
		print "UNKNOWN: Unable to connect to backend API.";
		exit 3;
	}
}

sub get_creds {
	open my $fh, '<', '/usr/local/nagios/etc/userpass' or die $!;
	chomp(my @creds = <$fh>);
	close $fh;
	return @creds;
}

return 1;
