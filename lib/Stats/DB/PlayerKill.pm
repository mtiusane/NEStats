package Stats::DB::PlayerKill;

use strict;
use base qw/Stats::DB::Object/;

__PACKAGE__->meta->setup(table => 'player_kills',auto => 1);
__PACKAGE__->meta->make_manager_class('player_kills');

1;
