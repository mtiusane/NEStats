#!/usr/bin/perl

use strict;
use warnings;

use lib '../lib';

# use Stats::DB::Map;
use File::Path qw/mkpath/;
use File::Temp qw/tempfile tempdir/;
use File::Copy qw/copy/;
use Archive::Zip qw/:ERROR_CODES :CONSTANTS/;
use Fcntl qw/SEEK_SET SEEK_END/;
use Image::Magick;

chomp(my $crunch = `which crunch`) or '../externals/crunch/bin_linux/crunch' or die "crunch not found.";
chomp(my $dwebp = `which dwebp`) or die "dwebp not found, install libwebp.";

print "Using:\n - crunch: $crunch\n - dwebp: $dwebp\n";

my $previewGeometry = '512x288';

my @errors;
sub error 
{
    my ($message) = @_;
    push @errors, "$message\n";
    print "$message\n";
}

my $pkgPath = shift || die "Syntax: $0 path-to-pkg";
my $outputDir = "../web/public/images/maps";
mkpath $outputDir;
opendir DIR,$pkgPath;
while (my $path = readdir DIR) {
    next if ($path =~ /^\./);
    next if (-d $path);
    next unless ($path =~ /^map-.+\.(?:pk3|dpk)$/);
    if ($path =~ /^map-(.+)_.+\.(?:pk3|dpk)$/) {
	my $mapname = $1;
	my $fullpath = join('/',$pkgPath,$path);
	my $zip = Archive::Zip->new;
	unless($zip->read($fullpath) == AZ_OK) {
	    print "Failed to read package: $fullpath\n";
	    next;
	}
	print "$path\n";
	# my $member = $zip->memberNamed("/meta/$mapname/$mapname.arena");
	my $tempdir = tempdir(CLEANUP => 1);
	my $image = Image::Magick->new;
	foreach my $zipimage ($zip->membersMatching('meta/'.$mapname.'/'.$mapname.'\.(?:jpg|webp|tga|crn)$')) {
	    if ($zipimage->fileName =~ /\.(.+?)$/) {
		my $imagename = "$mapname.$1";
		my $outputName = join('/',$outputDir,"$mapname.png");
		print "Image: $imagename -> $outputName\n";
		my ($fh,$tempfile) = tempfile(DIR => $tempdir);
		$zipimage->extractToFileNamed($tempfile);
		if ($imagename =~ /\.webp$/) {
		    system $dwebp, $tempfile, "-o", "$tempfile.png";
		    my $readResult = $image->Read(filename => "$tempfile.png");
		    if ("$readResult") {
		        error("Failed to read extracted file for $mapname: $readResult");
			next;
		    }
		    unlink "$tempfile.png";
		} elsif ($imagename =~ /\.crn$/) {
		    copy($tempfile,"$tempfile.crn");
		    system $crunch, "-file", "$tempfile.crn", "-out", "$tempfile.png", "-fileformat", "png";
		    my $readResult = $image->Read(filename => "$tempfile.png");
		    if ("$readResult") {
		        error("Failed to read extracted file for $mapname: $readResult");
			next;
		    }
		    unlink "$tempfile.png";
		    unlink "$tempfile.crn";
		} else {
		    my $readResult = $image->Read(filename => $tempfile);
		    if ("$readResult") {
		        error("Failed to read extracted file for $mapname: $readResult");
		        next;
	            }
	        }
		$image->Resize(geometry => $previewGeometry);
		my $writeResult = $image->Write(filename => $outputName);
		if ("$writeResult") {
		    error("Failed to write output file: for $mapname: $writeResult");
		    next;
	        }
	    }
	}
    } else {
	print "Fail: $path\n";
    }
}
closedir DIR;
