package Squiggy::Response;

use strict;
use warnings;

use parent 'Plack::Response';
require Squiggy;

sub new {
  my($class, $env, $cb) = @_;

  Carp::croak(q{$env is required})
    unless defined $env && ref($env) eq 'HASH';
  Carp::croak(q{$cb is required})
    unless defined $cb && ref($cb) eq 'CODE';

  my $self = bless {env => $env, cb => $cb}, $class;
  $self->status(200);
  $self->content_type("text/html");

  $self;
}

sub send {
  my ($self, $body) = @_;

  die "sending on a closed response" if $self->{closed};
  die "sending on a streaming response" if $self->{writer};

  $self->body($body) if defined $body;
  $self->content_length(length $self->body);
  
  $self->{cb}->($self->SUPER::finalize);
  $self->{closed} = 1;
}

sub write {
  my ($self, $chunk) = @_;

  die "writing on a closed response" if $self->{closed};

  if (!$self->{writer}) {
    my $response = $self->SUPER::finalize;
    $self->{writer} = $self->{cb}->([$response->[0,1]]);
    $self->{writer}->write($response->[2]) if $response->[2];
  }
  
  $self->{writer}->write($chunk);
}

sub close {
  my $self = shift;

  if ($self->{writer}) {
    $self->{writer}->close;
  }

  $self->{closed} = 1;
}

sub forward {
  my ($self, $dest) = @_;
  $self->{env}->{PATH_INFO} = $dest;
  Squiggy::dispatch($self->{env}, $self->{cb});
}

1;
