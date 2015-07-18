#!/usr/bin/perl

# reg-test.pl
# R. Gonzalez 2015

use Statistics::Regression;

my $sepChar = "\t"; # tab-delimited files
my %args = loadArgs();

########################
# Load training header and data

open my $trainHandle, '<', $args{trainFile}
	|| die "Can't open $trainFile";
	
my @colNames = split /$sepChar/, <$trainHandle>;
my %colPos = columnPositions(@colNames);

print $colPos{f_25};

exit(0);


########################
sub loadArgs {
	my $usage = "ARGS:
		-train <training data file>
		-test <test data file>
		-out <output file>
	";
	my %args;
	while ((my $arg=$ARGV[0]) =~ /^-/) {
	    if ($arg eq "-train")
	        { shift @ARGV; $args{trainFile} = $ARGV[0]; }
	    elsif ($arg eq "-test")
	        { shift @ARGV; $args{testFile} = $ARGV[0]; }
	    elsif ($arg eq "-out")
	        { shift @ARGV; $args{outFile} = $ARGV[0]; }
	    else
	        { die $usage }
	    shift @ARGV;
	}
	die $usage if (!$args{trainFile} || !$args{testFile} || !$args{outFile});
	return %args;
}

########################
sub columnPositions {
	my @colNames = @_;
	my %colPos;
	for (my $i=0 ; $i<scalar(@colNames) ; ++$i) {
		$colPos{$colNames[$i]} = $i;
	}
	return %colPos;
}






exit(0);
