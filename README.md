# NAME

Dist::Zilla::Role::File::ChangeNotification - Receive notification when something changes a file's contents

# VERSION

version 0.003

# SYNOPSIS

    package Dist::Zilla::Plugin::MyPlugin;
    sub some_phase
    {
        my $self = shift;

        my ($source_file) = grep { $_->name eq $self->source } @{$self->zilla->files};
        # ... do something with this file ...

        Dist::Zilla::Role::File::ChangeNotification->meta->apply($source_file);
        my $plugin = $self;
        $file->on_changed(sub {
            $plugin->log_fatal('someone tried to munge ', shift->name,
                ' after we read from it. You need to adjust the load order of your plugins.');
        });
        $file->watch_file;
    }

# DESCRIPTION

This is a role for [Dist::Zilla::Role::File](https://metacpan.org/pod/Dist::Zilla::Role::File) objects which gives you a
mechanism for detecting and acting on files changing their content. This is
useful if your plugin performs an action based on a file's content (perhaps
copying that content to another file), and then later in the build process,
that source file's content is later modified.

# ATTRIBUTES

## `on_changed`

A method which is invoked against the file when the file's
content has changed.  The new file content is passed as an argument.  If you
need to do something in your plugin at this point, define the sub as a closure
over your plugin object, as demonstrated in the ["SYNOPSIS"](#synopsis).

__Be careful__ of infinite loops, which can result if your sub changes the same
file's content again! Add a mechanism to return without altering content if
particular conditions are met (say that the needed content is already present,
or even the value of a particular suitably-scoped variable.

# METHODS

## `watch_file`

Once this method is called, every subsequent change to
the file's content will result in your `on_changed` sub being invoked against
the file.  The new content is passed as the argument to the sub; the return
value is ignored.

# SUPPORT

Bugs may be submitted through [the RT bug tracker](https://rt.cpan.org/Public/Dist/Display.html?Name=Dist-Zilla-Role-File-ChangeNotification)
(or [bug-Dist-Zilla-Role-File-ChangeNotification@rt.cpan.org](mailto:bug-Dist-Zilla-Role-File-ChangeNotification@rt.cpan.org)).
I am also usually active on irc, as 'ether' at `irc.perl.org`.

# SEE ALSO

- [Dist::Zilla::File::OnDisk](https://metacpan.org/pod/Dist::Zilla::File::OnDisk)
- [Dist::Zilla::File::InMemory](https://metacpan.org/pod/Dist::Zilla::File::InMemory)

# AUTHOR

Karen Etheridge <ether@cpan.org>

# COPYRIGHT AND LICENSE

This software is copyright (c) 2013 by Karen Etheridge.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

# CONTRIBUTOR

Yanick Champoux <yanick@babyl.dyndns.org>
