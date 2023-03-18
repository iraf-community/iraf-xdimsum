# An awk script used by IRAF/DIMSUM routine photdiff to look for photometric
# variations from frame to frame over an observing sequence.   This routine uses
# the formatted output from DIMSUM routine photcheck + awk script photcheck.format.awk
# as its input.  The first line of that input file is considered to be the photometry
# for the "reference frame."  Magnitudes of stars in each subsequent line are compared
# to it, and the average and rms of the magnitude differences is output along with
# the individual stellar magnitude differences.  Magnitude records that are INDEF
# are ignored in this computation.
#
# 3 August 1993,  Mark Dickinson
#
{
#
#   Record magnitudes from first line as reference values.
#
	if (NR==1) {
		ii=0
		nn=0
		for (i=3;i<=NF;i+=2) {
			ii+=1
			if ($i == "INDEF") {
				m[ii] = -99.99
				v[ii] = -99.99
			   } else {
				nn+=1
				m[ii] = $i
				v[ii] = $(i+1)*$(i+1)
			}
		}
		printf ("%15s %7s %7s %6s %2g ",$1,"  UT   ","delta m","  err ",nn)
		ii=0
		for (i=3;i<=NF;i+=2) {
			ii+=1
			if ($i == "INDEF") {
				printf (" %6s", " INDEF")
			   } else {
				printf (" %6.3f", m[ii])
			}
		}
		printf ("\n")
#
#   For all other lines, calculate differences between the star magnitudes and
#   the reference values, print these out, and calculate the mean and rms of 
#   those differences, then print those out at the end of the line.   Stars with
#   magnitude values = INDEF are excluded from the mean and rms calculation.
#
	   } else {
		printf ("%15s %7.4f ",$1,$2)
		dsum = 0.
		wsum = 0.
		nn = 0
		ii=0
		for (i=3;i<=NF;i+=2) {
			ii+=1
			if ($i != "INDEF" && m[ii] != -99.99) {
				d[ii] = m[ii] - $i
				vd[ii] = $(i+1)*$(i+1) + v[ii]
				dsum += d[ii]/vd[ii]
				wsum += 1./vd[ii]
				nn += 1
			   } else {
				d[ii] = -99.99
			}
		}
		if (nn > 0) {
			dmean = dsum / wsum
			derr  = sqrt(1./wsum)
			printf ("%7.3f %6.3f %2g ", dmean, derr, nn)
		   } else {
			printf ("%7s %6s %2g ","  INDEF"," INDEF", 0)
		}
		ii=0
		for (i=3;i<=NF;i+=2) {
			ii+=1
			if ($i != "INDEF" && m[ii] != -99.99) {
				printf (" %6.3f", d[ii])
			   } else {
				printf (" %6s"," INDEF")
			}
		}
		printf ("\n")
	}
}
