#!/usr/bin/perl

use strict;
use warnings;

my $emoticons_path; # = '../new-edge/assets/emoticons/*.tga';
my $emoticons_regex; # = qr/^(?:.+)\/(\S+?)_(\d+)x(\d+)\.tga$/;
die "Change to use correct paths first!" unless defined($emoticons_path) and defined($emoticons_regex);
# TODO: Not yet updated to work with unv sources/files.

my $header = qq|
/* Tremulous color codes */
span.color0 { margin: 0px; padding: 0px; color: #656565; }
span.color1 { margin: 0px; padding: 0px; color: #ff0000; }
span.color2 { margin: 0px; padding: 0px; color: #00ff00; }
span.color3 { margin: 0px; padding: 0px; color: #ffff00; }
span.color4 { margin: 0px; padding: 0px; color: #0000ff; }
span.color5 { margin: 0px; padding: 0px; color: #00ffff; }
span.color6 { margin: 0px; padding: 0px; color: #ff00ff; }
span.color7 { margin: 0px; padding: 0px; color: #ffffff; }

/* Default smiley (used when no real definition found) */
span.smiley { margin-left: 0px; margin-right: 0px; margin-top: 0px; margin-bottom: -4px; padding-bottom: 0px; padding-left: 0px; padding-right: 0px; padding-top: 0px; display: inline-block; width: 1em; height: 1em; background-color: transparent; background-origin: content-box; background-repeat: no-repeat; background-size: contain; background-position: center center; }
span.smiley.left { min-width: 3em; background-position: right center; }
span.smiley.right { min-width: 3em; background-position: left center; }

/* Tremulous smileys */
|;

print "Generating emoticons.css\n";
open FO,">emoticons.css";
print FO $header;
foreach my $file (<$emoticons_path>) {
    if ($file =~ /^(?:.+)\/(\S+?)_(\d+)x(\d+)\.tga$/) {
	print FO "span.smiley_$1 { display: inline-block; background-image: url(\"res/emoticons/$1.png\"); background-size: contain; background-color: transparent; width: $2em; height: $3em; }\n";
    }
}
close FO;
print "Generating ../lib/Stats/Emoticons.pm\n";
open FO,">../lib/Stats/Emoticons.pm";
print FO "package Stats::Emoticons;\n\n";
print FO "use strict;\nuse warnings;\n\n";
print FO "use base qw/Exporter/;\n";
print FO "our \@EXPORT_OK = qw/\@emoticons \$emoticons/;\n\n";
print FO "our \@emoticons = (\n";
foreach my $file (<../new-edge/assets/emoticons/*.tga>) {
    if ($file =~ /$emoticons_regex/) {
	print FO "  \"$1\",\n";
    }
}
print FO ");\n";
print FO "our \$emoticons = join('|',\@emoticons);\n";
close FO;
