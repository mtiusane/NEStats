#!/usr/bin/perl

use strict;
use warnings;

use Log::Log4perl qw/:easy/;

use Net::Domain qw/hostname/;
use Socket;

use lib '../lib';

my %importers = (
    tremulous => sub {
	my (%params) = @_;
	use Stats::LogParser::Tremulous;
	return Stats::LogParser::Tremulous->new(%params);
    },
    unvanquished => sub {
	my (%params) = @_;
	use Stats::LogParser::Unvanquished;
	return Stats::LogParser::Unvanquished->new(%params);
    }
);
use Stats::LogParser;

Log::Log4perl->easy_init({ level => $INFO, file => '>>logstats.log' });

$SIG{__DIE__} = sub {
    return if($^S); # inside eval { }
    $Log::Log4perl::caller_depth++;
    my $logger = get_logger("");
    $logger->fatal(@_);
    die @_;
};

my $syntax = "Usage: $0 [tremulous|unvanquished] logfile servername server_url serverip";

my $importer    = shift || die $syntax;
my $logfile     = shift || die $syntax;
my $server_name = shift || die $syntax;
my $server_url  = shift || die $syntax;
my $server_ip   = shift || inet_ntoa(scalar gethostbyname(hostname || 'localhost'));

die "No such importer: $importer" unless defined($importers{$importer});

my $log = Log::Log4perl->get_logger("logstats.pl");
$log->info("Starting import: $importer $logfile $server_name $server_url $server_ip");
my $parser = $importers{$importer}->(server_name => $server_name,server_ip => $server_ip,server_url => $server_url);
my $retry_count = 0;
while (1) {
    eval {
	$parser->parseFile($logfile);
    };
    if ($@) {
	if ($retry_count < 3) {
	    $log->info("Importer error: $@, retrying($retry_count)...\n");
	    $parser = $importers{$importer}->(server_name => $server_name,server_ip => $server_ip,server_url => $server_url);
	    ++$retry_count;
	} else {
	    $log->error("Too many consecutive errors in import.");
	    die "Too many consecutive errors in import.";
	}
    } else { $retry_count = 0; }
}
$log->info("Import finished.");
