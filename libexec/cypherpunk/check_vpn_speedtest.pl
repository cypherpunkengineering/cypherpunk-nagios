#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
Getopt::Long::Configure('bundling');

$ENV{HOME} = '/home/nagios';
my ($vpntype, $speedtesttype, $hostname, $hostip, $hostport, $servicename, $downloadwarn, $downloadcrit, $uploadwarn, $uploadcrit, $serverindex, $region) = (0,0,0,0,0,0,0,0,0,0,0,0);
my $status = GetOptions(
	"t=s" => \$vpntype, "vpntype=s" => \$vpntype,
	"k=s" => \$speedtesttype, "speedtesttype=s" => \$speedtesttype,
	"H=s" => \$hostname, "hostname=s" => \$hostname,
	"h=s" => \$hostip, "hostip=s" => \$hostip,
	"p=s" => \$hostport, "hostport=i" => \$hostport,
	"s=s" => \$servicename, "servicename=s" => \$servicename,
	"w=s" => \$downloadwarn, "downloadwarn=i" => \$downloadwarn,
	"c=s" => \$downloadcrit, "downloadcrit=i" => \$downloadcrit,
	"W=s" => \$uploadwarn, "uploadwarn=i" => \$uploadwarn,
	"C=s" => \$uploadcrit, "uploadcrit=i" => \$uploadcrit,
	"i=s" => \$serverindex, "serverindex=i" => \$serverindex,
	"r=s" => \$region, "region=s" => \$region,
	);

my $modified_hostname = $hostname;
$modified_hostname =~ s/\./\-/g;
my $container = "$modified_hostname-$servicename";
# Remove any existing lxc first, in case check timed out previously
&lxc_remove;
my $lxc_launch = `lxc launch vpncheck $container 2>&1`;
if ($? > 0 || $lxc_launch =~ /error/img) {
	print "CRITICAL: Problem launching lxc container $container: $lxc_launch\n";
	&lxc_remove(1);
	exit 2;
}

my $lxc_output;
if ($vpntype eq 'openvpn') {
	$lxc_output = `lxc exec $container -- /root/openvpn_speedtest $speedtesttype $hostip $hostport $downloadwarn $downloadcrit $uploadwarn $uploadcrit $serverindex`;
} else {
	$lxc_output = `lxc exec $container -- /root/ipsec_speedtest $vpntype $speedtesttype $hostip $region $downloadwarn $downloadcrit $uploadwarn $uploadcrit $serverindex`;
}

my $exitcode = $? >> 8;
print "$lxc_output";
my $remove_code = &lxc_remove(1);
exit (($remove_code > $exitcode) ? $remove_code : $exitcode);

sub lxc_remove {
	my ($flag) = @_;
	my $return = 0;
	my $null = '';
	my $lxc_delete = `lxc delete $container --force 2>&1`;
	if ($? > 0 && defined($flag)) {
		print "$lxc_delete\n";
		$return = 2;
	}
	return $return;
}
