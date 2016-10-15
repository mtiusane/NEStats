package Stats::DB::PlayerRanking;

use strict;
use base qw/Stats::DB::Object/;

use Stats::DB::Player;
use Stats::DB::Glicko2;

__PACKAGE__->meta->setup(table => 'player_rankings',foreign_keys => [
    player => { class => 'Stats::DB::Player', key_columns => { player_id => 'id' } },
    glicko2 => { class => 'Stats::DB::Glicko2', key_columns => { glicko2_id => 'id' } }
],auto => 1);
__PACKAGE__->meta->make_manager_class('player_rankings');

1;
