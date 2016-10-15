package Stats::DB::Glicko2Score;

use strict;
use base qw/Stats::DB::Object/;

__PACKAGE__->meta->setup(table => 'glicko2_scores',auto => 1);
__PACKAGE__->meta->make_manager_class('glicko2_scores');

1;
