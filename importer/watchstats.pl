#!/usr/bin/perl

use strict;
use warnings;

use Log::Log4perl qw/:easy/;

use File::Tail;

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

my $logConf = q{
    log4perl.category = INFO, Logfile
    log4perl.appender.Logfile = Log::Dispatch::FileRotate
    log4perl.appender.Logfile.filename = watchstats.log
    log4perl.appender.Logfile.mode = truncate
    log4perl.appender.Logfile.autoflush = 1
    log4perl.appender.Logfile.size = 104857600
    log4perl.appender.Logfile.layout = Log::Log4perl::Layout::SimpleLayout
};
Log::Log4perl->init(\$logConf);

$SIG{__DIE__} = sub {
    return if($^S); # eval { }
    $Log::Log4perl::caller_depth++;
    my $logger = get_logger("");
    $logger->fatal(@_);
    die @_;
};

my $syntax = "Syntax: $0 tremulous|unvanquished logfile server_name server_url [server_ip]";

my $importer    = shift || die $syntax;
my $logfile     = shift || die $syntax;
my $server_name = shift || die $syntax;
my $server_url  = shift || die $syntax;
my $server_ip   = shift || inet_ntoa(scalar gethostbyname(hostname || 'localhost'));

die "No such importer: $importer" unless defined($importers{$importer});

my $log = Log::Log4perl->get_logger("watchstats.pl");
$log->info("Starting import...");
while(1) {
    $log->info("Importing log: $server_name $server_ip $server_url\n");
    eval {
	my $parser = $importers{$importer}->(server_name => $server_name,server_ip => $server_ip,server_url => $server_url);
	$parser->sourcePath($logfile);
	my $file = File::Tail->new($logfile);
	while(defined(my $line = $file->read)) {
	    $parser->parseLine($line);
	}
    };
    if ($@) {
	$log->error($@);
	$log->info("Restarting import...");
    }
}
