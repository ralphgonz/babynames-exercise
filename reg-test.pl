#!/usr/bin/perl

##############################################################################
# reg-test.pl
# R. Gonzalez 2015
#
# Predict outcome of test data using numerical/categorical training data and
# K-nearest neighbors model.
# -h for usage
##############################################################################

use strict;
#use Statistics::Regression;
use Scalar::Util;

my $sepChar = "\t"; # tab-delimited files
my $targetName = "target";
my $numNeighbors = 5;
my %args = loadArgs();


#####
# Training. First pass to load header and discover categorical columns

print STDERR "*** Load header and analyze columns...\n";
open my $trainHandle, '<', $args{trainFile}
	|| die "Can't open $args{trainFile}";
my @colNames = getCols($trainHandle, $sepChar);
my %colPos = getColumnPositions(@colNames);
my $targetPos = $colPos{$targetName};
my %catColMap = getCategoricalColMap($trainHandle, $sepChar);
close $trainHandle;
my @featureNames = getFeatures($targetPos, \%catColMap, \@colNames, 1);

#####
# Second pass to load/process each training line

print STDERR "*** Load and transform training data...\n";
my @trainData; # list of hashes
open $trainHandle, '<', $args{trainFile}
	|| die "Can't open $args{trainFile}";
getCols($trainHandle, $sepChar); # skip header line
while (my @cols = getCols($trainHandle, $sepChar)) {
	my $target = $cols[$targetPos];
	my @features = getFeatures($targetPos, \%catColMap, \@cols, 0);
	push @trainData, { "target" => $target, "features" => \@features };
}
close $trainHandle;
my @featureVariance = computeFeatureVariance(\@trainData);

#####
# Process each test line. Assume file structure is the same except for missing 'target'

print STDERR "*** Process test data...\n";
open my $testHandle, '<', $args{testFile}
	|| die "Can't open $args{testFile}";
open my $outHandle, '>', $args{outFile}
	|| die "Can't write to $args{outFile}";
getCols($testHandle, $sepChar); # skip header line
my $row = 0;
while (my @cols = getCols($testHandle, $sepChar)) {
	print STDERR "Line " . (++$row) . "...\n";
	splice @cols, $targetPos, 0, 'target'; # add placeholder target column to match training data
	my @features = getFeatures($targetPos, \%catColMap, \@cols, 0);
	my @neighbors = getNearestNeighbors($numNeighbors, \@features, \@trainData, \@featureVariance);
	my $target = averageNeighborTargets(\@neighbors, \@trainData);
	print $outHandle "$target\n";
}

print STDERR "*** Done.\n";
close $testHandle;
close $outHandle;

exit(0);


##############################################################################
sub computeFeatureVariance {
	my ($trainData) = @_;
	my @colVariance;
	my $nCols = scalar(@{$trainData->[0]->{features}});
	my $nRows = scalar(@$trainData);
	for (my $col=0 ; $col < $nCols ; ++$col) {
		my $sum = 0;
		my $sumSq = 0;
		for (my $row=0 ; $row < $nRows ; ++$row) {
			my $val = $trainData->[$row]->{features}->[$col];
			$sum += $val;
			$sumSq += $val * $val;
		}
		$colVariance[$col] = ($sumSq - ($sum * $sum) / $nRows) / ($nRows - 1);
	}
	return @colVariance;
}

##############################################################################
# Returns array of offsets in trainData. These represent the k nearest
# neighbors after normalizing features by their variance over the training set.
sub getNearestNeighbors {
	my ($numNeighbors, $features, $trainData, $featureVariance) = @_;

	my %neighbors = initializeNeighbors($numNeighbors); # offset => distance
	for (my $i=0 ; $i<scalar(@$trainData) ; ++$i) {
		 my $distance = getFeatureDistance($features, $trainData->[$i]->{features}, $featureVariance);
		 foreach my $j (keys %neighbors) {
			 if (!defined($neighbors{$j}) || $distance < $neighbors{$j}) {
				 delete $neighbors{$j};
				 $neighbors{$i} = $distance;
				 last;
			 }
		 }
	 }
		 
	return keys %neighbors;
}

##############################################################################
sub getFeatureDistance {
	my ($fA, $fB, $featureVariance) = @_;
	my $distance = 0;
	for (my $i=0 ; $i < scalar(@$fA) ; ++$i) {
		$distance += ($fA->[$i] - $fB->[$i]) * ($fA->[$i] - $fB->[$i]) / $featureVariance->[$i];
	}
	return sqrt($distance);
}

##############################################################################
sub averageNeighborTargets {
	my ($neighbors, $trainData) = @_;
	my $avgTarget = 0;
	for (my $i=0 ; $i < scalar(@$neighbors) ; ++$i) {
		$avgTarget += $trainData->[$neighbors->[$i]]->{target};
	}
	return $avgTarget / scalar(@$neighbors);
}

##############################################################################
# Returns initial (dummy) hash offset => distance
sub initializeNeighbors {
	my ($numNeighbors) = @_;
	my %neighbors;
	for (my $i=0 ; $i<$numNeighbors ; ++$i) {
		$neighbors{"placeholder" . $i} = undef;
	}
	return %neighbors;
}

##############################################################################
# Returns hash on positions of columns containing nonnumeric data to mappings
# of this data to a cardinal number within each categorical column:
# { column number => { category value => category number, ... }, ... }
sub getCategoricalColMap {
	my ($trainHandle, $sepChar) = @_;
	my %catColMap;
	while (my @cols = getCols($trainHandle, $sepChar)) {
		for (my $i=0 ; $i<scalar(@cols) ; ++$i) {
			my $col = $cols[$i];
			if ($col && !Scalar::Util::looks_like_number($col)) {
				if (!$catColMap{$i}) {
					# initialize map for this column
					$catColMap{$i} = {}; 
				}
				if (!$catColMap{$i}->{$col}) {
					# number the newly-discovered new categorical value for this column
					$catColMap{$i}->{$col} = scalar(keys %{$catColMap{$i}});
				}
			}
		}
	}
	return %catColMap;
}
	
##############################################################################
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

##############################################################################
sub getCols {
	my ($trainHandle, $sepChar) = @_;
	my @cols = split /$sepChar/, <$trainHandle>;
	foreach my $col (@cols) {
		# trim leading and trailing space
		$col =~ s/^\s+//;
		$col =~ s/\s+$//;
	}
	return @cols;
}

##############################################################################
sub getColumnPositions {
	my @colNames = @_;
	my %colPos;
	for (my $i=0 ; $i<scalar(@colNames) ; ++$i) {
		$colPos{$colNames[$i]} = $i;
	}
	return %colPos;
}

##############################################################################
# Strip "target" column, map categorical columns
sub getFeatures {
	my ($targetPos, $catColMap, $cols, $isHeader) = @_;
	my @features;
	for (my $i=0 ; $i<scalar(@$cols) ; ++$i) {
		next if ($i == $targetPos);
		my $val = $cols->[$i];
		if (!$catColMap->{$i}) {
			# not categorical
			push @features, $val;
		} else {
			# Is categorical column. Replace with multiple dummy variables
			my $numCategories = scalar(keys %{$catColMap->{$i}});
			for (my $j=0 ; $j < $numCategories ; ++$j) {
				my $catVal;
				if ($isHeader) {
					$catVal = $val . "_" . $j;
				} elsif ($j == $catColMap->{$i}->{$val}) {
					$catVal = 1;
				} else {
					$catVal = 0;
				}
				push @features, $catVal;
			}
		}
	}
	return @features;
}



