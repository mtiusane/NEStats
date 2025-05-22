package Stats::DB::Server;

use strict;
use base qw/Stats::DB::Object/;

__PACKAGE__->meta->setup(table => 'servers',auto => 1);
# __PACKAGE__->meta->unique_key([ 'name' ]);
__PACKAGE__->meta->make_manager_class('servers');

1;
