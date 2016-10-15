package Stats::DB::ClanEvent;

use strict;
use base qw/Stats::DB::Object/;

__PACKAGE__->meta->setup(table => 'clan_events',auto => 1);
__PACKAGE__->meta->make_manager_class('clan_events');

1;
