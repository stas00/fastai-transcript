#!/usr/bin/perl

use strict;
use warnings;

use Data::Dumper;
use POSIX ();
use LWP::UserAgent;

my $ua = LWP::UserAgent->new();

sub time2secs { $_ = shift; s/(\d\d):(\d\d):(\d\d)/$1*3600+$2*60+$3/e; $_ }

sub map_timeline {
    my ($timestamp, $header, $text, $s, $ts, $c) = @_;
    my $secs = time2secs($timestamp);

    my $sub = get_subs($secs, $s, $ts, $c);
    my $header_n = $c+1;
    $header = qq[<h3>$header_n. $header</h3>\n\n];

#print "[$text]\n";

    $text = join "\n\n", qq[<ul style="list-style-type: square;">], map({"<li><b>$_</b></li>" if length($_)} split /<br>[\n]/, $text), "</ul>\n\n";
#    $t =~ s#^<li><b>##;

    return $header.$text.$sub;
}

sub get_subs {
    my ($timestamp, $s, $ts, $c) = @_;
    my @subs = ();

    my $start = $ts->[$c];
    my $end = $ts->[$c+1] || 100000; # if there is no end use some big secs
print "[$c][$start] ... [$end]\n";

    while (@$s) {

        my $r = shift @$s;
        if ($r->[0] >= $end) {
            # put the last record back
            unshift @$s, $r;
            last;
        }
        push @subs, $r->[1]
    }
    my $text = join " ", @subs;
    # XXX: add a link to github here
    my $warn = qq[<p style="color: #aaaaaa; text-align: center">(autogenerated subtitles follow, may contain gibberish/bad format - please proofread to improve - remove this note once proofread)</p>\n\n];

    ## XXX: temp: while developing if you want to avoid the hude delay
    ## of remote punctuating, bypass that part of the build - only
    ## re-enable when everything else is happy
    #return $warn.$text;

    # Use AI to reconstruct punctuation and make sentences.
    my $res = $ua->post("http://bark.phon.ioc.ee/punctuator", {text => $text});
    if ($res->is_success) {
        $text = $res->decoded_content();
        $text = cleanup_subs($text);
    }
    else {
        die "failed to punctuate: " . $res->status_line;
    }

    return $warn.$text;
}

sub cleanup_subs {
    local $_ = shift;

    # formatting - fix weird we'Re and It'S
    s|('[A-Z])|lc($1)|eg;

    # garbage
    s|\[,? Music,? \]||msg;

    # common mispellings
    s#Cagle|Cargill#Kaggle#ig;
    s#Kressel#Crestle#ig;
    s#fast,? AI|first AI|FASTA guy#fastai#ig;
    s#panda's#pandas#ig;
    s#Curly's#curlies#ig;
    s#Pi ?torch|paytorch|hi ?torch#pytorch#ig;
    s#SK learns?#scikit-learn#ig;
    s#SJD#SGD#ig;
    s#W get#wget#ig;


    # keep the text narrow in markup to make future patches easier
    s|(.{60,75}) |$1 \n|msg;

    # add some artificial paras
    s|(.{1300,1500} [a-z]+\.) +([A-Z])|$1\n\n$2|msg;
    $_ = join "\n\n", map {"<p>$_</p>"} split /\n\n/, $_;

    return "\n".$_."\n";
}

sub fcontent {
    my $f = shift;
    open my $fh, "<$f" or die "Can't open: $f: $!";
    my $t = do { local $/; <$fh> };
    close $fh;
    return $t;
}

sub make_html_file_cover {

    # write the final html one folder up - it will be edited later
    my $f = "../cover.html";
    open my $fh, ">$f" or die "$!";

    my $date = POSIX::strftime('%Y-%m-%d', localtime());

    print $fh <<"END";
<!DOCTYPE html>
<html lang="en">
  <head>
    <title>fast.ai: Deep Learning Part 2 (v2) (2018)</title>
    <meta charset="UTF-8">
  </head>
  <body>

  <p>&nbsp</p>
  <p>&nbsp</p>
  <p>&nbsp</p>

  <h1 style="text-align: center"><a href="http://course.fast.ai/part2.html">fast.ai: Deep Learning Part 2 (v2) (2018)</a></h1>

  <p>&nbsp</p>
  <p>&nbsp</p>

  <p style="text-align: center">7 Video lesson transcripts based on youtube.com autogenerated subtitles.</p>

  <p>&nbsp</p>

  <p style="text-align: center">Discussion forum: <a href="http://forums.fast.ai/c/part2-v2">http://forums.fast.ai/</a>.</p>

  <p>&nbsp</p>
  <p>&nbsp</p>

  <p style="text-align: center"><b>Version 0.1 ($date) (proofreading progress: 2%)</b>.</p>

  <p>&nbsp</p>
  <p>&nbsp</p>

  <p style="text-align: center"><b>If you'd like to contribute with proofreading, please see: <a href="https://github.com/stas00/fastai-transcript/">https://github.com/stas00/fastai-transcript/</a></b>.</p>

  <p>&nbsp</p>
  <p>&nbsp</p>

  <p style="text-align: center"></b>Credits: <a href="http://fast.ai/">Jeremy Howard</a> (fast.ai Teacher/Founder), Eric Perbos-Brinck (<a href="http://forums.fast.ai/t/part-1-v2-complete-collection-of-video-timelines/11183">Video Timelines</a>), Ottokar Tilk (<a href="http://bark.phon.ioc.ee/punctuator">Punctuator</a>), <a href="http://stasosphere.com/">Stas Bekman</a> (Transcript making)</b>.</p>

  </body>
</html>
END
     close $fh;

}


sub make_html_file {
    my ($lesson_n, $content) = @_;

    # outline
    my $o = fcontent("outline $lesson_n.html");
    my $title = '';
    if ($o =~ s#<h2>Lesson \d+: (.*?)</h2>\W+##) {
        $title = $1;
    }

    $o = join "\n\n", map {"<p>$_</p>" } split /\n+/, $o;
    $o = "<h2>Outline</h2>\n" . $o;

    # write the final html one folder up - it will be edited later
    my $f = "../lesson $lesson_n.html";
    open my $fh, ">$f" or die "$!";

    print $fh <<"END";
<!DOCTYPE html>
<html lang="en">
  <head>
    <title>Lesson $lesson_n: $title</title>
    <meta charset="UTF-8">
  </head>
  <body>
  <p style="text-align: right"><a href="http://course.fast.ai/">fast.ai: Deep Learning Part 2 (v2) (2018)</a></p>
  <h1><a href="http://course.fast.ai/lessons/lesson$lesson_n.html">Lesson $lesson_n: $title</a></h1>
  $o

  $content

  </body>
</html>
END
     close $fh;

}

sub write_make_pdf {
    my @lessons = @_;

    my $in = join " ", map {qq["lesson $_.html"]} @lessons;
    my $out = qq["fast.ai - Deep Learning Part 2 (v2) Transcript (2018).pdf"];
    my $title = qq["fast.ai - Deep Learning Part 2 (v2)"];

    # write the final build script one folder up - it will be edited later
    my $f = "../makepdf";
    open my $fh, ">$f" or die "$!";

    print $fh <<"END";
#!/bin/sh
/home/stas/src/wkhtmltox/bin/wkhtmltopdf --load-error-handling ignore --disable-javascript  --encoding utf-8 --no-background --zoom 1.45  --outline --outline-depth 3  --footer-center "[page]" --header-center "[title]"  --title $title cover cover.html toc --disable-dotted-lines --toc-text-size-shrink 0.7 $in $out
END

    close $fh;
    chmod 0755, $f;

}


my @lessons = (8..14);

# prepare cover
make_html_file_cover();

# prepare lessons
for my $n (@lessons) {

    print "Processing: $n\n";

    # subs file
    my $s = fcontent("lesson $n.srt");

    # parse the subs file to map start timestamp to its subtitle
    my @s = ();
    while ($s =~ m#\d+\n(\d\d:\d\d:\d\d).*?\n(.*?)\n\n#msg) {
        #print "[$1]: [$2]\n";
        push @s, [time2secs($1), $2];
    }

    # video timelines
    my $t = fcontent("timeline $n.html");

    # process timelines
    $t =~ s#</?ul>##msg;
    $t =~ s#<li>[\r\n]+#<li>#msg;
    $t =~ s#[\r\n]+</li>#</li>#msg;
    $t =~ s#<p><strong>Lesson \d+</strong></p>#<h2>Video Timelines and Transcript</h2>\n#;

    # prepare a list of timeline timestamps, so that we can find the
    # range of subs to pull from the .srt file
    my @ts = ();
    while ($t =~ m#<li><p><a href=".*?">(\d\d:\d\d:\d\d)#msg) {
        push @ts, time2secs($1);
    }
    #print Dumper \@ts;

    # inject the subs into the timelines
    my $c = 0;
    $t =~ s#<li><p>(<a href=".*?">(\d\d:\d\d:\d\d)\d?</a>)(.*?)</p></li>#map_timeline($2, $1, $3, \@s, \@ts, $c++)#msge;

    # write out the final merged result
    make_html_file($n, $t);

    #print Dumper \@s;
}

# prepare build into pdf
write_make_pdf(@lessons);


__END__
