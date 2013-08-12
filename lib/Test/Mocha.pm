use strict;
use warnings;
package Test::Mocha;
# ABSTRACT: Test Spy Framework

=head1 SYNOPSIS

    use Test::Mocha;

    # create the mock object and stub
    my $baker = mock;
    stub($mock)->bake_loaf('white')->returns($bread);

    # execute the code under test
    my $bakery = Bakery->new( bakers => [ $baker ] );
    my @loaves = $bakery->buy_loaf( amount => 2, type => 'white' );

    # verify the interactions with the mock object
    verify($baker, times => 2)->bake_loaf('white');

=head1 DESCRIPTION

Test::Mocha is a test double framework heavily inspired by the Mockito
framework for Java, and also the Python-Mockito project. In Mockito, you "spy"
on objects for their behaviour, rather than being upfront about what should
happen. I find this approach to be significantly more flexible and easier to
work with than mocking systems like EasyMock, so I created a Perl
implementation.

=begin :list

= Mock objects

Mock objects, represented by L<Test::Mocha::Mock> objects, are objects that
pretend to be everything you could ever want them to be. A mock object can have
any method called on it, does every roles, and isa subclass of any superclass.
This allows you to easily throw a mock object around it will be treated as
though it was a real object.

= Method stubbing

Any method can be called on a mock object, and it will be logged as an
invocation. By default, method calls return C<undef> in scalar context or an
empty list in list context. Often, though, clients will be interested in the
result of calling a method with some arguments. So you may specify how a
method stub should respond when it is called.

= Verify interactions

After calling your concrete code (the code under test) you may want to check
that the code did operate correctly on the mock. To do this, you can use
verifications to make sure code was called, with correct parameters and the
correct amount of times.

= Argument matching

Mocha gives you some helpful methods to validate arguments passed in to calls.
You can check equality between arguments, or consume a general type of argument,
or consume multiple arguments. See L<Test::Mocha::ArgumentMatcher> for the
juicy details.

=end :list

=cut

use aliased 'Test::Mocha::Inspect';
use aliased 'Test::Mocha::Mock';
use aliased 'Test::Mocha::Stubber';
use aliased 'Test::Mocha::Verify';

use Carp qw( croak );
use Exporter qw( import );
use Scalar::Util qw( looks_like_number );
use Test::Mocha::Types 'NumRange', Mock => { -as => 'MockType' };

=head1 EXPORTS

This module exports the following functions by default:

=for :list
* mock
* stub
* verify

All other functions need to be imported explicitly.

=for Pod::Coverage inspect

=cut

our @EXPORT = qw(
    mock
    stub
    verify
);
our @EXPORT_OK = qw(
    inspect
);

=func mock

C<mock()> constructs a new instance of a mock object.

    $mock = mock;
    $mock->method(@args);

C<$class> is an optional argument to set the type that the mock object is
blessed into. This value will be returned when C<ref()> is called on the object.

    $mock = mock($class);
    is( ref($mock), $class );

=cut

sub mock {
    return Mock->new if @_ == 0;

    my ($class) = @_;

    croak 'The argument for mock() must be a string'
        unless !ref $class;

    return Mock->new(class => $class);
}

=func stub

C<stub()> is used to tell the method stub to return some value(s) or to raise
an exception.

    stub($mock)->method(@args)->returns(1, 2, 3);
    stub($mock)->invalid(@args)->dies('exception');

=cut

sub stub {
    my ($mock) = @_;

    croak 'stub() must be given a mock object'
        unless defined $mock && MockType->check($mock);

    return Stubber->new(mock => $mock);
}

=func verify

C<verify()> is used to check the interactions on your mock object and prints
the test result. C<verify()> plays nicely with L<Test::Simple> and Co - it
depends on them for setting a test plan and its calls are counted in the test
plan.

    verify($mock)->method(@args)
    # prints: ok 1 - method("foo") was called 1 time(s)

C<verify()> accepts an optional C<$test_name> to print a custom name for the
test instead of the default.

    verify($mock, $test_name)->method(@args)
    # prints: ok 1 - record inserted into database'

C<verify()> accepts a few options to help your verifications:

    verify( $mock, times    => 3,     )->method(@args)
    verify( $mock, at_least => 3      )->method(@args)
    verify( $mock, at_most  => 5      )->method(@args)
    verify( $mock, between  => [3, 5] )->method(@args)

=for :list
= times
Specifies the number of times the given method is expected to be called. The
default is 1 if no other option is specified.
= at_least
Specifies the minimum number of times the given method is expected to be
called.
= at_most
Specifies the maximum number of times the given method is expected to be
called.
= between
Specifies the minimum and maximum number of times the given method is expected
to be called.

A C<$test_name> may also be supplied after the option.

    verify($mock, times => 3, $test_name)->method(@args)

=cut

sub verify {
    my $mock = shift;
    my $test_name;
    $test_name = pop if (@_ % 2 == 1);
    my %options = @_;

    # set default option if none given
    $options{times} = 1 if keys %options == 0;

    croak 'verify() must be given a mock object'
        unless defined $mock && MockType->check($mock);

    croak 'You can set only one of these options: '
        . join ', ', map {"'$_'"} keys %options
        unless keys %options == 1;

    if (defined $options{times}) {
        croak "'times' option must be a number" unless (
            looks_like_number $options{times} ||
            ref $options{times} eq 'CODE'
        );
    }
    elsif (defined $options{at_least}) {
        croak "'at_least' option must be a number"
            unless looks_like_number $options{at_least};
    }
    elsif (defined $options{at_most}) {
        croak "'at_most' option must be a number"
            unless looks_like_number $options{at_most};
    }
    elsif (defined $options{between}) {
        croak "'between' option must be an arrayref "
            . "with 2 numbers in ascending order" unless (
            NumRange->check( $options{between} ) &&
            $options{between}[0] < $options{between}[1]
        );
    }

    # set test name if given
    $options{test_name} = $test_name if defined $test_name;

    return Verify->new(mock => $mock, %options);
}

sub inspect {
    my ($mock) = @_;

    croak 'inspect() must be given a mock object'
        unless defined $mock && MockType->check($mock);

    return Inspect->new(mock => $mock);
}

1;