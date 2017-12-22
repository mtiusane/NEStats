#!/usr/bin/perl

use strict;
use warnings;
use File::Temp;
use File::Find;
use File::Copy;
use Cwd qw/realpath getcwd/;
use File::Spec;

my $sourcePath = "../web";
my @skipRe = (
    qr|sessions/.*$|,
    qr|~$|,
    qr|.bash_history$|,
    qr|PLAN.txt$|,
    qr|doc/.*$|,
    qr|doc$|,
    qr|MANIFEST(?:.SKIP)?$|,
    qr|local.*$|
);

my $tempDir = File::Temp->newdir(CLEANUP => 1);

my $realSource = realpath($sourcePath);
my $skipRe = join('|',@skipRe);
my @files;
find({
    no_chdir => 1,
    wanted =>  sub {
	unless (/$skipRe/) {
	    my $filename = File::Spec->abs2rel($_,$realSource);
	    my $target = "$tempDir/$filename";
	    if (-d) {
		push @files, { type => 'd', target => $target };
	    } elsif (-f) {
		push @files, { type => 'f', source => $_, target => $target };
	    }
	}
    }
}, $realSource);


foreach my $file (@files) {
    if ($file->{type} eq 'd') {
	mkdir($file->{target});
    } elsif ($file->{type} eq 'f') {
	if ($file->{target} =~ /(?<!min)\.js$/) {
	    compress_js($file->{source},$file->{target});
	} else {
	    copy($file->{source},$file->{target});
	}
    }
}
my $dir = getcwd();
chdir $tempDir;
system "tar -czf $dir/dist.tar.gz .";
chdir $dir;

sub compress_js
{
    my ($source,$target) = @_;
    system "java -jar closure-compiler-v20171112.jar --js_output_file $target $source";
}
