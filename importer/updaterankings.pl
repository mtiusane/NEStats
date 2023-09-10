#!/usr/bin/perl

use strict;
use warnings;

use Log::Log4perl qw/:easy/;

use lib '../lib';

use Stats::DB;
use Stats::DB::Server;
use Stats::LogParser::Unvanquished;

Log::Log4perl->easy_init({ level => $INFO, file => '>>updaterankings.log' });
my $log = Log::Log4perl->get_logger("updaterankings.pl");
$log->info("Rankings update started...");
foreach my $server (@{Stats::DB::Server::Manager->get_servers()}) {
    $log->info("Updating server rankings: ",$server->name," (ip = ",$server->ip,", url = ",$server->url,")");
    my $parser = Stats::LogParser::Unvanquished->new(server_ip => $server->ip, server_name => $server->name, server_url => $server->url);
    $parser->updateRankings();
}
$log->info("Rankings update finished.");
