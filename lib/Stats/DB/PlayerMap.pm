package Stats::DB::PlayerMap;

use strict;
use base qw/Stats::DB::Object/;

__PACKAGE__->meta->setup(table => 'player_maps',auto => 1);
__PACKAGE__->meta->make_manager_class('player_maps');

1;
