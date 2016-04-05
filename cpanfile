requires 'perl',                '5.010000';
requires 'Log::Log4perl::Tiny', '1.2.9';
requires 'Template::Perlish',   '1.50';
requires 'Mo',                  '0.39';
recommends 'Try::Tiny',         '0.24';

on test => sub {
   requires 'Path::Tiny', '0.084';
   requires 'Try::Tiny', '0.24';
};
