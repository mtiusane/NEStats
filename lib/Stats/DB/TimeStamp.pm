package Stats::DB::TimeStamp;

use strict;
use base qw/Stats::DB::Object/;

__PACKAGE__->meta->setup(table => 'timestamps',auto => 1);
__PACKAGE__->meta->make_manager_class('timestamps');

1;
