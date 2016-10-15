package Stats::DB::Clan;

use strict;
use base qw/Stats::DB::Object/;

__PACKAGE__->meta->setup(table => 'clans',auto => 1);
__PACKAGE__->meta->make_manager_class('clans');

1;
