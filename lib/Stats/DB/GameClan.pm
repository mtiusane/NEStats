package Stats::DB::GameClan;

use strict;
use base qw/Stats::DB::Object/;

__PACKAGE__->meta->setup(table => 'game_clans',auto => 1);
__PACKAGE__->meta->make_manager_class('game_clans');

1;
