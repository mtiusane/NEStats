package Stats::DB::PlayerEvent;

use strict;
use base qw/Stats::DB::Object/;

__PACKAGE__->meta->setup(table => 'player_events',auto => 1);
__PACKAGE__->meta->make_manager_class('player_events');

1;
