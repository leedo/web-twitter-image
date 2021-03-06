package Squiggy;

use Squiggy::Request;
use Squiggy::Response;
use Router::Simple;
use Plack::Middleware::WebSocket;

use strict;
use warnings;

use base "Exporter";
our @EXPORT = qw/get post any websocket/;
our %routers;

sub router {
  my $package = shift;

  $routers{$package} ||= do {
    my $router = Router::Simple->new;
    $router->connect(
      "/favicon.ico",
      { code => sub {[204, [], ['not found']]} },
      { method => "GET" }
    );
    $router;
  };
}

sub to_psgi {
  my $package = $_[0] || caller(0);
  my $router = router $package;

  my $app = sub {
    my $env = shift;
    $env->{'psgix.squiggy.router'} = $router;

    return sub {
      my $respond = shift;
      dispatch($env, $respond);
    };
  };

  Plack::Middleware::WebSocket->wrap($app);
}

sub dispatch {
  my ($env, $respond) = @_;

  if (my $p = $env->{'psgix.squiggy.router'}->match($env)) {
    my $cb = delete $p->{code};
    my $req = Squiggy::Request->new($env, $respond, $p);
    my $res = $req->new_response(200);
    $cb->($req, $res);
  }
  else {
    $respond->([404, [], ['not found']]);
  }
}

sub wrap_websocket {
  my $orig = shift;
  return sub {
    my ($req, $res) = @_;
    if (my $fh = $req->env->{'websocket.impl'}->handshake) {
      $orig->($req, $fh);
    }
    else {
      $res->code($req->env->{'websocket.impl'}->error_code);
      $res->send;
    }
  };
}

sub add_route {
  my ($method, $package, $route, $sub) = @_;
  my $router = router $package;

  if ($method eq "WEBSOCKET") {
    $method = "GET";
    $sub = wrap_websocket $sub;
  }

  $router->connect($route,
    { code => $sub },
    { method => $method },
  );

  to_psgi $package; 
}

for my $method (qw/get post any websocket/) {
  no strict;
  *{__PACKAGE__."::$method"} = sub {
    my $package = caller(0);
    add_route uc $method, $package, @_;
  };
}

1;
