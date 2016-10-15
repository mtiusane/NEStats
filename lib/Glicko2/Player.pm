package Glicko2::Player;

use strict;
use warnings;
use Module::Loaded qw/is_loaded/;

# use bignum precision => -4;
if (is_loaded 'bignum') {
    # TODO: bignum results in an endless loop if using the above precision
    *f_ln = sub { $_[0]->blog };
    *f_sqrt = sub { $_[0]->bsqrt };
    *f_exp = sub { $_[0]->bexp };
    *f_pow = sub { $_[0] ** $_[1] };
    *f_sqr = sub { f_pow($_[0],2.0) };
    *f_abs = sub { $_[0]->babs };
} else {
    use Math::Complex; # Required for sqrt(x) if x < 0
    *f_ln = sub { ln($_[0]) };
    *f_sqrt = sub { sqrt($_[0]) };
    *f_exp = sub { exp($_[0]) };
    *f_pow = sub { $_[0] ** $_[1] };
    *f_sqr = sub { f_pow($_[0],2.0) };
    *f_abs = sub { abs($_[0]) };
}

use List::Util qw/sum/;
use Math::Trig qw/:pi/;

use constant tau     => 0.5;
use constant epsilon => 0.000001;

use constant default_rating     => 1500;
use constant default_rd         => 350;
use constant default_volatility => 0.06;

use constant glicko_scale => 173.7178;

use overload '""' => 'stringify';

sub new {
    my ($class,%params) = @_;
    my $self = {
	rating     => $params{rating} // default_rating,
	rd         => $params{rd} // default_rd,
	volatility => $params{volatility} // default_volatility, # aka sigma, reasonable range 0.3 to 1.2
    };
    $self->{mu} = ($self->{rating} - default_rating)/glicko_scale;
    $self->{phi} = $self->{rd}/glicko_scale;
    bless($self,$class);
}

sub rating {
    my ($self,$value) = @_;
    if (scalar(@_) > 1) {
	$self->{rating} = $value;
	$self->{mu} = ($self->{rating} - default_rating)/glicko_scale;
    }
    return $self->{rating};
}

sub rd {
    my ($self,$value) = @_;
    if (scalar(@_) > 1) {
	$self->{rd} = $value;
	$self->{phi} = $self->{rd}/glicko_scale;
    }
    return $self->{rd};
}

sub volatility {
    my ($self,$value) = @_;
    $self->{volatility} = $value if (scalar(@_) > 1);
    return $self->{volatility};
}

sub mu { $_[0]->{mu} }
sub phi { $_[0]->{phi} }

sub clone { return Glicko2::Player->new(rating => $_[0]->rating,rd => $_[0]->rd,volatility => $_[0]->volatility); }

# step 3

# g(phi), usage: $player->g()
sub g {
    my ($self) = @_;
    return 1.0 / f_sqrt(1.0+(3.0*f_sqr($self->phi)/f_sqr(pi)));
}

# E(mu,muj,phij), usage: $player->E($opponent)
sub E {
    my ($self,$opponent) = @_;
    return 1.0 / (1.0 + f_exp(-$opponent->g()*($self->mu-$opponent->mu)));
}

# v, estimated variance, usage: $player->v(@outcomes)
sub v {
    my ($self,@outcomes) = @_;
    my $v = f_pow(sum(map {
	f_sqr($_->{opponent}->g()) * $self->E($_->{opponent}) * (1.0 - $self->E($_->{opponent}))
    } @outcomes),- 1.0);
    return $v;
}

# step 4

# delta, estimated improvement in rating, usage: $player->delta(map { opponent => $_, score => 0 (loss), 0.5 (draw) or 1 (win) } @opponents)
sub delta {
    my ($self,@outcomes) = @_;
    return $self->v(@outcomes) * sum map { $_->{opponent}->g()*($_->{score} - $self->E($_->{opponent})) } @outcomes;
}

# step 5

sub a {
    my ($self) = @_;
    return f_ln(f_sqr($self->volatility));
}

sub f {
    my ($self,$x,@outcomes) = @_;
    my $expx = f_exp($x);
    my $phi2 = f_sqr($self->phi);
    my $v = $self->v(@outcomes);
    return $expx*(f_sqr($self->delta(@outcomes))-$phi2-$v-$expx)/(2.0*f_sqr($phi2+$v+$expx)) - ($x-$self->a)/f_sqr(tau);
}

sub newSigma {
    my ($self,@outcomes) = @_;
    my $A = $self->a();
    my $a = $A;

    my $delta2 = f_sqr($self->delta(@outcomes));
    my $phi2 = f_sqr($self->phi);
    my $v = $self->v(@outcomes);
    my $B;
    if ($delta2 > $phi2+$v) {
	$B = f_ln($delta2-$phi2-$v);
    } else {
	my $k = 1.0;
	while ($self->f($a-$k*tau,@outcomes) < 0.0) { $k += 1.0; }
	$B = $a-$k*tau;
    }
    my $fA = $self->f($A,@outcomes);
    my $fB = $self->f($B,@outcomes);
    while (f_abs($B-$A) > epsilon) {
	my $C = $A+($A-$B)*$fA/($fB-$fA);
	my $fC = $self->f($C,@outcomes);
	if ($fC*$fB < 0.0) {
	    $A = $B;
	    $fA = $fB;
	} else {
	    $fA /= 2.0;
	}
	$B = $C;
	$fB = $fC;
    }
    return f_exp($A/2.0);
}

sub update {
    my ($self,@outcomes) = @_;
    if (scalar(@outcomes)) {
	my $newSigma = $self->newSigma(@outcomes);
	# step6, new pre-rating period value
	my $phiStar = f_sqrt(f_sqr($self->phi)+f_sqr($newSigma));
	# step7 rating,rd
	my $newPhi = 1.0 / f_sqrt(1.0 / f_sqr($phiStar)+ 1.0 / $self->v(@outcomes));
	my $newMu = $self->mu+f_sqr($newPhi)*(sum map { $_->{opponent}->g()*($_->{score}-$self->E($_->{opponent})) } @outcomes);
        # step 8
	$self->{mu} = $newMu;
	my $oldR = $self->{rating};
	$self->{rating} = glicko_scale * $self->{mu} + default_rating;
	$self->{phi} = $newPhi;
	# $self->{rd} = glicko_scale*$self->{phi};
	$self->{volatility} = $newSigma; # TODO: Is this correct?
    } else {
	# player not participating
	$self->{phi} = f_sqrt(f_sqr($self->{phi})+f_sqr($self->volatility));
	# $self->{rd} = glicko_scale*$self->{phi};
    }
    $self->{rd} = glicko_scale*$self->{phi};
}

sub stringify {
    my ($player) = @_;
    return sprintf('{ r = %f rd = %f vol = %f }',$player->rating,$player->rd,$player->volatility);
}

1;
