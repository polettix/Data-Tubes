use strict;
use Test::More;
use Data::Dumper;
use Path::Tiny;

use Text::Tubes qw< summon >;

my @functions = qw<
  dispatch_to_files
  write_to_handle
  write_to_file
>;
summon({'+Writer' => \@functions,});
ok __PACKAGE__->can($_), "summoned $_" for @functions;

{
   my $buffer = '';
   open my $fh, '>', \$buffer or die "open(): $!";

   my $wth = write_to_handle(handle => $fh);
   $wth->({rendered => "hello\n"});
   $wth->({rendered => "you"});

   close $fh;

   is $buffer, "hello\nyou", 'wrote to handle';
}

{
   my @buffers;
   my $wtf = write_to_file(
      filename => sub {
         push @buffers, '';
         return \$buffers[-1];
      },
      records_threshold => 1,
   );
   $wtf->({rendered => "hello\n"});
   $wtf->({rendered => "you"});
   $wtf = undef;    # ensure all buffers are flushed and handles are closed
   is scalar(@buffers), 2, 'two "files" generated';
   is $buffers[0], "hello\n", 'content of first "file"';
   is $buffers[1], 'you',     'content of second "file"';
}

my $me = path(__FILE__);
my $td = $me->sibling($me->basename() . '.tmp');
$td->remove_tree() if $td->is_dir();     # clean-up in case it's dirty
$td->remove()      if $td->is_file();    # clean-up in case it's dirty
$td->mkpath();

{
   my $filename = $td->child('first.txt');
   {
      my $wtf = write_to_file(filename => $filename->stringify(),);
      $wtf->({rendered => "hello\n"});
      $wtf->({rendered => "you"});
   }
   my @children = $td->children();
   is scalar(@children), 1, 'one file created';
   my $content = $filename->slurp_raw();
   is $content, "hello\nyou", 'content of only file';
   $filename->remove();
}

{
   my $template = $td->child('second%02d.txt');
   {
      my $wtf = write_to_file(
         filename          => $template->stringify(),
         records_threshold => 1
      );
      $wtf->({rendered => "hello\n"});
      $wtf->({rendered => "you"});
   }
   my @children =
     sort { $a->stringify() cmp $b->stringify() } $td->children();
   is scalar(@children), 2, 'two files created';
   my $content = $children[0]->slurp_raw();
   is $content, "hello\n", 'content of first file';
   is $children[0]->basename(), 'second00.txt', 'name of first file';
   $content = $children[1]->slurp_raw();
   is $content, "you", 'content of second file';
   is $children[1]->basename(), 'second01.txt', 'name of second file';
   $_->remove() for @children;
}

{
   my $template = $td->child('third.txt');
   {
      my $wtf = write_to_file(
         filename          => $template->stringify(),
         records_threshold => 1
      );
      $wtf->({rendered => "hello\n"});
      $wtf->({rendered => "you"});
   }
   my @children =
     sort { $a->stringify() cmp $b->stringify() } $td->children();
   is scalar(@children), 2, 'two files created';
   my $content = $children[0]->slurp_raw();
   is $content, "hello\n", 'content of first file';
   is $children[0]->basename(), 'third.txt', 'name of first file';
   $content = $children[1]->slurp_raw();
   is $content, "you", 'content of second file';
   is $children[1]->basename(), 'third.txt_1', 'name of second file';
   $_->remove() for @children;
}

{
   my $template = $td->child('third.txt');
   {
      my $dtf = dispatch_to_files(
         key => [qw< structured class >],
         filename_template =>
           $td->child('fourth-[% key %]-%02d.txt')->stringify(),
         records_threshold => 1
      );
      $dtf->({rendered => "hello\n", structured => {class => 'whatever'}});
      $dtf->({rendered => "you",     structured => {class => 'hey'}});
      $dtf->({rendered => "ciao",    structured => {class => 'whatever'}});
      $dtf->({rendered => "tube",    structured => {class => 'hey'}});
   }
   my @children =
     sort { $a->stringify() cmp $b->stringify() } $td->children();
   is scalar(@children), 4, 'four files created';

   my $content = $children[0]->slurp_raw();
   is $content, "you", 'content of first file';
   is $children[0]->basename(), 'fourth-hey-00.txt', 'name of first file';

   my $content = $children[1]->slurp_raw();
   is $content, "tube", 'content of second file';
   is $children[1]->basename(), 'fourth-hey-01.txt', 'name of second file';

   my $content = $children[2]->slurp_raw();
   is $content, "hello\n", 'content of third file';
   is $children[2]->basename(), 'fourth-whatever-00.txt',
     'name of third file';

   my $content = $children[3]->slurp_raw();
   is $content, "ciao", 'content of fourth file';
   is $children[3]->basename(), 'fourth-whatever-01.txt',
     'name of fourth file';

   $_->remove() for @children;
}

$td->remove_tree();    # clean-up

done_testing();
