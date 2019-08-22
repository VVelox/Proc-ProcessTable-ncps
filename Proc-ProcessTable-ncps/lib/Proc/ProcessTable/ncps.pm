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
				minor_faults=>0,
				major_faults=>0,
				colors=>[
						 'BRIGHT_YELLOW',
						 'BRIGHT_CYAN',
						 'BRIGHT_MAGENTA',
						 'BRIGHT_BLUE'
						 ],
				timeColors=>[
							 'GREEN',
							 'BRIGHT_GREEN',
							 'RED',
							 'BRIGHT_RED'
							 ],
				processColor=>'BRIGHT_RED',
				nextColor=>0,
				};
    bless $self;

	if (
		defined( $args{match} ) &&
		defined( $args{match}{checks} ) &&
		defined( $args{match}{checks}[0] )
		){
		$self->{match}=Proc::ProcessTable::Match->new( $args{match} );
	}

	if ( defined( $args{major_faults} ) ){
		$self->{major_faults}=$args{major_faults};
	}

	if ( defined( $args{minor_faults} ) ){
		$self->{minor_faults}=$args{minor_faults};
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

	# figures out if this systems reports nice or not
	my $have_nice=0;
	if (
		defined( $procs->[0] ) &&
		defined($procs->[0]->{nice} )
		){
		$have_nice=1;
	}

	# figures out if this systems reports priority or not
	my $have_pri=0;
	if (
		defined( $procs->[0] ) &&
		defined($procs->[0]->{priority} )
		){
		$have_pri=1;
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

	#
	# assemble the headers
	#
	my @headers;
	my $header_int=0;
	my $padding=0;
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
	# add nice if needed
	if ( $have_nice ){
		push( @headers, 'Nic' );
		if (( $header_int % 2 ) != 0){ $padding=1; }else{ $padding=0; }
		$tb->set_column_style($header_int, pad => $padding ); $header_int++;
	}
	# add priority if needed
	if ( $have_pri ){
		push( @headers, 'Pri' );
		if (( $header_int % 2 ) != 0){ $padding=1; }else{ $padding=0; }
		$tb->set_column_style($header_int, pad => $padding ); $header_int++;
	}
	# add major faults if needed
	if ( $self->{major_faults} ){
		push( @headers, 'MajF' );
		if (( $header_int % 2 ) != 0){ $padding=1; }else{ $padding=0; }
		$tb->set_column_style($header_int, pad => $padding ); $header_int++;
	}
	# add minor faults if needed
	if ( $self->{minor_faults} ){
		push( @headers, 'minF' );
		if (( $header_int % 2 ) != 0){ $padding=1; }else{ $padding=0; }
		$tb->set_column_style($header_int, pad => $padding ); $header_int++;
	}
	if (( $header_int % 2 ) != 0){ $padding=1; }else{ $padding=0; }
	$tb->set_column_style($header_int, pad => $padding ); $header_int++;
	push( @headers, 'Start' );
	if (( $header_int % 2 ) != 0){ $padding=1; }else{ $padding=0; }
	$tb->set_column_style($header_int, pad => $padding ); $header_int++;
	push( @headers, 'Time' );
	if (( $header_int % 2 ) != 0){ $padding=1; }else{ $padding=0; }
	$tb->set_column_style($header_int, pad => $padding ); $header_int++;
	push( @headers, 'Command' );
	if (( $header_int % 2 ) != 0){ $padding=1; }else{ $padding=0; }
	$tb->set_column_style($header_int, pad => $padding, formats=>[[wrap => {ansi=>1, mb=>1}]]);

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
			$user=color($self->nextColor).$user.color('reset');
			push( @new_line, $user );

			#
			# handles the PID
			#
			push( @new_line,  color($self->nextColor).$proc->{pid}.color('reset') );

			#
			# handles the %CPU
			#
			push( @new_line,  color($self->nextColor).$proc->{pctcpu}.color('reset') );

			#
			# handles the %MEM
			#
			if ( $^O =~ /bsd/ ) {
				my $mem=(($proc->{rssize} * 1024 * 4 ) / $physmem) * 100;
				push( @new_line,  color($self->nextColor).sprintf('%.2f', $mem).color('reset') );
			} else {
				push( @new_line,  color($self->nextColor).sprintf('%.2f', $proc->{pctcpu}).color('reset') );
			}

			#
			# handles VSZ
			#
			push( @new_line,  color($self->nextColor).$proc->{size}.color('reset') );

			#
			# handles the rss
			#
			push( @new_line,  color($self->nextColor).$proc->{rss}.color('reset') );

			#
			# handles the info
			#
			my $info;
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
			$info=color($self->nextColor).$info;
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
			$info=$info.' '.color($self->nextColor);
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
			$info=$info.color('reset');
			# finally actually add it to the new new line array
			push( @new_line,  $info );

			#
			# handle the nice column
			#
			if ( $have_nice ){
				push( @new_line, color($self->nextColor).$proc->{nice}.color('reset') );
			}

			#
			# handle the priority column
			#
			if ( $have_pri ){
				push( @new_line, color($self->nextColor).$proc->{priority}.color('reset') );
			}

			#
			# major faults
			#
			if ( $self->{major_faults} ){
				push( @new_line, color($self->nextColor).$proc->{majflt}.color('reset') );
			}

			#
			# major faults
			#
			if ( $self->{minor_faults} ){
				push( @new_line, color($self->nextColor).$proc->{minflt}.color('reset') );
			}

			#
			# handles the start column
			#
			push( @new_line, color($self->nextColor).$self->startString( $proc->{start} ).color('reset') );

			#
			# handles the time column
			#
			push( @new_line,  $self->timeString( $proc->{time} ) );

			#
			# handle the command
			#
			my $command=color($self->{processColor});
			if ( $proc->{cmndline} =~ /^$/ ) {
				$command=$command.'['.$proc->{fname}.']';
			} else {
				$command=$command.$proc->{cmndline};
			}
			push( @new_line, $command.color('reset') );

			push( @td, \@new_line );
			$self->{nextColor}=0;
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
                $toReturn=color($self->{timeColors}->[3]).$hours.':';
        }else{
                $toReturn=color($self->{timeColors}->[2]).$hours.':';
        }

        #process the minutes bit
        if (
                ( $hours > 0 ) ||
                ( $minutes > 0 )
                ){
                $toReturn=$toReturn.color( $self->{timeColors}->[1] ). $minutes.':';
        }

        $toReturn=$toReturn.color( $self->{timeColors}->[0] ).$seconds.color('reset');

        return $toReturn;
}

=head2 nextColor

Returns the next color.

=cut

sub nextColor{
	my $self=$_[0];

	my $color;

	if ( defined( $self->{colors}[ $self->{nextColor} ] ) ) {
		$color=$self->{colors}[ $self->{nextColor} ];
		$self->{nextColor}++;
	} else {
		$self->{nextColor}=0;
		$color=$self->{colors}[ $self->{nextColor} ];
		$self->{nextColor}++;
	}

	return $color;
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
