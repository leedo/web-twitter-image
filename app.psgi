use strict;
use warnings;

use lib "lib";

use Squiggy;
use JSON;
use File::Slurp;
use AnyEvent::Twitter;
use Twitter::Image;

if (!-e "twitter-auth.json") {
   die "need twitter-auth.json file, " .
       "generate it with gen_token.pl in AnyEvent::Twitter\n";
}

my $config = decode_json read_file "twitter-auth.json";
my $ua = AnyEvent::Twitter->new(%$config);

my %jobs;

sub work {
  my $id = shift;

  $ua->get("statuses/show/$id", sub {
    my ($hdr, $tweet, $reason) = @_;
    my $data = tweet_image $tweet;

    my $queue = delete $jobs{$id};
    while (my $res = shift @$queue) {
      $res->content_type("image/png");
      $res->send($data);
    }
  });
}

sub add_job {
  my ($id, $res) = @_;

  work $id unless exists $jobs{$id};
  push @{$jobs{$id}}, $res;
}

get "/{tweet:[0-9]+}" => sub {
  my ($req, $res) = @_;
  my $id = $req->captures->{tweet};

  add_job $id, $res;
};

get qr{^/https?://(?:www.)?twitter.com/[^/]+/status/(\d+)} => sub {
  my ($req, $res) = @_;
  my $id = $req->captures->{splat}[0];

  add_job $id, $res;
};
