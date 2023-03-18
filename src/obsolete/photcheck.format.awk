# An awk script used by the IRAF/DIMSUM routine photcheck for formatting 
# output data files.   The input data is taken from txdump, and consists 
# of a series of N lines for each apphot.phot photometry file, where 
# column 1 of each line has the name of the image from which the photometry 
# was measured, column 2 records the time of observation, column 3 contains 
# the magnitude measurement for the star, and column 4 contains the associated 
# error estimate in that magnitude.  There will be a blank line between each 
# set of N input data lines, indicating a break before the next photometry file.
#
# Mark Dickinson, 3 Aug 1993.
# Format slightly revised 16 Oct 1993.
#
#   Set new file switch.
#
BEGIN {newfile = 1}
#
{
#
#   If input line is blank, print carriage return and set newfile=1.
#
	if ($0=="") {
		printf ("\n")
		newfile = 1
#
#   Otherwise, if new file, print image name in column 1, the obstime (converted to decimal)
#   in column 2, and set newfile=0.
#
	   } else {
		if (newfile) {
			uth = substr($2,1,2)
			utm = substr($2,4,2)
			uts = substr($2,7,2)
			ut = uth + utm/60. + uts/3600.
			printf ("%15s %7.4f ",$1,ut)
			newfile = 0
		}
#
#   If magnitude record = INDEF, print "INDEF" on end of current output record.
#
		if ($3=="INDEF") {
			printf ("  %6s"," INDEF")
#
#   Otherwise, print magnitude on end of current output record.
#
		   } else {
			printf (" %6.3f",$3)
		}
#
#   If error record = INDEF, print "INDEF" on end of current output record.
#
		if ($4=="INDEF") {
			printf (" %5s","INDEF")
#
#   Otherwise, print error on end of current output record.
#
		   } else {
			printf (" %5.3f",$4)
		}
	}
}
