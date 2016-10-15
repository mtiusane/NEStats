package Stats::DB::Weapon;

use strict;
use base qw/Stats::DB::Object/;

__PACKAGE__->meta->setup(table => 'weapons',auto => 1);
__PACKAGE__->meta->make_manager_class('weapons');

1;
