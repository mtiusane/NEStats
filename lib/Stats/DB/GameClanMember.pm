package Stats::DB::GameClanMember;

use strict;
use base qw/Stats::DB::Object/;

__PACKAGE__->meta->setup(table => 'game_clan_members',auto => 1);
__PACKAGE__->meta->make_manager_class('game_clan_members');

1;
