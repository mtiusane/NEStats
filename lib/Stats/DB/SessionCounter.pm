package Stats::DB::SessionCounter;

use strict;
use base qw/Stats::DB::Object/;

__PACKAGE__->meta->setup(table => 'session_counters',auto => 1);
__PACKAGE__->meta->make_manager_class('session_counters');

1;
