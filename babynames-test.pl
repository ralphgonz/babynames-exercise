#!/usr/bin/perl

##############################################################################
# babynames-test.pl
# R. Gonzalez 2015
#
# Aggregate and draw conclusions from US birth names data
##############################################################################

use strict;

my $sepChar = ","; # comma-delimited files
my %colPos = ( 'state' => 0, 'gender' => 1, 'year' => 2, 'name' => 3, 'count' => 4);
my %args = loadArgs();


#####
# Aggregate per-state data into memory

print STDERR "*** Load data...\n";
my $data = loadAggregateData($args{dir}, $sepChar, \%colPos);

my $mostPopular = getMostPopular($data, undef);
print "Most popular ovarall: " . (ucfirst($mostPopular)) . "\n";
$mostPopular = getMostPopular($data, "f");
print "Most popular female name: " . (ucfirst($mostPopular)) . "\n";

my $mostGenderAmbiguous = getMostGenderAmbiguous($data, "2013");
print "Most gender ambiguous 2013: " . (ucfirst($mostGenderAmbiguous)) . "\n";
$mostGenderAmbiguous = getMostGenderAmbiguous($data, "1945");
print "Most gender ambiguous 1945: " . (ucfirst($mostGenderAmbiguous)) . "\n";

my $mostIncreasePopularity = getMostChangedPopularity($data, "1980", "2014", 1);
print "Most increased popularity 1980 to 2014: " . (ucfirst($mostIncreasePopularity)) . "\n";
my $mostDecreasePopularity = getMostChangedPopularity($data, "1980", "2014", 0);
print "Most decreased popularity 1980 to 2014: " . (ucfirst($mostDecreasePopularity)) . "\n";

exit(0);


##############################################################################
sub loadArgs {
	my $usage = "ARGS:
		-dir <directory containing baby data per state>
	";
	my %args;
	while ((my $arg=$ARGV[0]) =~ /^-/) {
	    if ($arg eq "-dir")
	        { shift @ARGV; $args{dir} = $ARGV[0]; }
	    else
	        { die $usage }
	    shift @ARGV;
	}
	die $usage if (!$args{dir});
	return %args;
}

##############################################################################
# Returns ref to 3-dimensional hash: name, year, gender, mapping to count.
# Aggregates across states.
sub loadAggregateData {
	my ($dir, $sepChar, $colPos) = @_;
	
	opendir (my $dh, $dir) || die "Can't open directory $dir";
	my @files = readdir $dh;
	closedir $dh;
	
	my %data;
	foreach my $fileName (@files) {
		next if ($fileName !~ /^\w\w\.TXT$/); # only open per-state data files
		print STDERR "*** Loading $fileName...\n";
		open my $fh, '<', "$dir/$fileName" || die "Can't open file $dir/$fileName";
		while (my @cols = getCols($fh, $sepChar)) {
			my ($gender, $year, $name, $count) =
				($cols[$colPos->{'gender'}], $cols[$colPos->{'year'}],$cols[$colPos->{'name'}],$cols[$colPos->{'count'}]);
			if (!exists($data{$name}{$year}{$gender})) {
				 $data{$name}{$year}{$gender} = 0;
			 }
			 $data{$name}{$year}{$gender} += $count;
		 }
		 close $fh;
	 }
	 
	 return \%data;
}

##############################################################################
sub getCols {
	my ($fh, $sepChar) = @_;
	my @cols = split /$sepChar/, <$fh>;
	foreach my $col (@cols) {
		# trim leading and trailing space, make case insensitive
		$col =~ s/^\s+//;
		$col =~ s/\s+$//;
		$col = lc($col);
	}
	return @cols;
}

##############################################################################
sub getMostPopular {
	my ($data, $genderChoice) = @_;
	
	my %overallCountByName;
	foreach my $name (keys %$data) {
		foreach my $year (keys %{$data->{$name}}) {
			foreach my $gender (keys %{$data->{$name}->{$year}}) {
				next if ($genderChoice && lc($genderChoice) ne lc($gender));
				if (!exists($overallCountByName{$name})) {
					$overallCountByName{$name} = 0;
				}
				$overallCountByName{$name} += $data->{$name}->{$year}->{$gender};
			}
		}
	}
	
	my $maxCount = 0;
	my $maxCountName;
	while (my ($name, $count) = each %overallCountByName) {
		if ($count > $maxCount) {
			$maxCount = $count;
			$maxCountName = $name;
		}
	}
	
	return $maxCountName;
}

##############################################################################
# Find name whose count is most similar across gender. 
# Based on the log ratio of M/F closest to 0
sub getMostGenderAmbiguous {
	my ($data, $year) = @_;
	
	my %countByNameF;
	my %countByNameM;
	foreach my $name (keys %$data) {
		foreach my $gender (keys %{$data->{$name}->{$year}}) {
			if ($gender eq 'f') {
				$countByNameF{$name} = $data->{$name}->{$year}->{$gender};
			} else {
				$countByNameM{$name} = $data->{$name}->{$year}->{$gender};
			}
		}
	}
	
	my $closestRatio = undef;
	my $closestRatioName;
	while (my ($name, $countF) = each %countByNameF) {
		my $countM = $countByNameM{$name};
		next if (!$countM);
		my $ratio = log($countM / $countF);
		if (!defined($closestRatio) || abs($ratio) < abs($closestRatio)) {
			$closestRatio = $ratio;
			$closestRatioName = $name;
		}
	}
	
	return $closestRatioName;
}

##############################################################################
# Find name whose popularity (count / total births) has changed the most 
sub getMostChangedPopularity {
	my ($data, $year1, $year2, $isIncrease) = @_;
	
	my %countByName1;
	my %countByName2;
	my %allNames;
	my $total1 = 0;
	my $total2 = 0;
	foreach my $name (keys %$data) {
		foreach my $gender (keys %{$data->{$name}->{$year1}}) {
			if (!exists($countByName1{$name})) {
				$countByName1{$name} = 0;
			}
			$countByName1{$name} += $data->{$name}->{$year1}->{$gender};
			$total1 += $data->{$name}->{$year1}->{$gender};
			$allNames{$name} = 1;
		}
		foreach my $gender (keys %{$data->{$name}->{$year2}}) {
			if (!exists($countByName2{$name})) {
				$countByName2{$name} = 0;
			}
			$countByName2{$name} += $data->{$name}->{$year2}->{$gender};
			$total2 += $data->{$name}->{$year2}->{$gender};
			$allNames{$name} = 1;
		}
	}
	
	my $maxChange = undef;
	my $maxChangeName;
	foreach my $name (keys %allNames) {
		my $pop1 = $countByName1{$name} / $total1;
		my $pop2 = $countByName2{$name} / $total2;
		my $change = ($isIncrease ? $pop2 - $pop1 : $pop1 - $pop2);
		if (!defined($maxChange) || $change > $maxChange) {
			$maxChange = $change;
			$maxChangeName = $name;
		}
	}
	
	return $maxChangeName;
}



