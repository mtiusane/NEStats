package Stats::DB::ClanMember;

use strict;
use base qw/Stats::DB::Object/;

__PACKAGE__->meta->setup(table => 'clan_members',auto => 1);
__PACKAGE__->meta->make_manager_class('clan_members');

1;
