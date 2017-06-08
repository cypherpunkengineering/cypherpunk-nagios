#!/usr/bin/perl
use strict;
use warnings;
use Time::Out qw(timeout);

#my @tcp_ports = qw( 443 7133 );
#my @udp_ports = qw( 53 5060 7133 );

#define host{
        #use                     seattle-server
        #host_name               freebsd1.seattle
        #alias                   freebsd1.seattle
        #address                 104.200.129.82
        #_OPENVPN_DEFAULT_IP     104.200.129.210
        #_OPENVPN_MAXSPEED_IP    104.200.129.211
        #_OPENVPN_MAXPRIVACY_IP  104.200.129.212
        #_OPENVPN_MAXFREEDOM_IP  104.200.129.213
        #_STRONGSWANIP           104.200.129.214
        #_REGION                 seattle
        #}
#$USER1$/cypherpunk/check_docker.sh $HOSTNAME$-$SERVICEDESC$ run -e "IP=$ARG1$" -e "PORT=$ARG3$" -e "DOWNLOADWARN=$ARG5$" -e "DOWNLOADCRIT=$ARG4$" -e "TEST=$ARG2$" -e "OPENVPNTYPE=$ARG6$" -e "TRANSPORT=$ARG7$" --dns=10.10.10.10  --rm --cap-add=NET_ADMIN --name $HOSTNAME$-$SERVICEDESC$ vpn /openvpn_speedtest

my %openvpn;
my %strongswan;
my %region;

opendir DIR, "/usr/local/nagios/etc/servers" or die "uhh: $!";
my @files = readdir DIR;
closedir DIR;

foreach my $file (@files) {
	next if $file =~ /^\./;

	if (open(my $fh, '<', "/usr/local/nagios/etc/servers/$file")) {
		my $server;
		my $inhost = 0;
		while (my $row = <$fh>) {
			chomp $row;
			if ($row =~ /host_name\s+(\S+)/) {
				$server = $1;
				$inhost = 1;
			} elsif ($inhost == 1 && $row =~ /_OPENVPN_DEFAULT_IP\s+([0-9\.]+)/) {
				$openvpn{$server} = $1;
			} elsif ($inhost == 1 && $row =~ /_STRONGSWANIP\s+([0-9\.]+)/) {
				$strongswan{$server} = $1;
			} elsif ($inhost == 1 && $row =~ /_REGION\s+([A-Za-z]+)/) {
				$region{$server} = $1;
			}
			if ($row =~ /}/) {
				$inhost = 0;
			}
		}
		close $fh;
	}
}

foreach my $server (sort keys %openvpn) {
	print "Trying openvpn speedtest on $server...\n";
	#print qq!/usr/bin/docker run -e "IP=$openvpn{$server}" -e "PORT=7133" -e "DOWNLOADWARN=10" -e "DOWNLOADCRIT=1" -e "TEST=google" -e "OPENVPNTYPE=default" -e "TRANSPORT=udp" --dns=10.10.10.10 --rm --cap-add=NET_ADMIN --name ${server}-openvpn_default_udp_7133 vpn /openvpn_speedtest!;
	my $status = 3;
	my $output;
	timeout 150 => sub {
		system("docker rm -f ${server}-openvpn_default_udp_7133 > /dev/null &2>1");
		$output = `/usr/bin/docker run -e "IP=$openvpn{$server}" -e "PORT=7133" -e "DOWNLOADWARN=10" -e "DOWNLOADCRIT=1" -e "TEST=google" -e "OPENVPNTYPE=default" -e "TRANSPORT=udp" --dns=10.10.10.10 --rm --cap-add=NET_ADMIN --name ${server}-openvpn_default_udp_7133 vpn /openvpn_speedtest`;
		$status = $? >> 8;
		
	};
	if ($@) {
		print("timed out\n");
		$status = 1;
		$output = "WARNING - Timed out while attempting speedtest.\n";
		system("docker rm -f ${server}-openvpn_default_udp_7133 > /dev/null &2>1");
	}
	if (-p '/usr/local/nagios/var/rw/nagios.cmd') {
		my $string = "[".time."] PROCESS_SERVICE_CHECK_RESULT;${server};openvpn-google;${status};$output";
		print $string;
		system("echo '$string' >> /usr/local/nagios/var/rw/nagios.cmd");
	}
}

foreach my $server (sort keys %strongswan) {
	next unless $region{$server};
	print "Trying strongswan speedtest on $server...\n";
#$USER1$/cypherpunk/check_docker.sh $HOSTNAME$-$SERVICEDESC$ run -e "IP=1$" -e "PORT=$ARG4$" -e "DOWNLOADWARN=$ARG6$" -e "DOWNLOADCRIT=$ARG5$" -e "TEST=$ARG3$" -e "TYPE=$ARG2$" -e "REGION=$ARG10$" --dns=10.10.10.10  --rm --cap-add=NET_ADMIN --name $HOSTNAME$-$SERVICEDESC$ vpn /ipsec_speedtest
	my $status = 3;
	my $output;
	timeout 150 => sub {
		system("docker rm -f ${server}-strongswan > /dev/null &2>1");
		$output = `/usr/bin/docker run -e "IP=$strongswan{$server}" -e "PORT=0" -e "DOWNLOADWARN=10" -e "DOWNLOADCRIT=1" -e "TEST=google" -e "TYPE=ikev2" -e "REGION=$region{$server}" --dns=10.10.10.10 --rm --cap-add=NET_ADMIN --name ${server}-strongswan vpn /ipsec_speedtest`;
		$status = $? >> 8;
		
	};
	if ($@) {
		print("timed out\n");
		$status = 1;
		$output = "WARNING - Timed out while attempting speedtest.\n";
		system("docker rm -f ${server}-strongswan > /dev/null &2>1");
	}
	if (-p '/usr/local/nagios/var/rw/nagios.cmd') {
		my $string = "[".time."] PROCESS_SERVICE_CHECK_RESULT;${server};ikev2-google;${status};$output";
		print $string;
		system("echo '$string' >> /usr/local/nagios/var/rw/nagios.cmd");
	}
}
