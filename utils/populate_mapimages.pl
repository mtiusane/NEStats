#!/usr/bin/perl

use strict;
use warnings;

use lib '../lib';

use Stats::DB::Map;
use File::Path qw/mkpath/;
use File::Temp qw/tempfile tempdir/;
use File::Copy qw/copy/;
use Archive::Zip qw/:ERROR_CODES :CONSTANTS/;
use Fcntl qw/SEEK_SET SEEK_END/;
use Image::Magick;

my $previewGeometry = '256x144'; # '512x288';

my $unvPath = shift || die "Syntax: $0 path-to-unv";
my $pkgPath = "$unvPath/pkg";
my $outputDir = "../web/public/images/maps";
mkpath $outputDir;
opendir DIR,$pkgPath;
while (my $path = readdir DIR) {
    next if ($path =~ /^\./);
    next if (-d $path);
    next unless ($path =~ /^map-.+\.pk3$/);
    if ($path =~ /^map-(.+)_.+\.pk3$/) {
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
		    `dwebp $tempfile -o $tempfile.png`;
		    my $readResult = $image->Read(filename => "$tempfile.png");
		    die "Failed to read extracted file: $readResult" if ("$readResult");
		    unlink "$tempfile.png";
		} elsif ($imagename =~ /\.crn$/) {
		    copy($tempfile,"$tempfile.crn");
		    `../externals/crunch/bin_linux/crunch -file $tempfile.crn -out $tempfile.png -fileformat png`;
		    my $readResult = $image->Read(filename => "$tempfile.png");
		    die "Failed to read extracted file: $readResult" if ("$readResult");
		    unlink "$tempfile.png";
		    unlink "$tempfile.crn";
		} else {
		    my $readResult = $image->Read(filename => $tempfile);
		    die "Failed to read extracted file: $readResult" if ("$readResult");
		}
		$image->Resize(geometry => $previewGeometry);
		my $writeResult = $image->Write(filename => $outputName);
		die "Failed to write output file: $writeResult" if ("$writeResult");
	    }
	}
    } else {
	print "Fail: $path\n";
    }
}
closedir DIR;
