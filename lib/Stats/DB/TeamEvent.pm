package Stats::DB::TeamEvent;

use strict;
use base qw/Stats::DB::Object/;

__PACKAGE__->meta->setup(table => 'team_events',auto => 1);
__PACKAGE__->meta->make_manager_class('team_events');

1;
