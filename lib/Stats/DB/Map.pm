package Stats::DB::Map;

use strict;
use base qw/Stats::DB::Object/;

__PACKAGE__->meta->setup(table => 'maps',auto => 1);
__PACKAGE__->meta->make_manager_class('maps');

1;
