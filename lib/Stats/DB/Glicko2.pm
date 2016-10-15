package Stats::DB::Glicko2;

use strict;
use base qw/Stats::DB::Object/;

__PACKAGE__->meta->setup(table => 'player_glicko2',auto => 1);
__PACKAGE__->meta->make_manager_class('glicko2');

1;
