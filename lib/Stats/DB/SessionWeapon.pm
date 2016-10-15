package Stats::DB::SessionWeapon;

use strict;
use base qw/Stats::DB::Object/;

__PACKAGE__->meta->setup(table => 'session_weapons',auto => 1);
__PACKAGE__->meta->make_manager_class('session_weapons');

1;
