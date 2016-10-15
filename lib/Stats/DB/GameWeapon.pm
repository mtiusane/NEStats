package Stats::DB::GameWeapon;

use strict;
use base qw/Stats::DB::Object/;

__PACKAGE__->meta->setup(table => 'game_weapons',auto => 1);
__PACKAGE__->meta->make_manager_class('game_weapons');

1;
