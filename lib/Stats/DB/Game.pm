package Stats::DB::Game;

use strict;
use base qw/Stats::DB::Object/;

__PACKAGE__->meta->setup(table => 'games',auto => 1);
__PACKAGE__->meta->make_manager_class('games');

1;
