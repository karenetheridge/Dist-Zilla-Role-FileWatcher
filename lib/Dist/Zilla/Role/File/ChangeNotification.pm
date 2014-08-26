use strict;
use warnings;
package Dist::Zilla::Role::File::ChangeNotification;
# ABSTRACT: Receive notification when something changes a file's contents
# vim: set ts=8 sw=4 tw=78 et :

use Moose::Role;
use Digest::MD5 'md5_hex';
use Encode 'encode_utf8';
use namespace::autoclean;

has _content_checksum => ( is => 'rw', isa => 'Str' );

has on_changed => (
    is => 'rw',
    isa => 'CodeRef',
    traits => ['Code'],
    handles => { has_changed => 'execute_method' },
    predicate => 'has_on_changed',
    lazy => 1,
    default => sub {
        sub {
            my ($file, $new_content) = @_;
            die 'content of ', $file->name, ' has changed!';
        }
    },
);

sub watch_file
{
    my $self = shift;

    return if $self->_content_checksum;

    # Storing a checksum initiates the "watch" process
    $self->_content_checksum($self->__calculate_checksum);
    return;
}

sub __calculate_checksum
{
    my $self = shift;
    # this may not be the correct encoding, but things should work out okay
    # anyway - all we care about is deterministically getting bytes back
    md5_hex(encode_utf8($self->content))
}

around content => sub {
    my $orig = shift;
    my $self = shift;

    # pass through if getter
    return $self->$orig if @_ < 1;

    # store the new content
    # XXX possible TODO: do not set the new content until after the callback
    # is invoked. Talk to me if you care about this in either direction!
    my $content = shift;
    $self->$orig($content);

    my $old_checksum = $self->_content_checksum;

    # do nothing extra if we haven't got a checksum yet
    return $content if not $old_checksum;

    # ...or if the content hasn't actually changed
    my $new_checksum = $self->__calculate_checksum;
    return $content if $old_checksum eq $new_checksum;

    # update the checksum to reflect the new content
    $self->_content_checksum($new_checksum);

    # invoke the callback
    $self->has_changed($content);

    return $self->content;
};

1;
__END__

=pod

=head1 SYNOPSIS

    package Dist::Zilla::Plugin::MyPlugin;
    sub some_phase
    {
        my $self = shift;

        my ($source_file) = grep { $_->name eq 'some_name' } @{$self->zilla->files};
        # ... do something with this file ...

        Dist::Zilla::Role::File::ChangeNotification->meta->apply($source_file);
        my $plugin = $self;
        $file->on_changed(sub {
            $plugin->log_fatal('someone tried to munge ', shift->name,
                ' after we read from it. You need to adjust the load order of your plugins.');
        });
        $file->watch_file;
    }

=head1 DESCRIPTION

This is a role for L<Dist::Zilla::Role::File> objects which gives you a
mechanism for detecting and acting on files changing their content. This is
useful if your plugin performs an action based on a file's content (perhaps
copying that content to another file), and then later in the build process,
that source file's content is later modified.

=head1 ATTRIBUTES

=head2 C<on_changed>

A method which is invoked against the file when the file's
content has changed.  The new file content is passed as an argument.  If you
need to do something in your plugin at this point, define the sub as a closure
over your plugin object, as demonstrated in the L</SYNOPSIS>.

B<Be careful> of infinite loops, which can result if your sub changes the same
file's content again! Add a mechanism to return without altering content if
particular conditions are met (say that the needed content is already present,
or even the value of a particular suitably-scoped variable.

=head1 METHODS

=head2 C<watch_file>

Once this method is called, every subsequent change to
the file's content will result in your C<on_changed> sub being invoked against
the file.  The new content is passed as the argument to the sub; the return
value is ignored.

=head1 LIMITATIONS

At the moment, a file can only be watched by one thing at a time. This may
change in a future release, if a valid use case can be found.

=head1 SUPPORT

=for stopwords irc

Bugs may be submitted through L<the RT bug tracker|https://rt.cpan.org/Public/Dist/Display.html?Name=Dist-Zilla-Role-File-ChangeNotification>
(or L<bug-Dist-Zilla-Role-File-ChangeNotification@rt.cpan.org|mailto:bug-Dist-Zilla-Role-File-ChangeNotification@rt.cpan.org>).
I am also usually active on irc, as 'ether' at C<irc.perl.org>.

=head1 SEE ALSO

=for :list
* L<Dist::Zilla::Role::FileWatcher> - in this distribution, for providing an interface for a plugin to watch a file
* L<Dist::Zilla::File::OnDisk>
* L<Dist::Zilla::File::InMemory>

=cut
