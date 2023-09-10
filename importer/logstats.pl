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

my $logConf = q{
    log4perl.category = INFO, Logfile
    log4perl.appender.Logfile = Log::Dispatch::FileRotate
    log4perl.appender.Logfile.mode = truncate
    log4perl.appender.Logfile.autoflush = 1
    log4perl.appender.Logfile.size = 104857600
    log4perl.appender.Logfile.layout = Log::Log4perl::Layout::SimpleLayout
};
Log::Log4perl->init(\$logConf);

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
open FI,'<',$logfile or die "Unable to read file: $logfile";
$parser->sourcePath($logfile);
while (1) {
    my $line = <FI>;
    last unless (defined $line);
    chomp($line);
    eval {
	$parser->parseLine($line);
    };
    if ($@) {
	if ($retry_count < 3) {
	    $log->error("Importer error: $@, retrying($retry_count)...\n");
	    $parser = $importers{$importer}->(server_name => $server_name,server_ip => $server_ip,server_url => $server_url);
	    $parser->sourcePath($logfile);
	    ++$retry_count;
	} else {
	    $log->error("Importer error: $@, too many consecutive errors in import.\n");
	    die "Too many consecutive errors in import.";
	}
    } else { $retry_count = 0; }
}
close FI;
$log->info("Import finished.");
