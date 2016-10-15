package Stats::DB::Player;

use strict;
use base qw/Stats::DB::Object/;

__PACKAGE__->meta->setup(table => 'players',auto => 1);
__PACKAGE__->meta->make_manager_class('players');

1;
