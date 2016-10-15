package Stats::DB::PlayerWeapon;

use strict;
use base qw/Stats::DB::Object/;

__PACKAGE__->meta->setup(table => 'player_weapons',auto => 1);
__PACKAGE__->meta->make_manager_class('player_weapons');

1;
