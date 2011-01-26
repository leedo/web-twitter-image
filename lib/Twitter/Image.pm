package Twitter::Image;

use Imager;
use Imager::Font::Wrap;
use Date::Parse;
use DateTime;
use HTML::Entities;

use base 'Exporter';
our @EXPORT = qw/tweet_image/;

my $blue = Imager::Color->new(155, 229, 233);
my $white = Imager::Color->new(255, 255, 255);
my $font = Imager::Font->new(
  file => "Verdana.ttf",
  color => "black",
  aa => 1,
  size => 12,
);

sub tweet_image {
  my $tweet = shift;

  my $author = "$tweet->{user}{name} (\@$tweet->{user}{screen_name})";
  my $text = decode_entities $tweet->{text};
  my @date = strptime($tweet->{created_at});
  $date[4]++;
  $date[5] += 1900;
  my $date = sprintf "%02d/%02d/%04d %02d:%02d", @date[4,3,5,2,1];

  my @d = Imager::Font::Wrap->wrap_text(
    string => $text, font => $font, width => 270,
    image => undef
  );

  my $text_height = $d[3];
  my $inner_height = $text_height + 20;
  my $height = $inner_height + 30;

  my $img = Imager->new(xsize => 300, ysize => $height + 15, channels => 4);

  $img->box(
    color => $blue, xmin => 0, ymin => 0,
    xmax => 300, ymax => $height, filled => 1,
  );

  $img->box(
    color => $white, xmin => 10, ymin => 10,
    xmax => 290, ymax => $inner_height, filled => 1,
  );

  Imager::Font::Wrap->wrap_text(
    string => $text, font => $font, width => 270,
    image => $img, x => 17, y => 5, align => 0
  );

  @d = $img->align_string(
    y => $inner_height + 17, x => 290, font => $font,
    size => 12, string => $author, align => 0,
    valign => 'center', halign => 'right'
  );

  my $length = "=" x int(rand() * 9);
  $img->align_string(
    y => $inner_height + 17, x => 10, font => $font,
    size => 9, string => "8".$length."D", align => 0,
    valign => 'center', halign => 'left',
    color => $white
  );

  my $arrowx = $d[0] - 30;
  $img->polygon(
    points => [[$arrowx, $inner_height],[$arrowx+20, $inner_height + 17],[$arrowx+20, $inner_height]],
    color => "white"
  );

  $img->align_string(
    y => $height + 5, x => 290, font => $font,
    size => 9, string => $date, align => 0,
    valign => 'top', halign => 'right',
    color => $blue
  );



  my $data;
  $img->write(data => \$data, type => "png");

  return $data;
}

1;
