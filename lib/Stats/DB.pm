package Stats::DB;

use strict;
use base qw/Rose::DB/;
use Sys::Hostname;

__PACKAGE__->use_private_registry;
__PACKAGE__->register_db(
    domain   => 'development',
    driver   => 'mysql',
    database => 'stats',
    host     => 'localhost',
    username => 'stats',
    password => 'stats',
);
__PACKAGE__->register_db(
    domain   => 'production',
    driver   => 'mysql',
    database => 'stats',
    host     => '10.129.233.222',
    username => 'stats',
    password => 'stats',
);
__PACKAGE__->register_db(
    domain   => 'development_realdb',
    driver   => 'mysql',
    database => 'stats',
    host     => '127.0.0.1',
    port     => 31337,
    username => 'stats',
    password => 'stats',
);

__PACKAGE__->default_domain((hostname =~ /\.new-edge\.org$/) ? 'production' : 'development_realdb');
__PACKAGE__->default_connect_options({ mysql_auto_reconnect => 1 });

1;
