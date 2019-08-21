package Proc::ProcessTable::ncps;

use 5.006;
use strict;
use warnings;
use Proc::ProcessTable::Match;
use Proc::ProcessTable;
use Text::ANSITable;
use Term::ANSIColor;

=head1 NAME

Proc::ProcessTable::ncps - The great new Proc::ProcessTable::ncps!

=head1 VERSION

Version 0.0.0

=cut

our $VERSION = '0.0.0';


=head1 SYNOPSIS

    use Proc::ProcessTable::ncps;

    my $ncps = Proc::ProcessTable::ncps->new();
    ...

=head1 METHODS

=head2 new

=cut

sub new {
	my %args;
	if (defined($_[1])) {
		%args= %{$_[1]};
	}


	my $self = {
				invert=>0,
				match=>undef,
				};
    bless $self;

	if ( defined( $args{match} ) ){
		$self->{match}=Proc::ProcessTable::Match->new( $args{match} );
	}

	return $self;
}

=head2 run

=cut

sub run{
	my $self=$_[0];

	my $ppt = Proc::ProcessTable->new( 'cache_ttys' => 1 );
	my $pt = $ppt->table;

	my $procs;
	if ( defined( $self->{match} ) ){
		$procs=[];
		foreach my $proc ( @{ $pt } ){
			eval{
				if ( $self->{match}->match( $proc ) ){
					push( @{ $procs }, $proc );
				}
			};
		}
	}else{
		$procs=$pt;
	}

	my $physmem;
	if ( $^O =~ /bsd/ ){
		$physmem=`/sbin/sysctl -a hw.physmem`;
		chomp( $physmem );
		$physmem=~s/^.*\: //;
	}

	my $tb = Text::ANSITable->new;
	$tb->border_style('Default::none_ascii');  # if not, a nice default is picked
	$tb->color_theme('Default::no_color');  # if not, a nice default is picked

	my @headers;
	my $header_int=0;
	push( @headers, 'User' );
	$tb->set_column_style($header_int, pad => 0); $header_int++;
	push( @headers, 'PID' );
	$tb->set_column_style($header_int, pad => 1); $header_int++;
	push( @headers, '%CPU' );
	$tb->set_column_style($header_int, pad => 0); $header_int++;
	push( @headers, '%MEM' );
	$tb->set_column_style($header_int, pad => 0); $header_int++;
	push( @headers, 'VSZ' );
	$tb->set_column_style($header_int, pad => 1); $header_int++;
	push( @headers, 'RSS' );
	$tb->set_column_style($header_int, pad => 0); $header_int++;
	push( @headers, 'Info' );
	$tb->set_column_style($header_int, pad => 1); $header_int++;
	push( @headers, 'Start' );
	$tb->set_column_style($header_int, pad => 0); $header_int++;
	push( @headers, 'Time' );
	$tb->set_column_style($header_int, pad => 1); $header_int++;
	push( @headers, 'Command' );
	$tb->set_column_style($header_int, pad => 1, formats=>[[wrap => {ansi=>1, mb=>1}]]);

	$tb->columns( \@headers );

	my @td;
	foreach my $proc ( @{ $procs } ) {
		if ( $proc->{fname} !~ /^idle$/ ) {
			my @new_line;

			#
			# handle username column
			#
			my $user=getpwuid($proc->{uid});
			if ( ! defined( $user ) ) {
				$user=$proc->{uid};
			}
			$user=color('bright_yellow').$user.color('reset');
			push( @new_line, $user );

			#
			# handles the PID
			#
			push( @new_line,  color('bright_cyan').$proc->{pid}.color('reset') );

			#
			# handles the %CPU
			#
			push( @new_line,  color('bright_green').$proc->{pctcpu}.color('reset') );

			#
			# handles the %MEM
			#
			if ( $^O =~ /bsd/ ) {
				my $mem=(($proc->{rssize} * 1024 * 4 ) / $physmem) * 100;
				push( @new_line,  color('bright_green').sprintf('%.2f', $mem).color('reset') );
			} else {
				push( @new_line,  color('bright_green').sprintf('%.2f', $proc->{pctcpu}).color('reset') );
			}

			#
			# handles VSZ
			#
			push( @new_line,  color('bright_green').$proc->{size}.color('reset') );

			#
			# handles the rss
			#
			push( @new_line,  color('bright_green').$proc->{rss}.color('reset') );

			#
			# handles the info
			#
			my $info=color('bright_magenta');
			my %flags;
			$flags{is_session_leader}=0;
			$flags{is_being_forked}=0;
			$flags{working_on_exiting}=0;
			$flags{has_controlling_terminal}=0;
			$flags{is_locked}=0;
			$flags{traced_by_debugger}=0;
			$flags{is_stopped}=0;
			$flags{posix_advisory_lock}=0;
			# parses the flags for freebsd
			if ( $^O =~ /freebsd/ ) {
				if ( hex($proc->flags) & 0x00002 ) {
					$flags{controlling_tty_active}=1;
				}
				if ( hex($proc->flags) & 0x00000002 ) {
					$flags{is_session_leader}=1;
				}
				#if ( hex($proc->flags) &  ){$flags{is_being_forked}=1; }
				if ( hex($proc->flags) & 0x02000 ) {
					$flags{working_on_exiting}=1;
				}
				if ( hex($proc->flags) & 0x00002 ) {
					$flags{has_controlling_terminal}=1;
				}
				if ( hex($proc->flags) & 0x00000004 ) {
					$flags{is_locked}=1;
				}
				if ( hex($proc->flags) & 0x00800 ) {
					$flags{traced_by_debugger}=1;
				}
				if ( hex($proc->flags) & 0x00001 ) {
					$flags{posix_advisory_lock}=1;
				}
			}
			# get the state
			$info=$proc->{state};
			if (
				$info eq 'sleep'
				) {
				$info='S';
			} elsif (
					 $info eq 'zombie'
					 ) {
				$info='Z';
			} elsif (
					 $info eq 'wait'
					 ) {
				$info='W';
			} elsif (
					 $info eq 'run'
					 ) {
				$info='R';
			}
			#checks if it is swapped out
			if (
				( $proc->{state} ne 'zombie' ) &&
				( $proc->{rss} == '0' )
				) {
				$info=$info.'O';
			}
			#handles the various flags
			if ( $flags{working_on_exiting} ) {
				$info=$info.'E';
			}
			;
			if ( $flags{is_session_leader} ) {
				$info=$info.'s';
			}
			;
			if ( $flags{is_locked} || $flags{posix_advisory_lock} ) {
				$info=$info.'L';
			}
			;
			if ( $flags{has_controlling_terminal} ) {
				$info=$info.'+';
			}
			;
			if ( $flags{is_being_forked} ) {
				$info=$info.'F';
			}
			;
			if ( $flags{traced_by_debugger} ) {
				$info=$info.'X';
			}
			;
			# adds the wchan
			$info=$info.' '.color('bright_blue');
			if ( $^O =~ /linux/ ) {
				my $wchan='';
				if ( -e '/proc/'.$proc->{pid}.'/wchan') {
					open( my $wchan_fh, '<', '/proc/'.$proc->{pid}.'/wchan' );
					$wchan=readline( $wchan_fh );
					close( $wchan_fh );
				}
				$info=$info.$wchan;
			} else {
				$info=$info.$proc->{wchan};
			}
			$info=$info.' '.color('reset');
			# finally actually add it to the new new line array
			push( @new_line,  $info );

			#
			# handles the start column
			#
			push( @new_line, color('bright_cyan').$self->startString( $proc->{start} ).color('reset') );

			#
			# handles the time column
			#
			push( @new_line,  $self->timeString( $proc->{time} ) );

			#
			# handle the command
			#
			my $command=color('bright_red');
			if ( $proc->{cmndline} =~ /^$/ ) {
				$command=$command.'['.$proc->{fname}.']';
			} else {
				$command=$command.$proc->{cmndline};
			}
			push( @new_line, $command.color('reset') );

			#$tb->add_row( \@new_line );
			push( @td, \@new_line );
		}
	}

	$tb->add_rows( \@td );

	return $tb->draw;
}

=head2 startString

Generates a short time string based on the supplied unix time.

=cut

sub startString{
        my $self=$_[0];
        my $startTime=$_[1];

        my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($startTime);
        my ($csec,$cmin,$chour,$cmday,$cmon,$cyear,$cwday,$cyday,$cisdst) = localtime(time);

        #add the required stuff to make this sane
        $year += 1900;
        $cyear += 1900;
        $mon += 1;
        $cmon += 1;

        #find the most common one and return it
        if ( $year ne $cyear ){
                return $year.sprintf('%02d', $mon).sprintf('%02d', $mday).'-'.sprintf('%02d', $hour).':'.sprintf('%02d', $min);
        }
        if ( $mon ne $cmon ){
                return sprintf('%02d', $mon).sprintf('%02d', $mday).'-'.sprintf('%02d', $hour).':'.sprintf('%02d', $min);
        }
        if ( $mday ne $cmday ){
                return sprintf('%02d', $mday).'-'.sprintf('%02d', $hour).':'.sprintf('%02d', $min);
        }

        #just return this for anything less
        return sprintf('%02d', $hour).':'.sprintf('%02d', $min);
}

=head2 timeString

Turns the raw run string into something usable.

=cut

sub timeString{
        my $self=$_[0];
        my $time=$_[1];

        my $colors=[
					'GREEN',
					'BRIGHT_GREEN',
					'RED',
					'BRIGHT_RED'
					];

        my $hours=0;
        if ( $time >= 3600 ){
                $hours = $time / 3600;
        }
        my $loSeconds = $time % 3600;
        my $minutes=0;
        if ( $time >= 60 ){
                $minutes = $loSeconds / 60;
        }
        my $seconds = $loSeconds % 60;

        #nicely format it
        $hours=~s/\..*//;
        $minutes=~s/\..*//;
        $seconds=sprintf('%.f',$seconds);

        #this will be returned
        my $toReturn='';

        #process the hours bit
        if ( $hours == 0 ){
                #don't do anything if time is 0
        }elsif(
                $hours >= 10
                ){
                $toReturn=color($colors->[3]).$hours.':';
        }else{
                $toReturn=color($colors->[2]).$hours.':';
        }

        #process the minutes bit
        if (
                ( $hours > 0 ) ||
                ( $minutes > 0 )
                ){
                $toReturn=$toReturn.color( $colors->[1] ). $minutes.':';
        }

        $toReturn=$toReturn.color( $colors->[0] ).$seconds.color('reset');

        return $toReturn;
}


=head1 AUTHOR

Zane C. Bowers-Hadley, C<< <vvelox at vvelox.net> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-proc-processtable-ncps at rt.cpan.org>, or through
the web interface at L<https://rt.cpan.org/NoAuth/ReportBug.html?Queue=Proc-ProcessTable-ncps>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Proc::ProcessTable::ncps


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<https://rt.cpan.org/NoAuth/Bugs.html?Dist=Proc-ProcessTable-ncps>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Proc-ProcessTable-ncps>

=item * CPAN Ratings

L<https://cpanratings.perl.org/d/Proc-ProcessTable-ncps>

=item * Search CPAN

L<https://metacpan.org/release/Proc-ProcessTable-ncps>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2019 by Zane C. Bowers-Hadley.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)


=cut

1; # End of Proc::ProcessTable::ncps
