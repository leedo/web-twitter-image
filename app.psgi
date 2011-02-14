use strict;
use warnings;

use lib "lib";

use Squiggy;
use JSON;
use File::Slurp;
use AnyEvent::Twitter;
use AnyEvent::HTTP;
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

  #if (my $data = $cache->get($id)) {
  #  $res->content_type("image/png");
  #  $res->send($data);
  #  return;
  #}

  $twitter->get("statuses/show/$id", sub {
    my ($hdr, $tweet, $reason) = @_;
    
    if ($reason ne "OK") {
      $res->not_found;
      return;
    }

    my $send = sub {
      $res->content_type("image/png");
      $res->send($_[0]);
      $cache->set($id, $_[0]);
    };

    if (my $image = $cache->get($tweet->{user}{profile_image_url})) {
      $send->(tweet_image($tweet, $image));
      return;
    }

    my $url = $tweet->{user}{profile_image_url};
    http_get $url, sub {
      my ($image, $headers) = @_;
      my @args = ($tweet);
      if ($headers->{Status} == 200) {
        push @args, $image;
        $cache->set($url, $image);
      }
      my $data = tweet_image(@args);
      $send->($data);
    };
  });
};

get qr{^/https?://?(?:www.)?twitter.com/[^/]+/status/(\d+)} => sub {
  my ($req, $res) = @_;
  my $id = $req->captures->{splat}[0];

  $res->forward("/$id");
};
