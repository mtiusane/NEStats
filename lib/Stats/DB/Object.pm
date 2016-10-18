package Stats::DB::Object;

use strict;
use base qw/Rose::DB::Object/;
use DateTime;

use Stats::DB;

sub init_db { Stats::DB->new_or_cached; }

sub TO_JSON { return { %{ shift() } }; }
sub DateTime::TO_JSON { return $_[0]->datetime.'.000Z'; }

1;
