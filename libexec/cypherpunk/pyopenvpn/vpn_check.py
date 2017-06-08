#!/usr/local/bin/python3.5 -u
import logging
import ipaddress
from argparse import ArgumentParser
from datetime import datetime, timedelta
logging.getLogger("scapy.runtime").setLevel(logging.ERROR)
from scapy.all import *

from pyopenvpn import Client, Settings


class PingClient:
    def __init__(self, args):
        self.host = args.host
        self.interval = timedelta(seconds=args.interval)
        self.timeout = timedelta(seconds=args.timeout)
        self.count = args.count
        self.hostip = None
        self.need_dns_query = True
        try:
            ipaddress.ip_address(self.host)
            self.hostip = self.host
            self.need_dns_query = False
        except ValueError:
            pass
        #print("Pinging %s..." % self.host)

        self.pings = []

    def __call__(self, client):
        while True:
            incoming = client.recv_data()
            if not incoming:
                break
            #print("imcoming.sr: " % incoming.src)
            if self.hostip is None and incoming.src == "10.10.10.10": # and isinstance(incoming.payload, DNS):
                #print("dns reply")
                in_dns = incoming.payload.an.rdata
                self.hostip = in_dns
                #print("using: ",  self.hostip)
                continue
                
            if incoming.src != self.hostip:
                continue
            if not isinstance(incoming.payload, ICMP):
                continue
            in_icmp = incoming.payload
            if in_icmp.type != 0:
                continue

            seq = in_icmp.seq
            if seq >= len(self.pings):
                continue

            ttl = incoming.ttl
            time = (datetime.now() - self.pings[seq]['time']).total_seconds() * 1000

            self.pings[seq]['received'] = True
            self.pings[seq]['latency'] = time
            #print('reply from %s: icmp_seq=%d ttl=%d time=%.1fms' %
                  #(self.hostip, seq, ttl, time))

            if self.count > 0 and len(self.pings) >= self.count:
                client.stop()
                return

        if self.pings:
            if (datetime.now() - self.pings[-1]['time']) > self.timeout \
               and self.pings[-1]['received'] is None:
                print('timeout')
                self.pings[-1]['received'] = False

                if self.count > 0 and len(self.pings) >= self.count:
                    client.stop()
                    return
        
        if self.hostip is None:
            if self.need_dns_query:
                d = IP(src=client.tunnel_ipv4, dst="10.10.10.10") / UDP() / DNS(rd=1,qd=DNSQR(qname=self.host))
                client.send_data(d)
                self.need_dns_query = False
                #print("sending dns query")
            return

        if not self.pings or (datetime.now() - self.pings[-1]['time']) > self.interval:
            p = IP(src=client.tunnel_ipv4, dst=self.hostip) / ICMP(seq=len(self.pings))
            client.send_data(p)
            self.pings.append({'time': datetime.now(), 'received': None})


if __name__ == '__main__':
    logging.basicConfig(level=logging.ERROR,
                        format="%(levelname)-5s:%(name)-8s: %(message)s")
    parser = ArgumentParser()
    #parser.add_argument('config_file', help="OpenVPN configuration file")
    parser.add_argument('host', help="Remote host to ping")
    parser.add_argument('-i', dest='interval', default=1, metavar='interval', type=int)
    parser.add_argument('-W', dest='timeout', default=5, metavar='timeout', type=int)
    parser.add_argument('-c', dest='count', default=0, metavar='count', type=int)
    parser.add_argument('-H', dest='server', default=0, metavar='server')
    parser.add_argument('-p', dest='port', default=0, metavar='port', type=int)
    parser.add_argument('-t', dest='transport', default="udp", metavar='transport', type=str)

    args = parser.parse_args()
    pinger = PingClient(args)
    #c = Client(Settings.from_file(args.config_file), PingClient(args))
    #c = Client(Settings.from_file(args.config_file), pinger)
    proto = args.transport
    openvpn_options = "remote %s %d\n" % (args.server, args.port)
    openvpn_options += "auth-user-pass /usr/local/nagios/etc/userpass\n"
    openvpn_options += "cipher AES-128-CBC\n"
    openvpn_options += "auth SHA256\n"
    openvpn_options += "proto %s\n" % (proto)
    c = Client(Settings.from_text(openvpn_options), pinger)
    c.run()
    i = 0
    packets_lost = 0
    for p in pinger.pings:
        if p['received'] is True:
            i += p['latency']
        else:
            packets_lost += 1
        
    average_latency = i / pinger.count
    connect_time = c.endtime - c.starttime
    packet_loss = (packets_lost / pinger.count) * 100
    return_code = 0
    status = "OK"
    if connect_time > 8 or packet_loss > 0.4:
       return_code = 2
       status = "CRITICAL"
    elif connect_time > 5 or packet_loss > 0.2:
       return_code = 1
       status = "WARNING"
    
    print("%s - connect time: %f secs, average latency: %.3f ms, packet loss: %.2f%% | connect_time=%fs, google_latency=%.3fms, packet_loss=%.2f%%" % (status, connect_time, average_latency, packet_loss, connect_time, average_latency, packet_loss))
    sys.exit(return_code)
