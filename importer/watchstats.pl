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
    log4perl.category = INFO, Screen
    log4perl.appender.Screen = Log::Log4perl::Appender::ScreenColoredLevels
    log4perl.appender.Screen.layout = Log::Log4perl::Layout::PatternLayout
    log4perl.appender.Screen.layout.ConversionPattern = %d %F{1} %L> %m %n
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
# my $syntax = "Syntax: $0 tremulous|unvanquished logfile server_id";

my $importer    = shift || die $syntax;
my $logfile     = shift || die $syntax;
# my $server_id   = shift || die $syntax;
my $server_name = shift || die $syntax;
my $server_url  = shift || die $syntax;
my $server_ip   = shift || inet_ntoa(scalar gethostbyname(hostname || 'localhost'));

die "No such importer: $importer" unless defined($importers{$importer});

my $running = 1;
#$SIG{TERM} = $SIG{INT} = sub { $running = 0; };

my $log = Log::Log4perl->get_logger("watchstats.pl");
$log->info("Starting import...");
while($running) {
    $log->info("Importing log: $server_name $server_ip $server_url\n");
    # $log->info("Importing log: $server_id\n");
    eval {
	# my $parser = $importers{$importer}->(server_id => $server_id);
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
log->info("Import ended...");
