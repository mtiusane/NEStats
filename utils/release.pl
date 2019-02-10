#!/usr/bin/perl

use strict;
use warnings;
use File::Temp;
use File::Find;
use File::Copy;
use Cwd qw/realpath getcwd/;
use File::Spec;
use File::Basename qw/basename/;

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

my %targets = (
    webroot => {
	sourcePaths => [ "../web","../lib" ],
	pkgName     => 'dist_web.tar.gz'
    },
    importerroot => {
	sourcePaths => [ "../importer","../lib" ],
	pkgName     => 'dist_importer.tar.gz'
    }
);

my $tempDirRoot = File::Temp->newdir(CLEANUP => 1);
while(my ($targetName, $target) = each(%targets))
{
    my $tempRoot = "$tempDirRoot/$targetName";
    mkdir $tempRoot;
    
    print "Generating file list...\n";
    my @files = list_files($tempRoot,@{$target->{sourcePaths}});

    print "Copying / compressing files...\n";
    copy_files(@files);

    print "Creating package \"$target->{pkgName}\"...\n";
    create_package($target->{pkgName}, $tempRoot);
}
print "Done\n";

sub list_files
{
    my ($targetRoot, @sourcePaths) = @_;
    my @files;
    foreach my $sourcePath (@sourcePaths) {
	my $basePath = basename($sourcePath);
	my $targetDir = "$targetRoot/$basePath";
	my $realSource = realpath($sourcePath);
	my $skipRe = join('|',@skipRe);
	push @files, { type => 'd', target => $targetDir };
	find({
	    no_chdir => 1,
	    wanted   => sub {
		unless (/$skipRe/) {
		    my $filename = File::Spec->abs2rel($_,$realSource);
		    my $target = "$targetDir/$filename";
		    if (-d) {
			push @files, { type => 'd', target => $target };
		    } elsif (-f) {
			push @files, { type => 'f', source => $_, target => $target };
		    }
		}
	    }
	}, $realSource);
    }
    return @files;
}

sub copy_files
{
    my (@files) = @_;
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
}

sub compress_js
{
    my ($source,$target) = @_;
    system "java -jar closure-compiler-v20171112.jar --js_output_file $target $source";
}

sub create_package
{
    my ($pkgName,$root) = @_;
    my $dir = getcwd();
    chdir $root;
    system "tar -czf \"$dir/$pkgName\" .";
    chdir $dir;
}
