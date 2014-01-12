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

    sub munge_files
    {
        my $self = shift;

        my ($file) = grep { $_->name =~ /Foo/ } @{$self->zilla->files};

        use_module('Dist::Zilla::Role::File::ChangeNotification')->meta->apply($file);

        my $plugin = $self;
        $file->on_changed(sub {
            my $self = shift;

            return if $self->content =~ /__END__/;

            $self->content( $file->content . "\n__END__\n" );
        });

        $file->watch_file;
    }
}

{
    package Dist::Zilla::Plugin::MyPlugin2;
    use Moose;
    with 'Dist::Zilla::Role::FileMunger';

    sub munge_files {
        my $self = shift;

        my ($file) = grep { $_->name =~ /Foo/ } @{$self->zilla->files};

        $file->content( 'package Foo; 2;' );
    }

}

{
    package Dist::Zilla::Plugin::MyPlugin3;
    use Moose;
    with 'Dist::Zilla::Role::FileMunger';

    sub munge_files {
        my $self = shift;

        my ($file) = grep { $_->name =~ /Foo/ } @{$self->zilla->files};

        $file->content( 'package Foo; 1;' );
    }

}

my $tzil = Builder->from_config(
    { dist_root => 't/does-not-exist' },
    {
        add_files => {
            'source/dist.ini' => simple_ini(
                [ 'GatherDir' ],
                [ 'MyPlugin' ],
                [ 'MyPlugin2' ],
                [ 'MyPlugin3' ],
            ),
            path(qw(source lib Foo.pm)) => 'package Foo; 1;',
        },
    },
);

$tzil->build;

like $tzil->slurp_file( 'build/lib/Foo.pm' ) => qr'__END__';

done_testing;
