package Stats::DB::Object;

use strict;
use base qw/Rose::DB::Object/;

use Stats::DB;

sub init_db { Stats::DB->new_or_cached; }

sub TO_JSON { return { %{ shift() } }; }

1;
