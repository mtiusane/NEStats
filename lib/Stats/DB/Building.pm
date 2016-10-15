package Stats::DB::Building;

use strict;
use base qw/Stats::DB::Object/;

__PACKAGE__->meta->setup(table => 'buildings',auto => 1);
__PACKAGE__->meta->make_manager_class('buildings');

1;
