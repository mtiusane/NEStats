package Stats::Util;

use strict;
use warnings;

use base qw/Exporter/;
our @EXPORT_OK = qw/replace_colors replace_smileys replace_all remove_all weapon_name format_duration db_to_hashref/;

use CGI qw/escapeHTML/;
use Stats::DB::Weapon;
use DateTime::Format::Duration;

use Stats::Emoticons qw/$emoticons/;

my %color_names = (
    '0' => 'color0',
    '1' => 'color1',
    '2' => 'color2',
    '3' => 'color3',
    '4' => 'color4',
    '5' => 'color5',
    '6' => 'color6',
    '7' => 'color7',
    '8' => 'color8',
    '9' => 'color9',
    ':' => 'color_colon',
    ';' => 'color_semicolon',
    '<' => 'color_lt',
    '=' => 'color_eq',
    '>' => 'color_gt',
    '?' => 'color_question',
    '@' => 'color_at',
    'a' => 'color_a',
    'b' => 'color_b',
    'c' => 'color_c',
    'd' => 'color_d',
    'e' => 'color_e',
    'f' => 'color_f',
    'g' => 'color_g',
    'h' => 'color_h',
    'i' => 'color_i',
    'j' => 'color_j',
    'k' => 'color_k',
    'l' => 'color_l',
    'm' => 'color_m',
    'n' => 'color_n',
    'o' => 'color_o',
    '*' => 'color7' # reset color
);

sub replace_colors {
    my ($line) = @_;
    my $result = '<span class="color7">';
    $line =~ s|\G(?<p>.*?)\^(?<c>[0-9a-o\:\;\<\=\>\?\@])|$+{p}.'</span><span class="'.($color_names{lc($+{c})} // 'color7').'">'|gei;
    $line =~ s|\G(?<p>.*?)\^x(?<c>[0-9a-f]{3})|$+{p}.'</span><span class="color" style="color: #'.lc($+{c}).'">'|gei;
    $line =~ s|\G(?<p>.*?)\^#(?<c>[0-9a-f]{6})|$+{p}.'</span><span class="color" style="color: #'.lc($+{c}).'">'|gei;
    return $result.$line.'</span>';
}

sub replace_smileys {
    my ($line) = @_;
    $line = escapeHTML($line);
    $line =~ s|\[($emoticons)\]|'<span class="smiley smiley_'.lc($1).'"></span>'|ge;
    return $line;
}

sub replace_all {
    my ($line) = @_;
    return replace_colors(replace_smileys($line));
}

sub remove_all {
    my ($line) = @_;
    $line =~ s/\^.//g;
    $line =~ s/\[($emoticons)\]//g;
    return $line;
}

# my $weapon_names = { };
# sub weapon_name
# {
#     my ($name) = @_;
#     return $weapon_names->{$name} if ($weapon_names->{$name});
#     my $weapon = Stats::DB::Weapon->new(server_id => $server->id,name => $name);
#     return $weapon_names->{$name} = ($weapon->load(speculative => 1)) ? replace_all($weapon->displayname) : $name;
# }

my $format = DateTime::Format::Duration->new(pattern => '%H:%M:%S',normalize => 1);
sub format_duration {
    return $format->format_duration(DateTime::Duration->new(seconds => $_[0]));
}

sub db_to_hashref {
    my ($obj) = @_;
    return defined($obj) ? +{ map { $_ => $obj->$_ } $obj->meta->column_names } : +{ };
}

1;
