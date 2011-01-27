use strict;
use warnings;

use lib "lib";

use Squiggy;
use JSON;
use File::Slurp;
use AnyEvent::Twitter;
use Twitter::Image;
use CHI;

if (!-e "twitter-auth.json") {
   die "need twitter-auth.json file, " .
       "generate it with gen_token.pl in AnyEvent::Twitter\n";
}

my $cache = CHI->new(driver => "File", root_dir => "./cache");
my $config = decode_json read_file "twitter-auth.json";
my $twitter = AnyEvent::Twitter->new(%$config);

get qr{/([0-9]+)(?:\.png)?/?} => sub {
  my ($req, $res) = @_;
  my $id = $req->captures->{splat}[0];

  if (my $data = $cache->get($id)) {
    $res->content_type("image/png");
    $res->send($data);
    return;
  }

  $twitter->get("statuses/show/$id", sub {
    my ($hdr, $tweet, $reason) = @_;
    
    if ($reason eq "OK") {
      my $data = tweet_image $tweet;
      $res->content_type("image/png");
      $res->send($data);
      $cache->set($id, $data);
    }
    else {
      print STDERR "$reason\n";
      $res->not_found;
    }
  });
};

get qr{^/https?://?(?:www.)?twitter.com/[^/]+/status/(\d+)} => sub {
  my ($req, $res) = @_;
  my $id = $req->captures->{splat}[0];

  $res->forward("/$id");
};
