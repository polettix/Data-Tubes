requires 'Mo';
requires 'Log::Log4perl::Tiny', '1.2.7';
requires 'Template::Perlish',   '1.50';

on test => sub {
   requires 'Path::Tiny';
};
