package Stats::DB::Session;

use strict;
use base qw/Stats::DB::Object/;

__PACKAGE__->meta->setup(table => 'sessions',auto => 1);
__PACKAGE__->meta->make_manager_class('sessions');

1;
