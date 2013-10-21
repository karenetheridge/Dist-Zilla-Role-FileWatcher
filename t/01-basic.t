use strict;
use warnings FATAL => 'all';

use Test::More;
use if $ENV{AUTHOR_TESTING}, 'Test::Warnings';
use Test::Fatal;
use Test::DZil;
use Path::Tiny;

# we chdir before attempting to load the module, so we need to load it now or
# our relative path in @INC will be for naught.
use Dist::Zilla::Role::File::ChangeNotification;

{
    package Dist::Zilla::Plugin::MyPlugin;
    use Moose;
    use Module::Runtime 'use_module';
    use Moose::Util::TypeConstraints;
    with 'Dist::Zilla::Role::FileMunger';
    has source_file => (
        is => 'ro', isa => 'Str',
        required => 1,
    );
    has function => (
        is => 'ro', isa => enum([qw(uc lc)]),
        required => 1,
    );
    sub munge_files
    {
        my $self = shift;

        my ($file) = grep { $_->name eq $self->source_file } @{$self->zilla->files};

        # upper-case all the comments
        my $content = $file->content;
        $content =~ s/^# (.+)$/'# ' . uc($1)/me if $self->function eq 'uc';
        $content =~ s/^# (.+)$/'# ' . lc($1)/me if $self->function eq 'lc';
        $file->content($content);

        # lock the file so no one can alter it after we have touched it

        use_module('Dist::Zilla::Role::File::ChangeNotification')->meta->apply($file);
        my $plugin = $self;
        $file->on_changed(sub {
            my $self = shift;
            $plugin->log_fatal('someone tried to munge ' . $self->name
                .' after we read from it. You need to adjust the load order of your plugins.');
        });

        $file->watch_file;
    }
}

my $tzil = Builder->from_config(
    { dist_root => 't/does-not-exist' },
    {
        add_files => {
            'source/dist.ini' => simple_ini(
                [ GatherDir => ],
                [ MyPlugin => uc => { function => 'uc', source_file => 'lib/Foo.pm' } ],
                [ MyPlugin => lc => { function => 'lc', source_file => 'lib/Foo.pm' } ],
            ),
            path(qw(source lib Foo.pm)) => <<CODE,
package Foo;
# hErE IS a coMMent!
1
CODE
        },
    },
);

like(
    exception { $tzil->build },
    qr{someone tried to munge lib/Foo.pm after we read from it. You need to adjust the load order of your plugins},
    'detected attempt to change README after signature was created from it',
);

done_testing;
