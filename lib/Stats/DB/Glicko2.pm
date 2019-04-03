package Stats::DB::Glicko2;

use strict;
use base qw/Stats::DB::Object/;
use Stats::DB;

__PACKAGE__->meta->setup(table => 'player_glicko2',auto => 1);
__PACKAGE__->meta->make_manager_class('glicko2');

sub get_rating_range {
    my ($class, %args) = @_;
    my $db = $args{'db'} || Stats::DB->new_or_cached();
    my $sth = $db->dbh->prepare('select min(rating),max(rating),min(rating-rd),max(rating+rd) from player_glicko2 where update_count > 0');
    $sth->execute;
    my ($minRating,$maxRating,$minRange,$maxRange) = $sth->fetchrow_array;
    $sth->finish;
    return {
        min_rating => $minRating,
        max_rating => $maxRating,
        min_range  => $minRange,
        max_range  => $maxRange
    }
}

1;
