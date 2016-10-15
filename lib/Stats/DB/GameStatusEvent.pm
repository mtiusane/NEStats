package Stats::DB::GameStatusEvent;

use strict;
use base qw/Stats::DB::Object/;

__PACKAGE__->meta->setup(table => 'game_status_events',auto => 1);
__PACKAGE__->meta->make_manager_class('game_status_events');

1;
