package Stats::DB::BuildingEvent;

use strict;
use base qw/Stats::DB::Object/;

__PACKAGE__->meta->setup(table => 'building_events',auto => 1);
__PACKAGE__->meta->make_manager_class('building_events');

1;
