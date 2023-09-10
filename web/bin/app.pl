#!/usr/bin/env perl
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use NEStats;
use NEStatsJSON;
use Plack::Builder;

builder {
    mount '/'     => NEStats->to_app,
    mount '/json' => NEStatsJSON->to_app,
};
